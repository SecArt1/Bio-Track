#include "ota_manager.h"
#include <SPIFFS.h>
#include <Update.h>

OTAManager::OTAManager() {
    // Initialize latestUpdate struct
    latestUpdate.version = "";
    latestUpdate.downloadUrl = "";
    latestUpdate.releaseNotes = "";
    latestUpdate.isRequired = false;
    latestUpdate.fileSize = 0;
    latestUpdate.checksum = "";
}

bool OTAManager::begin() {
    Serial.println("🔄 Initializing OTA Manager...");
    
    // Configure ArduinoOTA
    ArduinoOTA.setHostname(OTA_HOSTNAME);
    ArduinoOTA.setPassword(OTA_PASSWORD);
    
    // Set OTA callbacks
    ArduinoOTA.onStart(onOTAStart);
    ArduinoOTA.onEnd(onOTAEnd);
    ArduinoOTA.onProgress(onOTAProgress);
    ArduinoOTA.onError(onOTAError);
    
    ArduinoOTA.begin();
    
    Serial.println("✅ OTA Manager initialized");
    Serial.printf("🔧 OTA Hostname: %s\n", OTA_HOSTNAME);
    
    return true;
}

bool OTAManager::checkForUpdatesNow() {
    Serial.println("🔄 Checking for firmware updates...");
    
    currentState = OTA_STATE_CHECKING;
    
    HTTPClient http;
    WiFiClientSecure client;
    client.setInsecure(); // For development
    
    String url = updateServerUrl + "/check-update";
    http.begin(client, url);
    http.addHeader("Content-Type", "application/json");
    
    // Send device info
    String deviceInfo = generateDeviceInfo();
    int httpCode = http.POST(deviceInfo);
    
    if (httpCode == 200) {
        String response = http.getString();        if (parseUpdateResponse(response)) {
            Serial.printf("✅ Update available: v%s\n", latestUpdate.version.c_str());
            currentState = OTA_STATE_IDLE;
            return true;
        } else {
            Serial.println("✅ No updates available");
            currentState = OTA_STATE_IDLE;
            return false;
        }    } else {
        Serial.printf("❌ Update check failed: HTTP %d\n", httpCode);
        lastError = "HTTP Error: " + String(httpCode);
        currentState = OTA_STATE_ERROR;
        return false;
    }
    
    http.end();
}

String OTAManager::generateDeviceInfo() {
    StaticJsonDocument<512> doc;
    
    doc["deviceId"] = DEVICE_ID;
    doc["currentVersion"] = currentVersion;
    doc["chipModel"] = ESP.getChipModel();
    doc["chipRevision"] = ESP.getChipRevision();
    doc["flashSize"] = ESP.getFlashChipSize();
    doc["freeHeap"] = ESP.getFreeHeap();
    doc["sketchSize"] = ESP.getSketchSize();
    doc["freeSketchSpace"] = ESP.getFreeSketchSpace();
    
    String output;
    serializeJson(doc, output);
    return output;
}

bool OTAManager::parseUpdateResponse(const String& response) {
    StaticJsonDocument<1024> doc;
    DeserializationError error = deserializeJson(doc, response);
    
    if (error) {
        lastError = "JSON Parse Error";
        return false;
    }
    
    if (!doc["updateAvailable"].as<bool>()) {
        return false;
    }
    
    latestUpdate.version = doc["version"].as<String>();
    latestUpdate.downloadUrl = doc["downloadUrl"].as<String>();
    latestUpdate.releaseNotes = doc["releaseNotes"].as<String>();
    latestUpdate.isRequired = doc["required"].as<bool>();
    latestUpdate.fileSize = doc["fileSize"];
    latestUpdate.checksum = doc["checksum"].as<String>();
    
    return true;
}

bool OTAManager::startUpdate() {
    if (latestUpdate.downloadUrl.isEmpty()) {
        lastError = "No update URL available";
        return false;
    }
    
    Serial.printf("🔄 Starting OTA update to v%s\n", latestUpdate.version.c_str());
    Serial.printf("📦 Download size: %d bytes\n", latestUpdate.fileSize);
    
    currentState = OTA_STATE_DOWNLOADING;
    downloadProgress = 0;
    
    // Use HTTP Update for remote updates
    WiFiClientSecure client;
    client.setInsecure();
    
    httpUpdate.setLedPin(LED_BUILTIN, LOW);
    httpUpdate.onStart([]() {
        Serial.println("🔄 HTTP Update started");
    });
    
    httpUpdate.onEnd([]() {
        Serial.println("✅ HTTP Update finished");
    });
    
    httpUpdate.onProgress([](int current, int total) {
        int progress = (current * 100) / total;
        Serial.printf("⬇️ Download progress: %d%%\n", progress);
    });
    
    httpUpdate.onError([](int error) {
        Serial.printf("❌ HTTP Update error: %d\n", error);
    });
    
    t_httpUpdate_return result = httpUpdate.update(client, latestUpdate.downloadUrl);
    
    switch (result) {        case HTTP_UPDATE_FAILED:
            currentState = OTA_STATE_ERROR;
            lastError = "Update failed: " + httpUpdate.getLastErrorString();
            Serial.printf("❌ Update failed: %s\n", lastError.c_str());
            return false;
              case HTTP_UPDATE_NO_UPDATES:
            currentState = OTA_STATE_IDLE;
            Serial.println("ℹ️ No update needed");
            return false;
            
        case HTTP_UPDATE_OK:
            currentState = OTA_STATE_SUCCESS;
            Serial.println("✅ Update successful! Restarting...");
            ESP.restart();
            return true;
    }
    
    return false;
}

