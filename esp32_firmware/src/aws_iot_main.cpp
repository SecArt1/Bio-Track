#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include "config.h"
#include "aws_certificates.h"

// AWS IoT and WiFi clients
WiFiClientSecure wifiClient;
PubSubClient mqttClient(wifiClient);
HTTPClient httpClient;
Preferences preferences;

// Device state management
struct DeviceState {
    bool isWiFiConnected = false;
    bool isAWSIoTConnected = false;
    bool isFirebaseConnected = false;
    String userId = USER_ID_PLACEHOLDER;
    String deviceStatus = "offline";
    unsigned long lastHeartbeat = 0;
    unsigned long lastSensorRead = 0;
    float lastTemperature = 0.0;
    float lastWeight = 0.0;
    float lastBioimpedance = 0.0;
    float lastSpO2 = 0.0;
    int heartRate = 0;
    String currentCommand = "";
    String lastError = "";
} deviceState;

// Function declarations
void connectToWiFi();
void setupAWSIoT();
void configureAWSIoT();
void connectToAWSIoT();
void onMQTTMessage(char* topic, byte* payload, unsigned int length);
void publishSensorData(String sensorType, float value, String unit, JsonObject metadata);
void publishDeviceStatus(String status);
void updateDeviceShadow();
void handleCommand(DynamicJsonDocument& doc);
void handleShadowDelta(DynamicJsonDocument& doc);
void pairDeviceToUser(String userId, String requestId);
void runSensorTest(String sensorType, String requestId);
void calibrateSensor(String sensorType, String requestId);
void readAndPublishSensors();
void initializeSensors();
void sendResponseToAWS(String command, String status, JsonObject data);
void syncToFirebase();

// Sensor reading functions (implement based on your hardware)
float readTemperatureSensor();
float readWeightSensor();
float readBioimpedanceSensor();
float readSpO2Sensor();
int readHeartRateSensor();

void setupAWSIoT() {
    Serial.begin(115200);
    Serial.println("\n🚀 BioTrack Device Starting...");
    
    // Initialize preferences for persistent storage
    preferences.begin("biotrack", false);
    deviceState.userId = preferences.getString("userId", USER_ID_PLACEHOLDER);
    
    // Connect to WiFi
    connectToWiFi();
      // Setup AWS IoT Core
    configureAWSIoT();
    
    // Connect to AWS IoT
    connectToAWSIoT();
    
    // Initialize sensors
    initializeSensors();
    
    // Set initial device status
    deviceState.deviceStatus = "online";
    publishDeviceStatus("online");
    
    Serial.println("✅ BioTrack device ready for operation");
    Serial.println("📋 Device ID: " + String(DEVICE_ID));
    Serial.println("👤 User ID: " + deviceState.userId);
}

void connectToWiFi() {
    Serial.println("🌐 Connecting to WiFi: " + String(WIFI_SSID));
    
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    unsigned long startTime = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - startTime < WIFI_CONNECT_TIMEOUT) {
        delay(1000);
        Serial.print(".");
    }
    
    if (WiFi.status() == WL_CONNECTED) {
        deviceState.isWiFiConnected = true;
        Serial.println("\n✅ WiFi connected successfully");
        Serial.println("📍 IP Address: " + WiFi.localIP().toString());
        Serial.println("📶 Signal Strength: " + String(WiFi.RSSI()) + " dBm");
    } else {
        deviceState.isWiFiConnected = false;
        deviceState.lastError = "WiFi connection failed";
        Serial.println("\n❌ WiFi connection failed");
    }
}

void configureAWSIoT() {
    Serial.println("🔧 Setting up AWS IoT Core connection...");
    
    // Configure secure WiFi client with certificates
    wifiClient.setCACert(aws_root_ca_pem);
    wifiClient.setCertificate(certificate_pem_crt);
    wifiClient.setPrivateKey(private_pem_key);
    
    // Configure MQTT client
    mqttClient.setServer(AWS_IOT_ENDPOINT, AWS_IOT_PORT);
    mqttClient.setCallback(onMQTTMessage);
    mqttClient.setBufferSize(2048);
    mqttClient.setKeepAlive(60);
    
    Serial.println("🔐 AWS IoT certificates configured");
}

