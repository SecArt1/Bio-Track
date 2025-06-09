#ifndef SECURE_NETWORK_H
#define SECURE_NETWORK_H

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <esp_wifi.h>
#include <esp_task_wdt.h>
#include "config.h"

// Network states
enum NetworkState {
    NETWORK_IDLE,
    NETWORK_CONNECTING,
    NETWORK_CONNECTED,
    NETWORK_AUTHENTICATED,
    NETWORK_ERROR,
    NETWORK_DISCONNECTED
};

// Security levels
enum SecurityLevel {
    SECURITY_NONE,
    SECURITY_WPA2,
    SECURITY_TLS_BASIC,
    SECURITY_TLS_VERIFIED
};

// Data transmission priority
enum TransmissionPriority {
    PRIORITY_LOW,
    PRIORITY_NORMAL,
    PRIORITY_HIGH,
    PRIORITY_CRITICAL
};

class SecureNetworkManager {
private:
    NetworkState currentState;
    SecurityLevel securityLevel;
    Preferences nvs;
    WiFiClientSecure secureClient;
    HTTPClient httpClient;
    
    // Connection management
    unsigned long lastConnectionAttempt;
    unsigned long lastHeartbeat;
    unsigned long lastReconnectAttempt;
    int connectionRetries;
    int maxRetries;
    
    // Certificate and authentication
    String firebaseIdToken;
    String deviceAuthToken;
    unsigned long tokenExpiry;
    
    // Network statistics
    struct NetworkStats {
        unsigned long totalBytesSent;
        unsigned long totalBytesReceived;
        unsigned long successfulRequests;
        unsigned long failedRequests;
        int signalStrength;
        float dataRate;
    } stats;
    
    // Queue for outgoing data
    struct QueuedData {
        String payload;
        String endpoint;
        TransmissionPriority priority;
        unsigned long timestamp;
        int retryCount;
    };
    
    static const int MAX_QUEUE_SIZE = 50;
    QueuedData dataQueue[MAX_QUEUE_SIZE];
    int queueHead;
    int queueTail;
    int queueSize;
    
    // Private methods
    bool initializeSecureConnection();
    bool loadStoredCredentials();
    void storeCredentials();
    bool verifyFirebaseCertificate();
    bool authenticateDevice();
    bool refreshAuthToken();
    void handleConnectionError(String error);
    void implementExponentialBackoff();
    bool sendHTTPRequest(String endpoint, String payload, String& response);
    void processDataQueue();
    bool queueData(String payload, String endpoint, TransmissionPriority priority);
    void updateNetworkStatistics(bool success, size_t bytes);
    void monitorNetworkHealth();
    
public:
    SecureNetworkManager();
    ~SecureNetworkManager();
    
    // Core networking functions
    bool begin();
    bool connectToWiFi();
    bool establishSecureConnection();
    void checkConnections();
    void disconnect();
    void handleNetworkTasks();
    
    // Authentication and security
    bool performDeviceAuthentication();
    bool validateServerCertificate();
    SecurityLevel getCurrentSecurityLevel();
    void enableCertificatePinning();
    
    // Data transmission
    bool sendSensorData(String jsonData, TransmissionPriority priority = PRIORITY_NORMAL);
    bool sendHeartbeat(String deviceStatus);
    bool sendAlert(String alertData, TransmissionPriority priority = PRIORITY_CRITICAL);
    bool checkForOTAUpdates(String& updateInfo);
    
    // Queue management
    bool hasQueuedData();
    int getQueueSize();
    void clearQueue();
    void prioritizeQueue();
    
    // Status and diagnostics
    NetworkState getNetworkState();
    NetworkStats getNetworkStatistics();
    String getConnectionInfo();
    bool isFullyConnected();
    bool isSecureConnection();
    int getSignalStrength();
    String getNetworkDiagnostics();
    
    // Configuration
    void setMaxRetries(int retries);
    void setConnectionTimeout(unsigned long timeout);
    void enableVerboseLogging(bool enable);
    
    // Error handling and recovery
    void handleNetworkError(String error);
    bool performNetworkReset();
    void logNetworkEvent(String event, String details = "");
};

// Firebase certificate (for certificate pinning)
extern const char* firebase_root_ca;

// Utility functions
String generateDeviceSignature(String data);
bool validateResponseSignature(String response, String signature);
String encryptSensitiveData(String data);
String decryptSensitiveData(String encryptedData);

#endif // SECURE_NETWORK_H