void OTAManager::handleAutoUpdates() {
    unsigned long currentTime = millis();
    
    if (currentTime - lastUpdateCheck > updateCheckInterval) {
        checkForUpdatesNow();
        lastUpdateCheck = currentTime;
        
        if (isUpdateAvailable() && isUpdateRequired()) {
            Serial.println("🔄 Required update found, installing automatically...");
            startUpdate();
        }
    }
}

bool OTAManager::isUpdateAvailable() {
    return !latestUpdate.version.isEmpty() && 
           latestUpdate.version != currentVersion;
}

bool OTAManager::isUpdateRequired() {
    return latestUpdate.isRequired;
}

String OTAManager::getStatusString() {
    switch (currentState) {
        case OTA_STATE_IDLE: return "Idle";
        case OTA_STATE_CHECKING: return "Checking for updates";
        case OTA_STATE_DOWNLOADING: return "Downloading update";
        case OTA_STATE_INSTALLING: return "Installing update";
        case OTA_STATE_SUCCESS: return "Update successful";
        case OTA_STATE_ERROR: return "Error: " + lastError;
        default: return "Unknown";
    }
}

void OTAManager::printUpdateInfo() {
    if (!isUpdateAvailable()) {
        Serial.println("ℹ️ No updates available");
        return;
    }
    
    Serial.println("=== Update Information ===");
    Serial.printf("Current Version: %s\n", currentVersion.c_str());
    Serial.printf("Latest Version: %s\n", latestUpdate.version.c_str());
    Serial.printf("Required: %s\n", latestUpdate.isRequired ? "Yes" : "No");
    Serial.printf("File Size: %d bytes\n", latestUpdate.fileSize);
    Serial.printf("Release Notes: %s\n", latestUpdate.releaseNotes.c_str());
    Serial.println("===========================");
}

bool OTAManager::performSelfTest() {
    Serial.println("🔧 Performing OTA self-test...");
    
    // Check available space
    size_t freeSpace = ESP.getFreeSketchSpace();
    if (freeSpace < 100000) { // Need at least 100KB free
        Serial.printf("⚠️ Low free space: %d bytes\n", freeSpace);
        return false;
    }
    
    // Check WiFi connection
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("❌ WiFi not connected");
        return false;
    }
    
    // Test update server connectivity
    HTTPClient http;
    WiFiClientSecure client;
    client.setInsecure();
    
    http.begin(client, updateServerUrl + "/ping");
    int httpCode = http.GET();
    http.end();
    
    if (httpCode != 200) {
        Serial.printf("⚠️ Update server unreachable: HTTP %d\n", httpCode);
        return false;
    }
    
    Serial.println("✅ OTA self-test passed");
    return true;
}

// Static callback functions
void OTAManager::onOTAStart() {
    String type = (ArduinoOTA.getCommand() == U_FLASH) ? "sketch" : "filesystem";
    Serial.printf("🔄 OTA Start: Updating %s\n", type.c_str());
}

void OTAManager::onOTAEnd() {
    Serial.println("✅ OTA End: Update completed");
}

void OTAManager::onOTAProgress(unsigned int progress, unsigned int total) {
    int percentage = (progress / (total / 100));
    Serial.printf("⬇️ OTA Progress: %u%%\n", percentage);
}

void OTAManager::onOTAError(ota_error_t error) {
    String errorMsg;
    switch (error) {
        case OTA_AUTH_ERROR: errorMsg = "Auth Failed"; break;
        case OTA_BEGIN_ERROR: errorMsg = "Begin Failed"; break;
        case OTA_CONNECT_ERROR: errorMsg = "Connect Failed"; break;
        case OTA_RECEIVE_ERROR: errorMsg = "Receive Failed"; break;
        case OTA_END_ERROR: errorMsg = "End Failed"; break;
        default: errorMsg = "Unknown Error"; break;
    }
    Serial.printf("❌ OTA Error: %s\n", errorMsg.c_str());
}

void OTAManager::setUpdateCheckInterval(unsigned long interval) {
    updateCheckInterval = interval;
    Serial.printf("⚙️ Update check interval set to %lu ms\n", interval);
}

void OTAManager::factoryReset() {
    Serial.println("🔄 Performing factory reset...");
    
    // Clear SPIFFS
    if (SPIFFS.begin()) {
        SPIFFS.format();
        Serial.println("✅ File system formatted");
    }
    
    // Clear WiFi credentials
    WiFi.disconnect(true);
    WiFi.mode(WIFI_OFF);
    
    Serial.println("✅ Factory reset completed. Restarting...");
    delay(1000);
    ESP.restart();
}