void connectToAWSIoT() {
    while (!mqttClient.connected() && deviceState.isWiFiConnected) {
        Serial.println("🔗 Connecting to AWS IoT Core...");
        Serial.println("🌐 Endpoint: " + String(AWS_IOT_ENDPOINT));
        
        if (mqttClient.connect(AWS_IOT_CLIENT_ID)) {
            deviceState.isAWSIoTConnected = true;
            Serial.println("✅ Connected to AWS IoT Core");
            
            // Subscribe to command topics
            String commandTopic = String(TOPIC_COMMANDS) + "/+";
            mqttClient.subscribe(commandTopic.c_str());
            Serial.println("📥 Subscribed to: " + commandTopic);
            
            // Subscribe to shadow deltas
            String shadowDelta = "$aws/thing/" + String(AWS_IOT_THING_NAME) + "/shadow/update/delta";
            mqttClient.subscribe(shadowDelta.c_str());
            Serial.println("📥 Subscribed to: " + shadowDelta);
            
            // Subscribe to shadow accepted
            String shadowAccepted = "$aws/thing/" + String(AWS_IOT_THING_NAME) + "/shadow/update/accepted";
            mqttClient.subscribe(shadowAccepted.c_str());
            
            // Publish initial device status
            publishDeviceStatus("online");
            updateDeviceShadow();
            
        } else {
            deviceState.isAWSIoTConnected = false;
            Serial.printf("❌ AWS IoT connection failed, error code: %d\n", mqttClient.state());
            Serial.println("🔄 Retrying in 5 seconds...");
            delay(5000);
        }
    }
}

void onMQTTMessage(char* topic, byte* payload, unsigned int length) {
    String message = "";
    for (int i = 0; i < length; i++) {
        message += (char)payload[i];
    }
    
    Serial.println("📥 MQTT Message Received:");
    Serial.println("📍 Topic: " + String(topic));
    Serial.println("💬 Payload: " + message);
      // Parse JSON message
    DynamicJsonDocument doc(1024);
    DeserializationError error = deserializeJson(doc, message);
    
    if (error) {
        Serial.println("❌ Failed to parse JSON message: " + String(error.c_str()));
        return;
    }
    
    // Handle different message types
    String topicStr = String(topic);
    
    if (topicStr.indexOf("/commands/") > 0) {
        handleCommand(doc);
    } else if (topicStr.indexOf("/shadow/update/delta") > 0) {
        handleShadowDelta(doc);
    } else if (topicStr.indexOf("/shadow/update/accepted") > 0) {
        Serial.println("✅ Shadow update accepted");
    }
}

void handleCommand(DynamicJsonDocument& doc) {
    String command = doc["command"];
    String requestId = doc["requestId"] | String(millis());
    String userId = doc["userId"] | "";
    
    Serial.println("🎯 Processing command: " + command);
    deviceState.currentCommand = command;
    
    if (command == "pair_device") {
        pairDeviceToUser(userId, requestId);
    } else if (command == "test_sensor") {
        String sensorType = doc["sensorType"] | "all";
        runSensorTest(sensorType, requestId);
    } else if (command == "calibrate") {
        String sensorType = doc["sensorType"] | "all";
        calibrateSensor(sensorType, requestId);
    } else if (command == "ping") {        // Respond to ping immediately
        DynamicJsonDocument response(512);
        response["command"] = "ping";
        response["requestId"] = requestId;
        response["status"] = "success";
        response["deviceId"] = DEVICE_ID;
        response["timestamp"] = millis();
        response["responseTime"] = 50; // Simulated response time
        
        String responsePayload;
        serializeJson(response, responsePayload);
        
        String responseTopic = String(TOPIC_RESPONSES) + "/ping";
        mqttClient.publish(responseTopic.c_str(), responsePayload.c_str());
        
        Serial.println("🏓 Ping response sent");
    } else if (command == "get_status") {
        publishDeviceStatus(deviceState.deviceStatus);
        updateDeviceShadow();
    } else {
        Serial.println("⚠️ Unknown command: " + command);
    }
}

void handleShadowDelta(DynamicJsonDocument& doc) {
    Serial.println("🔄 Processing shadow delta update");
    
    if (doc["state"].containsKey("userId")) {
        String newUserId = doc["state"]["userId"];
        if (newUserId != deviceState.userId) {
            deviceState.userId = newUserId;
            preferences.putString("userId", newUserId);
            Serial.println("👤 User ID updated via shadow: " + newUserId);
        }
    }
    
    if (doc["state"].containsKey("sampleRate")) {
        int newSampleRate = doc["state"]["sampleRate"];
        Serial.println("⏱️ Sample rate updated via shadow: " + String(newSampleRate) + "ms");
        // Update sample rate logic here
    }
}

