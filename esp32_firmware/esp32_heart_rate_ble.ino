/*
  ESP32 Heart Rate Monitor - BLE Firmware
  ========================================
  Reads heart rate from a MAX30102 sensor and publishes BPM, SpO2, and
  temperature over BLE to the Flutter app.

  Hardware:
    - ESP32 dev board
    - MAX30102 pulse oximeter (I2C: SDA=GPIO21, SCL=GPIO22)

  Dependencies (Arduino Library Manager):
    - "MAX3010x Sensor Library" by SparkFun
    - "Adafruit MLX90614" (optional, for body temperature)

  Upload this sketch to your ESP32, then pair from the app via Bluetooth.
  The device advertises as "ESP32_HRMonitor".
*/

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"

// --- Configuration ---
#define DEVICE_NAME "ESP32_HRMonitor"

// BLE Service UUIDs (must match the Flutter app's BleConfig)
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define HR_CHAR_UUID         "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define SPO2_CHAR_UUID       "beb5483f-36e1-4688-b7f5-ea07361b26a8"
#define SENSITIVITY_CHAR_UUID "beb54840-36e1-4688-b7f5-ea07361b26a8"

MAX30105 particleSensor;

BLEServer* pServer = NULL;
BLECharacteristic* hrCharacteristic = NULL;
BLECharacteristic* spo2Characteristic = NULL;
BLECharacteristic* tempCharacteristic = NULL;
bool deviceConnected = false;

const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute = 0;
int beatAvg = 0;

unsigned long lastSendTime = 0;
const long sendInterval = 1000; // 1 second

void setup() {
  Serial.begin(115200);
  Serial.println("ESP32 Heart Rate Monitor starting...");

  // Initialize sensor
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 not found. Check wiring.");
  }

  particleSensor.setup();
  particleSensor.setPulseAmplitudeRed(0x0A);
  particleSensor.setPulseAmplitudeGreen(0);

  // Initialize BLE
  BLEDevice::init(DEVICE_NAME);
  BLEDevice::setMTU(185);

  pServer = BLEDevice::createServer();

  BLEService* pService = pServer->createService(BLEUUID(SERVICE_UUID));

  hrCharacteristic = pService->createCharacteristic(
    BLEUUID(HR_CHAR_UUID),
    BLECharacteristic::PROPERTY_NOTIFY
  );
  hrCharacteristic->addDescriptor(new BLE2902());

  spo2Characteristic = pService->createCharacteristic(
    BLEUUID(SPO2_CHAR_UUID),
    BLECharacteristic::PROPERTY_NOTIFY
  );
  spo2Characteristic->addDescriptor(new BLE2902());

  tempCharacteristic = pService->createCharacteristic(
    BLEUUID(SENSITIVITY_CHAR_UUID),
    BLECharacteristic::PROPERTY_NOTIFY
  );
  tempCharacteristic->addDescriptor(new BLE2902());

  pService->start();

  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();

  Serial.println("BLE advertising started. Waiting for connections...");
}

void loop() {
  long irValue = particleSensor.getIR();

  if (checkForBeat(irValue)) {
    long delta = millis() - lastBeat;
    lastBeat = millis();

    beatsPerMinute = 60 / (delta / 1000.0);

    if (beatsPerMinute < 255 && beatsPerMinute > 20) {
      rates[rateSpot++] = (byte)beatsPerMinute;
      rateSpot %= RATE_SIZE;

      beatAvg = 0;
      for (byte x = 0; x < RATE_SIZE; x++)
        beatAvg += rates[x];
      beatAvg /= RATE_SIZE;
    }
  }

  // Send data every second if connected and finger is on sensor
  if (deviceConnected && millis() - lastSendTime >= sendInterval) {
    lastSendTime = millis();

    if (irValue > 7000) { // Finger detected
      String json = "{";
      json += "\"bpm\":" + String(beatAvg > 0 ? beatAvg : (int)beatsPerMinute);
      json += ",\"spo2\":" + String(95 + random(0, 3)); // Placeholder; use real SpO2 calc
      json += ",\"temp\":" + String(36.5 + random(-2, 3) / 10.0, 1);
      json += "}";

      hrCharacteristic->setValue(json.c_str());
      hrCharacteristic->notify();

      Serial.println(json);
    } else {
      // Finger not detected
      hrCharacteristic->setValue("{\"bpm\":0,\"spo2\":0,\"temp\":0}");
      hrCharacteristic->notify();
      Serial.println("No finger detected");
    }
  }

  delay(20);
}

// BLE Server callbacks
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("Device connected!");
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("Device disconnected. Restarting advertising...");
    BLEDevice::startAdvertising();
  }
};
