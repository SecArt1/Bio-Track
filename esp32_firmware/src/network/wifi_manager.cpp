#include "network/wifi_manager.h"
#include "esp_log.h"
#include "esp_wifi.h"

static const char* TAG = "WiFiManager";

// Define static member
EventGroupHandle_t SecureWiFiManager::wifiEventGroup = nullptr;

SecureWiFiManager::SecureWiFiManager() 
    : retryCount(0), backoffDelay(BASE_DELAY_MS), isConnected(false) {
    if (wifiEventGroup == nullptr) {
        wifiEventGroup = xEventGroupCreate();
    }
}

SecureWiFiManager::~SecureWiFiManager() {
    if (wifiEventGroup) {
        vEventGroupDelete(wifiEventGroup);
    }
}

bool SecureWiFiManager::begin() {
    ESP_LOGI(TAG, "Initializing secure WiFi manager");
    
    if (!nvs.begin("wifi_creds", false)) {
        ESP_LOGE(TAG, "Failed to initialize NVS");
        return false;
    }
    
    // Set WiFi event handler
    WiFi.onEvent(wifiEventHandler);
    
    return true;
}

bool SecureWiFiManager::connect() {
    char ssid[64] = {0};
    char password[64] = {0};
    
    if (!loadCredentials(ssid, password, sizeof(ssid))) {
        ESP_LOGE(TAG, "No stored WiFi credentials found");
        return false;
    }
    
    ESP_LOGI(TAG, "Connecting to WiFi: %s", ssid);
    
    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid, password);
    
    // Wait for connection with timeout and exponential backoff
    while (retryCount < MAX_RETRY_COUNT) {
        EventBits_t bits = xEventGroupWaitBits(
            wifiEventGroup,
            WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
            pdFALSE,
            pdFALSE,
            pdMS_TO_TICKS(backoffDelay)
        );
        
        if (bits & WIFI_CONNECTED_BIT) {
            ESP_LOGI(TAG, "Connected to WiFi successfully");
            isConnected = true;
            resetBackoff();
            return true;
        } else if (bits & WIFI_FAIL_BIT) {
            retryCount++;
            calculateBackoffDelay();
            ESP_LOGW(TAG, "WiFi connection failed, retry %d/%d in %lums", 
                     retryCount, MAX_RETRY_COUNT, backoffDelay);
            
            if (retryCount < MAX_RETRY_COUNT) {
                vTaskDelay(pdMS_TO_TICKS(backoffDelay));
                WiFi.reconnect();
            }
        } else {
            // Timeout occurred
            ESP_LOGW(TAG, "WiFi connection timeout");
            retryCount++;
            calculateBackoffDelay();
        }
    }
    
    ESP_LOGE(TAG, "Failed to connect to WiFi after %d attempts", MAX_RETRY_COUNT);
    return false;
}

bool SecureWiFiManager::disconnect() {
    WiFi.disconnect(true);
    isConnected = false;
    return true;
}

bool SecureWiFiManager::isWiFiConnected() {
    return WiFi.status() == WL_CONNECTED && isConnected;
}

bool SecureWiFiManager::storeCredentials(const char* ssid, const char* password) {
    if (!nvs.putString("ssid", ssid)) {
        ESP_LOGE(TAG, "Failed to store SSID");
        return false;
    }
    
    if (!nvs.putString("password", password)) {
        ESP_LOGE(TAG, "Failed to store password");
        return false;
    }
    
    ESP_LOGI(TAG, "WiFi credentials stored securely");
    return true;
}

bool SecureWiFiManager::loadCredentials(char* ssid, char* password, size_t maxLen) {
    String storedSSID = nvs.getString("ssid", "");
    String storedPassword = nvs.getString("password", "");
    
    if (storedSSID.length() == 0 || storedPassword.length() == 0) {
        return false;
    }
    
    strncpy(ssid, storedSSID.c_str(), maxLen - 1);
    strncpy(password, storedPassword.c_str(), maxLen - 1);
    ssid[maxLen - 1] = '\0';
    password[maxLen - 1] = '\0';
    
    return true;
}

bool SecureWiFiManager::clearCredentials() {
    nvs.remove("ssid");
    nvs.remove("password");
    ESP_LOGI(TAG, "WiFi credentials cleared");
    return true;
}

void SecureWiFiManager::startConnectionMonitor() {
    xTaskCreate(
        connectionMonitorTask,
        "wifi_monitor",
        4096,
        this,
        1,
        NULL
    );
}

String SecureWiFiManager::getConnectionStatus() {
    String status = "WiFi Status: ";
    
    switch (WiFi.status()) {
        case WL_CONNECTED:
            status += "Connected to " + WiFi.SSID();
            status += " (IP: " + WiFi.localIP().toString() + ")";
            status += " RSSI: " + String(WiFi.RSSI()) + "dBm";
            break;
        case WL_DISCONNECTED:
            status += "Disconnected";
            break;
        case WL_NO_SSID_AVAIL:
            status += "SSID not available";
            break;
        case WL_CONNECT_FAILED:
            status += "Connection failed";
            break;
        case WL_IDLE_STATUS:
            status += "Connecting...";
            break;
        default:
            status += "Unknown (" + String(WiFi.status()) + ")";
            break;
    }
    
    return status;
}

int SecureWiFiManager::getRSSI() {
    return WiFi.RSSI();
}

String SecureWiFiManager::getLocalIP() {
    return WiFi.localIP().toString();
}

String SecureWiFiManager::getMACAddress() {
    return WiFi.macAddress();
}

void SecureWiFiManager::wifiEventHandler(WiFiEvent_t event) {
    switch (event) {
        case ARDUINO_EVENT_WIFI_STA_GOT_IP:
            ESP_LOGI(TAG, "WiFi connected with IP: %s", WiFi.localIP().toString().c_str());
            if (wifiEventGroup != nullptr) {
                xEventGroupSetBits(wifiEventGroup, WIFI_CONNECTED_BIT);
            }
            break;
        case ARDUINO_EVENT_WIFI_STA_DISCONNECTED:
            ESP_LOGW(TAG, "WiFi disconnected");
            if (wifiEventGroup != nullptr) {
                xEventGroupSetBits(wifiEventGroup, WIFI_FAIL_BIT);
            }
            break;
        default:
            break;
    }
}

void SecureWiFiManager::connectionMonitorTask(void* parameter) {
    SecureWiFiManager* manager = static_cast<SecureWiFiManager*>(parameter);
    
    while (true) {
        if (!manager->isWiFiConnected()) {
            ESP_LOGW(TAG, "WiFi connection lost, attempting reconnection");
            manager->connect();
        }
        
        vTaskDelay(pdMS_TO_TICKS(30000)); // Check every 30 seconds
    }
}

void SecureWiFiManager::calculateBackoffDelay() {
    backoffDelay = min(backoffDelay * 2, MAX_DELAY_MS);
}

void SecureWiFiManager::resetBackoff() {
    retryCount = 0;
    backoffDelay = BASE_DELAY_MS;
}
