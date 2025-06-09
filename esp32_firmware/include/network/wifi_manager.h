#ifndef NETWORK_WIFI_MANAGER_H
#define NETWORK_WIFI_MANAGER_H

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <Preferences.h>
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"

class SecureWiFiManager {
private:
    Preferences nvs;
    static EventGroupHandle_t wifiEventGroup; // Make static
    static const int WIFI_CONNECTED_BIT = BIT0;
    static const int WIFI_FAIL_BIT = BIT1;
    
    uint8_t retryCount;
    uint32_t backoffDelay;
    bool isConnected;
    
    // Exponential backoff parameters
    static const uint8_t MAX_RETRY_COUNT = 10;
    static const uint32_t BASE_DELAY_MS = 1000;
    static const uint32_t MAX_DELAY_MS = 60000;
    
public:
    SecureWiFiManager();
    ~SecureWiFiManager();
    
    bool begin();
    bool connect();
    bool disconnect();
    bool isWiFiConnected();
    
    // Credential management
    bool storeCredentials(const char* ssid, const char* password);
    bool loadCredentials(char* ssid, char* password, size_t maxLen);
    bool clearCredentials();
    
    // Connection monitoring
    void startConnectionMonitor();
    void stopConnectionMonitor();
    
    // Status and diagnostics
    String getConnectionStatus();
    int getRSSI();
    String getLocalIP();
    String getMACAddress();
    
private:
    static void wifiEventHandler(WiFiEvent_t event);
    static void connectionMonitorTask(void* parameter);
    void calculateBackoffDelay();
    void resetBackoff();
};

#endif // NETWORK_WIFI_MANAGER_H