void pairDeviceToUser(String userId, String requestId) {
    Serial.println("👥 Pairing device to user: " + userId);
    
    // Store user ID persistently
    deviceState.userId = userId;
    preferences.putString("userId", userId);
    
    // Update device shadow
    updateDeviceShadow();
      // Send pairing confirmation
    DynamicJsonDocument response(512);
    response["command"] = "pair_device";
    response["requestId"] = requestId;
    response["status"] = "success";
    response["deviceId"] = DEVICE_ID;
    response["userId"] = userId;
    response["timestamp"] = millis();
    response["firmwareVersion"] = FIRMWARE_VERSION;
    
    String responsePayload;
    serializeJson(response, responsePayload);
    
    String responseTopic = String(TOPIC_RESPONSES) + "/pair_device";
    mqttClient.publish(responseTopic.c_str(), responsePayload.c_str());
      // Also sync to AWS IoT Core for app integration
    sendResponseToAWS("pair_device", "success", response.as<JsonObject>());
    
    Serial.println("✅ Device successfully paired to user: " + userId);
}

void runSensorTest(String sensorType, String requestId) {    Serial.println("🧪 Running sensor test: " + sensorType);
    
    DynamicJsonDocument response(1024);
    response["command"] = "test_sensor";
    response["requestId"] = requestId;
    response["sensorType"] = sensorType;
    response["deviceId"] = DEVICE_ID;
    response["timestamp"] = millis();
    
    if (sensorType == "temperature" || sensorType == "all") {
        float temp = readTemperatureSensor();
        response["results"]["temperature"]["value"] = temp;
        response["results"]["temperature"]["unit"] = "°C";
        response["results"]["temperature"]["status"] = "success";
        
        publishSensorData("temperature", temp, "°C", response["results"]["temperature"].as<JsonObject>());
    }
    
    if (sensorType == "weight" || sensorType == "all") {
        float weight = readWeightSensor();
        response["results"]["weight"]["value"] = weight;
        response["results"]["weight"]["unit"] = "kg";
        response["results"]["weight"]["status"] = "success";
        
        publishSensorData("weight", weight, "kg", response["results"]["weight"].as<JsonObject>());
    }
    
    if (sensorType == "bioimpedance" || sensorType == "all") {
        float bioimpedance = readBioimpedanceSensor();
        response["results"]["bioimpedance"]["value"] = bioimpedance;
        response["results"]["bioimpedance"]["unit"] = "Ω";
        response["results"]["bioimpedance"]["status"] = "success";
        
        publishSensorData("bioimpedance", bioimpedance, "Ω", response["results"]["bioimpedance"].as<JsonObject>());
    }
    
    if (sensorType == "spo2" || sensorType == "all") {
        float spo2 = readSpO2Sensor();
        int heartRate = readHeartRateSensor();
        response["results"]["spo2"]["value"] = spo2;
        response["results"]["spo2"]["unit"] = "%";
        response["results"]["spo2"]["heartRate"] = heartRate;
        response["results"]["spo2"]["status"] = "success";
        
        JsonObject metadata = response["results"]["spo2"].as<JsonObject>();
        publishSensorData("spo2", spo2, "%", metadata);
    }
    
    response["status"] = "success";
    response["message"] = "Sensor test completed successfully";
    
    String responsePayload;
    serializeJson(response, responsePayload);
    
    String responseTopic = String(TOPIC_RESPONSES) + "/test_sensor";
    mqttClient.publish(responseTopic.c_str(), responsePayload.c_str());
      // Sync to AWS IoT Core
    sendResponseToAWS("test_sensor", "success", response.as<JsonObject>());
    
    Serial.println("✅ Sensor test completed: " + sensorType);
}

void calibrateSensor(String sensorType, String requestId) {
    Serial.println("🎯 Calibrating sensor: " + sensorType);
      // Implement sensor calibration logic here
    // This is a placeholder implementation
    
    DynamicJsonDocument response(512);
    response["command"] = "calibrate";
    response["requestId"] = requestId;
    response["sensorType"] = sensorType;
    response["status"] = "success";
    response["message"] = "Sensor calibration completed";
    response["deviceId"] = DEVICE_ID;
    response["timestamp"] = millis();
    
    String responsePayload;
    serializeJson(response, responsePayload);
    
    String responseTopic = String(TOPIC_RESPONSES) + "/calibrate";
    mqttClient.publish(responseTopic.c_str(), responsePayload.c_str());
    
    Serial.println("✅ Sensor calibration completed: " + sensorType);
}

