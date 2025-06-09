#ifndef WIFI_MANAGER_H
#define WIFI_MANAGER_H

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include "config.h"

// Connection states
enum WiFiState {
    WIFI_DISCONNECTED,
    WIFI_CONNECTING,
    WIFI_CONNECTED,
    WIFI_ERROR
};

enum MQTTState {
    MQTT_STATE_DISCONNECTED,
    MQTT_STATE_CONNECTING,
    MQTT_STATE_CONNECTED,
    MQTT_STATE_ERROR
};

class WiFiManager {
private:
    WiFiState wifiState = WIFI_DISCONNECTED;
    MQTTState mqttState = MQTT_STATE_DISCONNECTED;
    
    unsigned long lastWiFiCheck = 0;
    unsigned long lastMQTTCheck = 0;
    unsigned long connectionAttempts = 0;
    
    static const unsigned long WIFI_CHECK_INTERVAL = 10000;  // 10 seconds
    static const unsigned long MQTT_CHECK_INTERVAL = 5000;   // 5 seconds
    static const unsigned long MAX_CONNECTION_ATTEMPTS = 5;
    
    // Connection methods
    bool connectToWiFi();
    bool connectToMQTT();
    void handleWiFiReconnection();
    void handleMQTTReconnection();

public:
    WiFiManager();
    
    // Initialization
    bool begin();
    void reset();
    
    // Connection management
    bool isWiFiConnected();
    bool isMQTTConnected();
    bool isFullyConnected();
    
    void checkConnections();
    void reconnectIfNeeded();
    
    // Status methods
    WiFiState getWiFiState();
    MQTTState getMQTTState();
    String getConnectionStatus();
    int getSignalStrength();
    String getLocalIP();
    
    // MQTT methods
    bool publishData(const String& topic, const String& payload);
    bool publishHealthData(const String& jsonData);
    bool publishHeartbeat();
    bool publishAlert(const String& alertType, const String& message);
    
    // HTTP methods (fallback for MQTT)
    bool sendHTTPData(const String& endpoint, const String& jsonData);
    
    // Utility methods
    void printConnectionInfo();
    void handleMQTTMessage(char* topic, byte* payload, unsigned int length);
};

// Global MQTT callback function
void mqttCallback(char* topic, byte* payload, unsigned int length);

#endif // WIFI_MANAGER_H
