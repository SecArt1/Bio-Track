#include "wifi_manager.h"

// Global instances for MQTT callback
extern WiFiClientSecure wifiClient;
extern PubSubClient mqttClient;

WiFiManager::WiFiManager() {
    // Constructor
}

bool WiFiManager::begin() {
    Serial.println("🔄 Initializing WiFi Manager...");
    
    // Configure WiFi client for security
    wifiClient.setInsecure(); // For development - use certificates in production
    
    // Configure MQTT client
    mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
    mqttClient.setCallback(mqttCallback);
    mqttClient.setBufferSize(2048);
    
    // Start WiFi connection
    return connectToWiFi();
}

bool WiFiManager::connectToWiFi() {
    Serial.printf("🔄 Connecting to WiFi: %s\n", WIFI_SSID);
    
    wifiState = WIFI_CONNECTING;
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
        delay(1000);
        Serial.print(".");
        attempts++;
    }
    
    if (WiFi.status() == WL_CONNECTED) {
        wifiState = WIFI_CONNECTED;
        Serial.println();
        Serial.printf("✅ WiFi connected! IP: %s\n", WiFi.localIP().toString().c_str());
        Serial.printf("📶 Signal strength: %d dBm\n", WiFi.RSSI());
        
        // Try to connect to MQTT after WiFi is ready
        connectToMQTT();
        return true;
    } else {
        wifiState = WIFI_ERROR;
        Serial.println();
        Serial.println("❌ WiFi connection failed!");
        return false;
    }
}

bool WiFiManager::connectToMQTT() {
    if (wifiState != WIFI_CONNECTED) {
        return false;
    }
    
    Serial.println("🔄 Connecting to MQTT...");
    mqttState = MQTT_STATE_CONNECTING;
    
    String clientId = "biotrack_" + String(DEVICE_ID);
    
    if (mqttClient.connect(clientId.c_str())) {
        mqttState = MQTT_STATE_CONNECTED;
        Serial.println("✅ MQTT connected!");
        
        // Subscribe to device-specific topics
        String deviceTopic = "biotrack/devices/" + String(DEVICE_ID) + "/commands";
        mqttClient.subscribe(deviceTopic.c_str());
        
        // Send connection announcement
        publishHeartbeat();
        return true;
    } else {
        mqttState = MQTT_STATE_ERROR;
        Serial.printf("❌ MQTT connection failed! Error: %d\n", mqttClient.state());
        return false;
    }
}

void WiFiManager::checkConnections() {
    unsigned long currentTime = millis();
    
    // Check WiFi connection
    if (currentTime - lastWiFiCheck > WIFI_CHECK_INTERVAL) {
        if (WiFi.status() != WL_CONNECTED) {
            Serial.println("⚠️ WiFi disconnected, attempting reconnection...");
            wifiState = WIFI_DISCONNECTED;
            connectToWiFi();
        }
        lastWiFiCheck = currentTime;
    }
    
    // Check MQTT connection
    if (currentTime - lastMQTTCheck > MQTT_CHECK_INTERVAL) {
        if (wifiState == WIFI_CONNECTED && !mqttClient.connected()) {
            Serial.println("⚠️ MQTT disconnected, attempting reconnection...");
            mqttState = MQTT_STATE_DISCONNECTED;
            connectToMQTT();
        }
        lastMQTTCheck = currentTime;
    }
    
    // Handle MQTT loop
    if (mqttClient.connected()) {
        mqttClient.loop();
    }
}

bool WiFiManager::publishHealthData(const String& jsonData) {
    if (!isFullyConnected()) {
        return sendHTTPData("/api/health-data", jsonData);
    }
    
    String topic = "biotrack/devices/" + String(DEVICE_ID) + "/health-data";
    return mqttClient.publish(topic.c_str(), jsonData.c_str());
}

bool WiFiManager::publishHeartbeat() {
    if (!isFullyConnected()) {
        return false;
    }
    
    StaticJsonDocument<256> doc;
    doc["deviceId"] = DEVICE_ID;
    doc["timestamp"] = millis();
    doc["version"] = FIRMWARE_VERSION;
    doc["wifiRSSI"] = WiFi.RSSI();
    doc["freeHeap"] = ESP.getFreeHeap();
    doc["uptime"] = millis() / 1000;
    
    String payload;
    serializeJson(doc, payload);
    
    String topic = "biotrack/devices/" + String(DEVICE_ID) + "/heartbeat";
    return mqttClient.publish(topic.c_str(), payload.c_str());
}