void publishSensorData(String sensorType, float value, String unit, JsonObject metadata) {
    if (!mqttClient.connected()) return;
    
    DynamicJsonDocument telemetryDoc(1024);
    telemetryDoc["deviceId"] = DEVICE_ID;
    telemetryDoc["sensorType"] = sensorType;
    telemetryDoc["value"] = value;
    telemetryDoc["unit"] = unit;
    telemetryDoc["timestamp"] = millis();
    telemetryDoc["userId"] = deviceState.userId;
    telemetryDoc["firmwareVersion"] = FIRMWARE_VERSION;
    
    // Add metadata if provided
    if (!metadata.isNull()) {
        telemetryDoc["metadata"] = metadata;
    }
    
    // Add quality assessment
    telemetryDoc["quality"] = "good"; // Implement actual quality assessment
    telemetryDoc["calibrated"] = true;
    
    String telemetryPayload;
    serializeJson(telemetryDoc, telemetryPayload);
    
    // Publish to AWS IoT
    String topic = String(TOPIC_TELEMETRY) + "/" + sensorType;
    bool published = mqttClient.publish(topic.c_str(), telemetryPayload.c_str(), true);
    
    if (published) {
        Serial.println("📊 Published telemetry: " + topic + " -> " + String(value) + unit);
    } else {
        Serial.println("❌ Failed to publish telemetry for: " + sensorType);
    }
}

void publishDeviceStatus(String status) {
    if (!mqttClient.connected()) return;
    
    deviceState.deviceStatus = status;
      DynamicJsonDocument statusDoc(1024);
    statusDoc["deviceId"] = DEVICE_ID;
    statusDoc["status"] = status;
    statusDoc["timestamp"] = millis();
    statusDoc["userId"] = deviceState.userId;
    statusDoc["firmwareVersion"] = FIRMWARE_VERSION;
    statusDoc["wifiRSSI"] = WiFi.RSSI();
    statusDoc["freeMemory"] = ESP.getFreeHeap();
    statusDoc["uptime"] = millis();
    statusDoc["ipAddress"] = WiFi.localIP().toString();
    
    String statusPayload;
    serializeJson(statusDoc, statusPayload);
    
    bool published = mqttClient.publish(TOPIC_STATUS, statusPayload.c_str(), true);
    
    if (published) {
        Serial.println("📋 Device status published: " + status);
    } else {
        Serial.println("❌ Failed to publish device status");
    }
}

void updateDeviceShadow() {
    if (!mqttClient.connected()) return;
      DynamicJsonDocument shadowDoc(1024);
    shadowDoc["state"]["reported"]["deviceId"] = DEVICE_ID;
    shadowDoc["state"]["reported"]["status"] = deviceState.deviceStatus;
    shadowDoc["state"]["reported"]["userId"] = deviceState.userId;
    shadowDoc["state"]["reported"]["firmwareVersion"] = FIRMWARE_VERSION;
    shadowDoc["state"]["reported"]["lastUpdate"] = millis();
    shadowDoc["state"]["reported"]["wifiRSSI"] = WiFi.RSSI();
    shadowDoc["state"]["reported"]["freeMemory"] = ESP.getFreeHeap();
    shadowDoc["state"]["reported"]["ipAddress"] = WiFi.localIP().toString();
    
    // Add latest sensor readings
    shadowDoc["state"]["reported"]["sensors"]["temperature"] = deviceState.lastTemperature;
    shadowDoc["state"]["reported"]["sensors"]["weight"] = deviceState.lastWeight;
    shadowDoc["state"]["reported"]["sensors"]["bioimpedance"] = deviceState.lastBioimpedance;
    shadowDoc["state"]["reported"]["sensors"]["spo2"] = deviceState.lastSpO2;
    shadowDoc["state"]["reported"]["sensors"]["heartRate"] = deviceState.heartRate;
    
    String shadowPayload;
    serializeJson(shadowDoc, shadowPayload);
    
    bool published = mqttClient.publish(TOPIC_SHADOW_UPDATE, shadowPayload.c_str());
    
    if (published) {
        Serial.println("🌙 Device shadow updated");
    } else {
        Serial.println("❌ Failed to update device shadow");
    }
}

