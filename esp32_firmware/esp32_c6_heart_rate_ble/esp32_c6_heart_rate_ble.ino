/*
  ESP32-C6 Heart Rate Monitor - BLE Firmware (analog pulse sensor)
  ================================================================

  Hardware pair this targets (nothing else is required):
    - ESP32-C6 dev board
    - 3-wire analog pulse sensor (round "Pulse Sensor" style module)

  The sensor outputs an analog heartbeat waveform on a single signal wire. This
  sketch samples it, detects beats, and publishes BPM over BLE to the Flutter
  app in this repository.

  BLE protocol (must match lib/utils/ble_config.dart):
    Service    4fafc201-1fb5-459e-8fcc-c5c9c331914b
    HR char    beb5483e-...  UTF-8 JSON {"bpm":72}  (notify, <= 20 B)
    SpO2 char  beb5483f-...  uint8 percent          (created, never notified)
    Temp char  beb54840-...  uint16 LE centidegrees (created, never notified)

  SpO2 and body temperature cannot be measured by an analog pulse module, so
  those two characteristics exist for protocol compatibility and are never
  written. The app consequently shows 0 % and "-- °C" for them.

  Wiring (defaults, override with -DPULSE_SIGNAL_PIN=<n>):
    Pulse sensor VCC     -> 3V3
    Pulse sensor GND     -> GND
    Pulse sensor SIGNAL  -> header pin labelled A2 (also labelled D2 on some
                            boards; both mean GPIO2)

  On ESP32-C6 boards the A0-A3 and D0-D3 header labels are GPIO numbers, not
  ADC channel numbers: A2 == D2 == GPIO2. Only GPIO0..GPIO6 are ADC-capable, so
  the aliases that work for the signal wire are A0/D0, A1/D1, A2/D2, A3/D3,
  D4, D5 and D6 (GPIO0 is used for battery measurement and GPIO4/5 are the
  I2C pins on some variants, so prefer A2/D2). This sketch understands both
  the A* and D* spellings, e.g. -DPULSE_SIGNAL_PIN=A2.
  Check the cable's wire colours before powering up; swapping VCC and GND can
  destroy the sensor.

  Build - USB CDC must be enabled or Serial output goes to UART0 and is
  invisible over the USB connector:
    arduino-cli compile --fqbn esp32:esp32:esp32c6:CDCOnBoot=cdc .
*/

#include <Arduino.h>
#include <BLE.h>

// ---------------------------------------------------------------- BLE identity
static const char* DEVICE_NAME = "ESP32-C6 HRM";