bool WiFiManager::publishAlert(const String& alertType, const String& message) {
    StaticJsonDocument<512> doc;
    doc["deviceId"] = DEVICE_ID;
    doc["alertType"] = alertType;
    doc["message"] = message;
    doc["timestamp"] = millis();
    doc["severity"] = "high";
    
    String payload;
    serializeJson(doc, payload);
    
    if (isFullyConnected()) {
        String topic = "biotrack/devices/" + String(DEVICE_ID) + "/alerts";
        return mqttClient.publish(topic.c_str(), payload.c_str());
    } else {
        return sendHTTPData("/api/alerts", payload);
    }
}

bool WiFiManager::sendHTTPData(const String& endpoint, const String& jsonData) {
    if (wifiState != WIFI_CONNECTED) {
        return false;
    }
    
    HTTPClient http;
    http.begin(wifiClient, String("https://") + MQTT_SERVER + endpoint);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("Authorization", "Bearer " + String(FIREBASE_API_KEY));
    
    int httpResponseCode = http.POST(jsonData);
    bool success = (httpResponseCode == 200 || httpResponseCode == 201);
    
    if (!success) {
        Serial.printf("❌ HTTP POST failed: %d\n", httpResponseCode);
    }
    
    http.end();
    return success;
}

bool WiFiManager::isWiFiConnected() {
    return wifiState == WIFI_CONNECTED && WiFi.status() == WL_CONNECTED;
}

bool WiFiManager::isMQTTConnected() {
    return mqttState == MQTT_STATE_CONNECTED && mqttClient.connected();
}

bool WiFiManager::isFullyConnected() {
    return isWiFiConnected() && isMQTTConnected();
}

String WiFiManager::getConnectionStatus() {
    String status = "WiFi: ";
    switch (wifiState) {
        case WIFI_CONNECTED: status += "✅ Connected"; break;
        case WIFI_CONNECTING: status += "🔄 Connecting"; break;
        case WIFI_DISCONNECTED: status += "❌ Disconnected"; break;
        case WIFI_ERROR: status += "❌ Error"; break;
    }
    
    status += " | MQTT: ";
    switch (mqttState) {
        case MQTT_STATE_CONNECTED: status += "✅ Connected"; break;
        case MQTT_STATE_CONNECTING: status += "🔄 Connecting"; break;
        case MQTT_STATE_DISCONNECTED: status += "❌ Disconnected"; break;
        case MQTT_STATE_ERROR: status += "❌ Error"; break;
    }
    
    return status;
}

int WiFiManager::getSignalStrength() {
    return WiFi.RSSI();
}

String WiFiManager::getLocalIP() {
    return WiFi.localIP().toString();
}

void WiFiManager::printConnectionInfo() {
    Serial.println("=== Connection Info ===");
    Serial.printf("WiFi Status: %s\n", getConnectionStatus().c_str());
    Serial.printf("IP Address: %s\n", getLocalIP().c_str());
    Serial.printf("Signal Strength: %d dBm\n", getSignalStrength());
    Serial.printf("MAC Address: %s\n", WiFi.macAddress().c_str());
    Serial.println("=======================");
}

bool WiFiManager::publishData(const String& topic, const String& payload) {
    if (!isFullyConnected()) {
        return false;
    }
    
    bool success = mqttClient.publish(topic.c_str(), payload.c_str());
    if (success) {
        Serial.println("✅ Data published to topic: " + topic);
    } else {
        Serial.println("❌ Failed to publish to topic: " + topic);
    }
    
    return success;
}

// Global MQTT callback function
void mqttCallback(char* topic, byte* payload, unsigned int length) {
    Serial.printf("📨 MQTT message received [%s]: ", topic);
    
    String message = "";
    for (unsigned int i = 0; i < length; i++) {
        message += (char)payload[i];
    }
    Serial.println(message);
    
    // Parse and handle commands
    StaticJsonDocument<512> doc;
    DeserializationError error = deserializeJson(doc, message);
    
    if (!error) {
        String command = doc["command"];
        
        if (command == "restart") {
            Serial.println("🔄 Restart command received");
            ESP.restart();
        } else if (command == "calibrate") {
            Serial.println("🔧 Calibration command received");
            // Handle calibration command
        } else if (command == "update_config") {
            Serial.println("⚙️ Configuration update received");
            // Handle configuration update
        }
    }
}