void readAndPublishSensors() {
    Serial.println("📊 Reading sensors...");
    
    // Read all sensors
    deviceState.lastTemperature = readTemperatureSensor();
    deviceState.lastWeight = readWeightSensor();
    deviceState.lastBioimpedance = readBioimpedanceSensor();
    deviceState.lastSpO2 = readSpO2Sensor();
    deviceState.heartRate = readHeartRateSensor();
      // Publish sensor data
    DynamicJsonDocument metadata(512);
    metadata["quality"] = "good";
    metadata["calibrated"] = true;
    metadata["automatic"] = true;
    
    publishSensorData("temperature", deviceState.lastTemperature, "°C", metadata.as<JsonObject>());
    publishSensorData("weight", deviceState.lastWeight, "kg", metadata.as<JsonObject>());
    publishSensorData("bioimpedance", deviceState.lastBioimpedance, "Ω", metadata.as<JsonObject>());
    
    metadata["heartRate"] = deviceState.heartRate;
    publishSensorData("spo2", deviceState.lastSpO2, "%", metadata.as<JsonObject>());
    
    // Update device shadow
    updateDeviceShadow();
    
    Serial.println("✅ Sensor reading cycle completed");
}

void sendResponseToAWS(String command, String status, JsonObject data) {
    if (deviceState.userId == USER_ID_PLACEHOLDER) {
        Serial.println("⚠️ Device not paired, skipping AWS sync");
        return;
    }
    
    // Send response data to AWS IoT Core via MQTT
    String responseTopic = "biotrack/device/" + String(DEVICE_ID) + "/responses";
    
    DynamicJsonDocument responseDoc(1024);
    responseDoc["command"] = command;
    responseDoc["status"] = status;
    responseDoc["data"] = data;
    responseDoc["timestamp"] = millis();
    responseDoc["deviceId"] = DEVICE_ID;
    
    String responsePayload;
    serializeJson(responseDoc, responsePayload);
    
    if (mqttClient.publish(responseTopic.c_str(), responsePayload.c_str())) {
        Serial.println("✅ Response sent to AWS IoT Core: " + command);
    } else {
        Serial.println("❌ Failed to send response to AWS IoT Core");
    }
}

void initializeSensors() {
    Serial.println("🔧 Initializing sensors...");
    
    // Initialize sensor pins and libraries
    // Implementation depends on your specific sensors
    
    Serial.println("✅ Sensors initialized");
}

void loopAWSIoT() {
    // Maintain AWS IoT connection
    if (!mqttClient.connected() && deviceState.isWiFiConnected) {
        Serial.println("🔄 AWS IoT disconnected, reconnecting...");
        connectToAWSIoT();
    }
    
    // Process MQTT messages
    mqttClient.loop();
    
    // Check WiFi connection
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("🔄 WiFi disconnected, reconnecting...");
        deviceState.isWiFiConnected = false;
        deviceState.isAWSIoTConnected = false;
        connectToWiFi();
        if (deviceState.isWiFiConnected) {
            connectToAWSIoT();
        }
    }
    
    // Periodic sensor readings
    if (millis() - deviceState.lastSensorRead > SENSOR_SAMPLE_RATE) {
        readAndPublishSensors();
        deviceState.lastSensorRead = millis();
    }
    
    // Periodic heartbeat
    if (millis() - deviceState.lastHeartbeat > HEARTBEAT_INTERVAL) {
        publishDeviceStatus(deviceState.deviceStatus);
        deviceState.lastHeartbeat = millis();
    }
    
    // Small delay to prevent watchdog issues
    delay(100);
}

// Sensor reading implementations (replace with actual sensor code)
float readTemperatureSensor() {
    // Implement actual DS18B20 reading
    return 36.5 + (random(-10, 10) / 10.0); // Simulated value
}

float readWeightSensor() {
    // Implement actual HX711 reading
    return 70.0 + (random(-50, 50) / 10.0); // Simulated value
}

float readBioimpedanceSensor() {
    // Implement actual BIA reading
    return 500.0 + (random(-100, 100)); // Simulated value
}

float readSpO2Sensor() {
    // Implement actual MAX30102 SpO2 reading
    return 97.0 + (random(-20, 20) / 10.0); // Simulated value
}

int readHeartRateSensor() {
    // Implement actual MAX30102 heart rate reading
    return 72 + random(-10, 10); // Simulated value
}
