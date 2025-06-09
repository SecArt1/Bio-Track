#ifndef CLOUD_MQTT_CLIENT_H
#define CLOUD_MQTT_CLIENT_H

#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/semphr.h"

struct CloudMessage {
    String topic;
    String payload;
    bool retained;
    uint8_t qos;
    uint32_t timestamp;
};

class SecureMQTTClient {
private:
    WiFiClientSecure wifiClient;
    PubSubClient mqttClient;
    Preferences nvs;
    
    QueueHandle_t messageQueue;
    QueueHandle_t retryQueue;
    SemaphoreHandle_t clientMutex;
    TaskHandle_t publishTaskHandle;
    
    String deviceID;
    String projectID;
    String region;
    String registryID;
    
    bool isConnected;
    uint8_t reconnectAttempts;
    uint32_t lastHeartbeat;
    
    // TLS certificate pinning
    const char* rootCACert;
    const char* deviceCert;
    const char* deviceKey;
    
    static const uint8_t MAX_RECONNECT_ATTEMPTS = 5;
    static const uint32_t HEARTBEAT_INTERVAL = 30000; // 30 seconds
    static const size_t MESSAGE_QUEUE_SIZE = 20;
    static const size_t RETRY_QUEUE_SIZE = 10;
    
public:
    SecureMQTTClient();
    ~SecureMQTTClient();
    
    bool begin();
    bool connect();
    bool disconnect();
    bool isClientConnected();
    
    // Certificate management
    bool setCertificates(const char* rootCA, const char* cert, const char* key);
    bool loadCertificatesFromNVS();
    bool storeCertificatesInNVS(const char* rootCA, const char* cert, const char* key);
    
    // Device configuration
    bool setDeviceConfig(const String& deviceId, const String& projectId, 
                        const String& regionId, const String& registryId);
    
    // Publishing
    bool publishSensorData(const String& jsonPayload);
    bool publishHeartbeat();
    bool publishAlert(const String& alertType, float value, const String& severity);
    bool publishMessage(const String& topic, const String& payload, bool retained = false);
    
    // Subscription and command handling
    bool subscribeToCommands();
    void setCommandCallback(std::function<void(String, String)> callback);
    
    // Queue management
    bool enqueueMessage(const String& topic, const String& payload, bool retained = false);
    void processMessageQueue();
    void processRetryQueue();
    
    // Diagnostics
    String getConnectionStatus();
    uint32_t getQueueSize();
    uint32_t getRetryQueueSize();
    
private:
    static void messageCallback(char* topic, byte* payload, unsigned int length);
    static void publishTask(void* parameter);
    
    void handleIncomingMessage(const String& topic, const String& payload);
    void validateAndExecuteCommand(const JsonDocument& command);
    
    String generateJWT();
    String getEventTopic();
    String getCommandTopic();
    String getHeartbeatTopic();
    String getAlertTopic();
    
    bool reconnectWithBackoff();
    void saveFailedMessage(const CloudMessage& message);
    void loadFailedMessages();
    
    std::function<void(String, String)> commandCallback;
};

#endif // CLOUD_MQTT_CLIENT_H
