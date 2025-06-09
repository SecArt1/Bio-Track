#ifndef DATA_MANAGER_H
#define DATA_MANAGER_H

#include <Arduino.h>
#include <ArduinoJson.h>
#include <SPIFFS.h>
#include <NTPClient.h>
#include "sensors.h"
#include "config.h"

// Data storage structures
struct DataPoint {
    String sensorType;
    float value;
    String unit;
    unsigned long timestamp;
    bool isSynced;
};

struct HealthAlert {
    String alertType;
    String message;
    String severity; // "low", "medium", "high", "critical"
    unsigned long timestamp;
    bool isAcknowledged;
};

class DataManager {
private:
    // Data buffers
    SensorReadings dataBuffer[MAX_BUFFER_SIZE];
    HealthAlert alertBuffer[MAX_BUFFER_SIZE];
    
    int currentBufferIndex = 0;
    int alertBufferIndex = 0;
    
    // File system paths
    const char* DATA_FILE = "/sensor_data.json";
    const char* ALERTS_FILE = "/alerts.json";
    const char* CONFIG_FILE = "/device_config.json";
    
    // Statistics
    unsigned long totalReadings = 0;
    unsigned long successfulUploads = 0;
    unsigned long failedUploads = 0;
    
    // Helper methods
    bool initializeFileSystem();
    bool saveDataToFile(const SensorReadings& data);
    bool loadDataFromFile();    bool saveAlertsToFile();
    bool loadAlertsFromFile();
    
    void analyzeDataForAlerts(const SensorReadings& data);
    void addAlert(const String& type, const String& message, const String& severity);
    
    void updateStatistics(bool uploadSuccess);

public:
    DataManager();
    
    // Initialization
    bool begin();
    void reset();
    
    // Data handling methods
    String formatSensorDataJSON(const SensorReadings& data);
    String formatAlertJSON(const HealthAlert& alert);
    String formatHeartbeatJSON();
    bool isValidReading(const SensorReadings& data);
    bool addSensorData(const SensorReadings& data);
    bool addAlert(const HealthAlert& alert);
    
    // Data retrieval
    SensorReadings getLatestReading();
    String getPendingDataJSON();
    String getPendingAlertsJSON();
    
    // Data synchronization
    bool syncPendingData();
    bool markDataAsSynced(int index);
    bool hasPendingData();
    int getPendingDataCount();
    
    // Alert management
    bool hasUnacknowledgedAlerts();
    int getUnacknowledgedAlertsCount();
    bool acknowledgeAlert(int index);
    String getLatestAlertJSON();
    
    // File system operations
    bool saveConfiguration(const String& config);
    String loadConfiguration();
    bool clearStoredData();
    bool clearStoredAlerts();
    
    // Statistics and monitoring
    unsigned long getTotalReadings();
    float getUploadSuccessRate();
    String getSystemStats();
    bool performHealthCheck();
    
    // Data validation and processing
    bool validateDataIntegrity();
    void processDataForTrends();
    String generateDataSummary();
    
    // Utility methods
    void printBufferStatus();
    void printDataStatistics();
    size_t getAvailableStorage();
    bool isStorageHealthy();
};

#endif // DATA_MANAGER_H
