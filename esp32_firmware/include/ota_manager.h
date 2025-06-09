#ifndef OTA_MANAGER_H
#define OTA_MANAGER_H

#include <ArduinoOTA.h>
#include <HTTPUpdate.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include "config.h"

// OTA states
enum OTAState {
    OTA_STATE_IDLE,
    OTA_STATE_CHECKING,
    OTA_STATE_DOWNLOADING,
    OTA_STATE_INSTALLING,
    OTA_STATE_SUCCESS,
    OTA_STATE_ERROR
};

// Update info structure
struct UpdateInfo {
    String version;
    String downloadUrl;
    String releaseNotes;
    bool isRequired;
    size_t fileSize;
    String checksum;
};

class OTAManager {
private:
    OTAState currentState = OTA_STATE_IDLE;
    UpdateInfo latestUpdate;
    
    unsigned long lastUpdateCheck = 0;
    unsigned long updateCheckInterval = 24 * 60 * 60 * 1000; // 24 hours
    
    String updateServerUrl = "https://your-update-server.com/api";
    String currentVersion = FIRMWARE_VERSION;
    
    // Progress tracking
    int downloadProgress = 0;
    String lastError = "";
    
    // Helper methods
    bool checkForUpdates();
    bool downloadUpdate(const String& url);
    bool verifyUpdate(const String& checksum);
    void handleOTAProgress(unsigned int progress, unsigned int total);
    void handleOTAError(ota_error_t error);
    
    String generateDeviceInfo();
    bool parseUpdateResponse(const String& response);

public:
    OTAManager();
    
    // Initialization
    bool begin();
    void reset();
    
    // Update management
    bool checkForUpdatesNow();
    bool startUpdate();
    bool installUpdate();
    void setUpdateCheckInterval(unsigned long interval);
    
    // Automatic update handling
    void handleAutoUpdates();
    bool isUpdateAvailable();
    bool isUpdateRequired();
    
    // Progress and status
    OTAState getState();
    int getProgress();
    String getLastError();
    UpdateInfo getUpdateInfo();
    String getCurrentVersion();
    
    // Configuration
    void setUpdateServer(const String& url);
    void enableAutoUpdates(bool enable);
    void setRequiredUpdatesOnly(bool required);
    
    // Callbacks for OTA events
    static void onOTAStart();
    static void onOTAEnd();
    static void onOTAProgress(unsigned int progress, unsigned int total);
    static void onOTAError(ota_error_t error);
    
    // Utility methods
    void printUpdateInfo();
    String getStatusString();
    bool performSelfTest();
    
    // Recovery methods
    bool rollbackUpdate();
    void factoryReset();
    bool repairFileSystem();
};

#endif // OTA_MANAGER_H
