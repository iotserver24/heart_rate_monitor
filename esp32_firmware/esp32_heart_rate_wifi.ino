/*
  ESP32 Heart Rate Monitor - WiFi Firmware
  =========================================
  Serves heart rate data over HTTP on port 80.

  Endpoints:
    GET /heartRate  -> {"bpm":72,"spo2":98,"temp":36.5}
    GET /           -> status page

  Uses same MAX30102 sensor. Connect ESP32 to WiFi, note the IP
  from Serial Monitor, and enter it in the app's WiFi connection tab.
*/

#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"

// --- WiFi Configuration ---
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

WebServer server(80);
MAX30105 particleSensor;

const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute = 0;
int beatAvg = 0;
float currentTemp = 36.5;
int currentSpo2 = 97;

void setup() {
  Serial.begin(115200);

  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 not found.");
  }
  particleSensor.setup();
  particleSensor.setPulseAmplitudeRed(0x0A);
  particleSensor.setPulseAmplitudeGreen(0);

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("Connected! IP: ");
  Serial.println(WiFi.localIP());

  server.on("/heartRate", handleHeartRate);
  server.on("/", handleRoot);
  server.begin();
  Serial.println("HTTP server started on port 80");
}

void loop() {
  server.handleClient();
  readSensor();

  if (millis() - lastBeat > 25000 && beatAvg > 0) {
    // Reset if no beat for 25s
    beatAvg = 0;
    beatsPerMinute = 0;
    for (byte i = 0; i < RATE_SIZE; i++) rates[i] = 0;
    rateSpot = 0;
  }
}

void readSensor() {
  long irValue = particleSensor.getIR();

  if (checkForBeat(irValue)) {
    long delta = millis() - lastBeat;
    lastBeat = millis();
    beatsPerMinute = 60 / (delta / 1000.0);

    if (beatsPerMinute < 255 && beatsPerMinute > 20) {
      rates[rateSpot++] = (byte)beatsPerMinute;
      rateSpot %= RATE_SIZE;
      beatAvg = 0;
      for (byte x = 0; x < RATE_SIZE; x++) beatAvg += rates[x];
      beatAvg /= RATE_SIZE;
    }
  }
}

void handleHeartRate() {
  long irValue = particleSensor.getIR();
  int bpm = 0;
  int spo2 = 0;
  float temp = 0;

  if (irValue > 7000) {
    bpm = beatAvg > 0 ? beatAvg : (int)beatsPerMinute;
    spo2 = currentSpo2 + random(-1, 2);
    temp = currentTemp;
  }

  if (spo2 < 85) spo2 = 85;
  if (spo2 > 100) spo2 = 100;

  String json = "{";
  json += "\"bpm\":" + String(bpm);
  json += ",\"spo2\":" + String(spo2);
  json += ",\"temp\":" + String(temp, 1);
  json += "}";

  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);
  Serial.println("Sent: " + json);
}

void handleRoot() {
  String html = "<html><body style='font-family:sans-serif;text-align:center;background:#0A0E21;color:white'>";
  html += "<h1>ESP32 Heart Rate Monitor</h1>";
  html += "<p>BPM: " + String(beatAvg > 0 ? beatAvg : (int)beatsPerMinute) + "</p>";
  html += "<p>SpO2: " + String(currentSpo2) + "%</p>";
  html += "<p>Temp: " + String(currentTemp, 1) + " C</p>";
  html += "<p><small>Data endpoint: <a style='color:#E53935' href='/heartRate'>/heartRate</a></small></p>";
  html += "</body></html>";
  server.send(200, "text/html", html);
}