static const BLEUUID SVC_UUID("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
static const BLEUUID HR_CHAR_UUID("beb5483e-36e1-4688-b7f5-ea07361b26a8");
static const BLEUUID SPO2_CHAR_UUID("beb5483f-36e1-4688-b7f5-ea07361b26a8");
static const BLEUUID TEMP_CHAR_UUID("beb54840-36e1-4688-b7f5-ea07361b26a8");

BLECharacteristic hrChar;
BLECharacteristic spo2Char;
BLECharacteristic tempChar;
bool clientConnected = false;

// --------------------------------------------------------------------- signal
// Header labels A0-A3/D0-D3 are the GPIO numbers themselves. The indirection
// lets -DPULSE_SIGNAL_PIN=A2 and -DPULSE_SIGNAL_PIN=2 both resolve to 2.
#define HRM_CAT2(a, b) a##b
#define HRM_CAT(a, b) HRM_CAT2(a, b)
#define HRM_PIN_A0 0
#define HRM_PIN_A1 1
#define HRM_PIN_A2 2
#define HRM_PIN_A3 3
#define HRM_RESOLVE(p) HRM_CAT(HRM_PIN_, p)

#ifndef PULSE_SIGNAL_PIN
#define HRM_SIGNAL_PIN 2
#else
#define HRM_SIGNAL_PIN HRM_RESOLVE(PULSE_SIGNAL_PIN)
#endif

static const uint32_t SAMPLE_INTERVAL_US   = 2000;   // 500 Hz
static const uint32_t SEND_INTERVAL_MS     = 1000;
static const uint32_t STATUS_INTERVAL_MS   = 5000;
static const uint32_t BEAT_REFRACTORY_MS   = 280;    // hardware floor on beat spacing
// Physiological bounds: a resting human heart runs ~40-200 BPM. Anything
// outside 40-180 BPM is treated as noise, not a heartbeat.
static const uint32_t MIN_BEAT_INTERVAL_MS = 333;   // 180 BPM ceiling
static const uint32_t MAX_BEAT_INTERVAL_MS = 1500;  // 40 BPM floor
static const uint32_t BEAT_TIMEOUT_MS      = 5000;   // report 0 after this
static const float    MIN_AC_AMPLITUDE_MV  = 40.0f;  // ignore tiny wobbles
// A powered pulse module idles near VCC/2. Outside this window the pin is
// either floating or saturated, so no reading can be trusted.
static const float    DC_VALID_MIN_MV      = 700.0f;
static const float    DC_VALID_MAX_MV      = 2950.0f;
static const uint32_t MIN_CONSISTENT_BEATS = 4;      // beats needed before trusting BPM
static const float    MAX_INTERVAL_DEV     = 0.20f;  // reject intervals >20% off median

// ------------------------------------------------------------------ BLE objects
// Ring of accepted beat intervals, used to reject erratic (noise) detections.
static const uint8_t  INTERVAL_RING = 7;
uint32_t intervalsMs[INTERVAL_RING] = {0};
uint8_t  intervalCount = 0;
uint8_t  intervalSpot  = 0;

// ------------------------------------------------------------------ ADC state
float    dcLevel      = 1650.0f;
float    envMax       = 0.0f;
bool     armed        = false;
bool     aboveThresh  = false;
uint32_t lastBeatMs   = 0;

int      beatBpm      = 0;    // validated rate, 0 when signal is unusable
int      lastBpm      = 0;

float    lastDcMv  = 0.0f;
float    lastAcMv  = 0.0f;
float    lastEnvMv = 0.0f;
bool     leadOff   = true;

// ---------------------------------------------------------------------- helpers
const char* resetReasonName() {
  switch (esp_reset_reason()) {
    case ESP_RST_POWERON:  return "power-on";
    case ESP_RST_SW:       return "software";
    case ESP_RST_PANIC:    return "panic";
    case ESP_RST_INT_WDT:  return "interrupt-watchdog";
    case ESP_RST_TASK_WDT: return "task-watchdog";
    case ESP_RST_BROWNOUT: return "brownout";
    case ESP_RST_EXT:      return "external";
    default:               return "other";
  }
}

void resetIntervals() {
  for (uint8_t i = 0; i < INTERVAL_RING; i++) intervalsMs[i] = 0;
  intervalCount = 0;
  intervalSpot = 0;
  beatBpm = 0;
}

uint32_t medianInterval() {
  uint32_t tmp[INTERVAL_RING];
  uint8_t n = 0;
  for (uint8_t i = 0; i < INTERVAL_RING; i++) {
    if (intervalsMs[i] > 0) tmp[n++] = intervalsMs[i];
  }
  if (n == 0) return 0;
  // Insertion sort; n is at most 7
  for (uint8_t i = 1; i < n; i++) {
    uint32_t key = tmp[i];
    int8_t j = (int8_t)i - 1;
    while (j >= 0 && tmp[j] > key) { tmp[j + 1] = tmp[j]; j--; }
    tmp[j + 1] = key;
  }
  return n % 2 ? tmp[n / 2] : (tmp[n / 2 - 1] + tmp[n / 2]) / 2;
}

// Accept an interval only if it is consistent with the recent rhythm.
void registerInterval(uint32_t intervalMs) {
  if (intervalMs < MIN_BEAT_INTERVAL_MS || intervalMs > MAX_BEAT_INTERVAL_MS) return;
  uint32_t median = medianInterval();
  if (median > 0 && intervalCount >= 2) {
    float dev = fabsf((float)intervalMs - (float)median) / (float)median;
    if (dev > MAX_INTERVAL_DEV) return;   // erratic -> treat as noise
  }

  intervalsMs[intervalSpot++ % INTERVAL_RING] = intervalMs;
  if (intervalCount < INTERVAL_RING) intervalCount++;

  if (intervalCount >= MIN_CONSISTENT_BEATS) {
    uint32_t med = medianInterval();
    if (med > 0) beatBpm = (int)lroundf(60000.0f / (float)med);
  }
}

// One decision step per ADC sample.
void processSample() {
  uint32_t mv = analogReadMilliVolts(HRM_SIGNAL_PIN);
  uint32_t now = millis();

  // A disconnected input floats or sits at a rail and wanders. Reject anything
  // outside the mid-rail window so noise cannot masquerade as a heartbeat.
  leadOff = (dcLevel < DC_VALID_MIN_MV || dcLevel > DC_VALID_MAX_MV);

  dcLevel += ((float)mv - dcLevel) * 0.00006f;   // ~33 s at 500 Hz
  float ac = (float)mv - dcLevel;

  envMax = fmaxf(envMax * 0.999f, fabsf(ac));

  if (!armed && now > 500) armed = true;
  if (!armed || leadOff) {
    lastDcMv = dcLevel;
    lastAcMv = ac;
    lastEnvMv = envMax;
    return;
  }

  float threshold = fmaxf(MIN_AC_AMPLITUDE_MV, envMax * 0.60f);
  bool signalOk = envMax > MIN_AC_AMPLITUDE_MV;

  if (signalOk && ac > threshold && !aboveThresh &&
      (lastBeatMs == 0 || now - lastBeatMs > BEAT_REFRACTORY_MS)) {
    if (lastBeatMs != 0) registerInterval(now - lastBeatMs);
    lastBeatMs = now;
    aboveThresh = true;
  } else if (ac < threshold * 0.4f) {
    aboveThresh = false;
  }

  lastDcMv  = dcLevel;
  lastAcMv  = ac;
  lastEnvMv = envMax;
}

// --------------------------------------------------------------------- BLE glue
void hrmPrintPinHint(float mv) {
  static bool warned = false;
  if (mv >= DC_VALID_MIN_MV && mv <= DC_VALID_MAX_MV) {
    warned = false;
    return;
  }
  if (warned) return;
  warned = true;
  Serial.printf(
      "WARNING: GPIO%d reads %.0f mV, outside the 900-2600 mV window for a "
      "powered pulse module (floating wire reads ~500 mV). Check that SIGNAL "
      "goes to header pin A%d/D%d and that VCC=3V3, GND=GND.\n",
      HRM_SIGNAL_PIN, mv, HRM_SIGNAL_PIN, HRM_SIGNAL_PIN);
}

void hrmPrintPinOk(float mv) {
  static bool reported = false;
  if (reported || mv < DC_VALID_MIN_MV || mv > DC_VALID_MAX_MV) return;
  reported = true;
  Serial.printf("OK: GPIO%d reads %.0f mV - sensor is powered and on the right pin\n",
                HRM_SIGNAL_PIN, mv);
}

void setupBle() {
  Serial.print("BLE: init... ");
  BTStatus initStatus = BLE.begin(DEVICE_NAME);
  if (!initStatus) {
    Serial.printf("FAILED (%s)\n", initStatus.toString());
    return;
  }
  Serial.println("ok");

  BLE.setMTU(247);

  BLEServer server = BLE.createServer();
  if (!server) {
    Serial.println("BLE: createServer FAILED");
    return;
  }
  server.advertiseOnDisconnect(true);

  server.onConnect([](BLEServer& s, const BLEConnInfo& conn) {
    clientConnected = true;
    Serial.printf("BLE: client connected (mtu=%d)\n", conn.getMTU());
  });
  server.onDisconnect([](BLEServer& s, const BLEConnInfo& conn, uint8_t reason) {
    clientConnected = false;
    Serial.printf("BLE: client disconnected (reason 0x%02X)\n", reason);
  });

  BLEService svc = server.createService(SVC_UUID);
  if (!svc) {
    Serial.println("BLE: createService FAILED");
    return;
  }

  // Notifications carry only BPM so they fit one ATT packet at the default MTU.
  hrChar = svc.createCharacteristic(HR_CHAR_UUID,
                                    BLEProperty::Read | BLEProperty::Notify,
                                    BLEPermission::ReadOpen);
  // Present for protocol compatibility; this hardware has no SpO2 source.
  spo2Char = svc.createCharacteristic(SPO2_CHAR_UUID,
                                      BLEProperty::Read | BLEProperty::Notify,
                                      BLEPermission::ReadOpen);
  // Present for protocol compatibility; this hardware has no temp source.
  tempChar = svc.createCharacteristic(TEMP_CHAR_UUID,
                                      BLEProperty::Read | BLEProperty::Notify,
                                      BLEPermission::ReadOpen);

  if (!hrChar || !spo2Char || !tempChar) {
    Serial.println("BLE: createCharacteristic FAILED");
    return;
  }

  BTStatus serverStatus = server.start();
  Serial.printf("BLE: server.start %s\n", serverStatus ? "ok" : serverStatus.toString());

  BLEAdvertising adv = BLE.getAdvertising();
  adv.addServiceUUID(SVC_UUID);
  adv.setName(DEVICE_NAME);
  adv.setScanResponse(true);
  BTStatus advStatus = adv.start();
  Serial.printf("BLE: advertising %s as \"%s\"\n",
                advStatus ? "started" : advStatus.toString(), DEVICE_NAME);
}

void publish(int bpm) {
  char json[24];
  int len = snprintf(json, sizeof(json), "{\"bpm\":%d}", bpm);

  hrChar.setValue((const uint8_t*)json, (size_t)len);
  hrChar.notify();

  Serial.printf("DATA bpm=%d dc=%.0fmV ac=%.1fmV env=%.1fmV\n",
                bpm, lastDcMv, lastAcMv, lastEnvMv);
}

// ------------------------------------------------------------------------ setup
void setup() {
  Serial.begin(115200);
  uint32_t waitStart = millis();
  while (!Serial && millis() - waitStart < 1500) delay(10);

  Serial.println();
  Serial.println("=== ESP32-C6 Heart Rate Monitor (analog pulse sensor) ===");
  Serial.printf("chip: %s  cores: %d  reset: %s\n",
                ESP.getChipModel(), ESP.getChipCores(), resetReasonName());
  Serial.printf("signal pin: GPIO%d  sample rate: %u Hz\n",
                HRM_SIGNAL_PIN, (unsigned)(1000000UL / SAMPLE_INTERVAL_US));

  analogReadResolution(12);
  analogSetPinAttenuation(HRM_SIGNAL_PIN, ADC_11db);

  // Seed the baseline from real samples so detection starts from the measured
  // mid-rail voltage rather than the hard-coded default.
  float sum = 0.0f;
  for (int i = 0; i < 64; i++) {
    sum += (float)analogReadMilliVolts(HRM_SIGNAL_PIN);
    delay(3);
  }
  dcLevel = sum / 64.0f;
  Serial.printf("baseline: %.0f mV\n", dcLevel);
  hrmPrintPinHint(dcLevel);

  setupBle();
  Serial.println("=== ready ===");
}

// ------------------------------------------------------------------------- loop
void loop() {
  static uint32_t nextSampleUs = 0;
  static uint32_t lastSend = 0;
  static uint32_t lastDebug = 0;
  static uint32_t lastStatus = 0;
  uint32_t nowUs = micros();
  uint32_t now = millis();

  if ((int32_t)(nowUs - nextSampleUs) >= 0) {
    nextSampleUs = nowUs + SAMPLE_INTERVAL_US;
    processSample();
  }

  // A silent sensor must not keep reporting a stale rate.
  if (lastBeatMs != 0 && now - lastBeatMs > BEAT_TIMEOUT_MS) {
    lastBeatMs = 0;
    resetIntervals();
  }
  if (leadOff) resetIntervals();

  if (clientConnected && now - lastSend >= SEND_INTERVAL_MS) {
    lastSend = now;
    lastBpm = beatBpm;
    publish(lastBpm);
  }

  if (now - lastDebug >= 2000) {
    lastDebug = now;
    // The window check re-evaluates the live baseline, so a wire made after
    // boot still shows up here even though setup() already printed once.
    hrmPrintPinHint(lastDcMv);
    hrmPrintPinOk(lastDcMv);
    Serial.printf("SENSOR dc=%.0fmV ac=%.1fmV env=%.1fmV lead_off=%d beats=%u bpm=%d age=%ldms\n",
                  lastDcMv, lastAcMv, lastEnvMv, leadOff ? 1 : 0, intervalCount,
                  beatBpm, lastBeatMs == 0 ? -1L : (long)(now - lastBeatMs));
  }

  if (now - lastStatus >= STATUS_INTERVAL_MS) {
    lastStatus = now;
    Serial.printf("STATUS ble_client=%d bpm=%d heap=%u\n",
                  clientConnected ? 1 : 0, lastBpm, (unsigned)ESP.getFreeHeap());
  }
}
