#include "data_manager.h"

DataManager::DataManager() {
    // Initialize data buffers
    for (int i = 0; i < MAX_BUFFER_SIZE; i++) {
        // Initialize dataBuffer entries
        dataBuffer[i].systemTimestamp = 0;
        dataBuffer[i].heartRate = {0, 0, false, 0};
        dataBuffer[i].temperature = {0, false, 0};
        dataBuffer[i].weight = {0, false, false, 0};        dataBuffer[i].bioimpedance = {0, 0, 0, 0, 0, false, 0};
        dataBuffer[i].ecg = {0, 0, 0, false, false, 0};
        dataBuffer[i].glucose = {0, 0, 0, 0, 0, false, false, 0};
        dataBuffer[i].bloodPressure = {0, 0, 0, 0, 0, 0, false, true, 0, 0, 0, false};
        dataBuffer[i].bodyComposition = {}; // Initialize body composition
        dataBuffer[i].bodyComposition.timestamp = 0;
        dataBuffer[i].bodyComposition.validReading = false;
        
        // Initialize alertBuffer entries
        alertBuffer[i].alertType = "";
        alertBuffer[i].message = "";
        alertBuffer[i].severity = "";
        alertBuffer[i].timestamp = 0;
        alertBuffer[i].isAcknowledged = false;
    }
}

bool DataManager::begin() {
    Serial.println("🔄 Initializing Data Manager...");
    
    if (!initializeFileSystem()) {
        Serial.println("❌ File system initialization failed");
        return false;
    }
    
    // Load existing data
    loadDataFromFile();
    loadAlertsFromFile();
    
    Serial.println("✅ Data Manager initialized");
    return true;
}

bool DataManager::initializeFileSystem() {
    if (!SPIFFS.begin(true)) {
        Serial.println("❌ SPIFFS Mount Failed");
        return false;
    }
    
    Serial.printf("📁 SPIFFS initialized. Total: %d bytes, Used: %d bytes\n",
                 SPIFFS.totalBytes(), SPIFFS.usedBytes());
    
    return true;
}

bool DataManager::addSensorData(const SensorReadings& data) {
    if (!isValidReading(data)) {
        Serial.println("⚠️ Invalid sensor reading, not storing");
        return false;
    }
    
    // Add to buffer
    dataBuffer[currentBufferIndex] = data;
    currentBufferIndex = (currentBufferIndex + 1) % MAX_BUFFER_SIZE;
    totalReadings++;
    
    // Analyze for alerts
    analyzeDataForAlerts(data);
    
    // Save to file system for persistence
    saveDataToFile(data);
    
    return true;
}

String DataManager::formatSensorDataJSON(const SensorReadings& data) {
    StaticJsonDocument<JSON_BUFFER_SIZE> doc;
    
    doc["deviceId"] = DEVICE_ID;
    doc["timestamp"] = data.systemTimestamp;
    doc["version"] = FIRMWARE_VERSION;
    
    // Heart Rate data
    if (data.heartRate.validReading) {
        JsonObject hr = doc.createNestedObject("heartRate");
        hr["value"] = data.heartRate.heartRate;
        hr["unit"] = "bpm";
        hr["spo2"] = data.heartRate.spO2;
        hr["timestamp"] = data.heartRate.timestamp;
        hr["valid"] = true;
    }
    
    // Temperature data
    if (data.temperature.validReading) {
        JsonObject temp = doc.createNestedObject("temperature");
        temp["value"] = data.temperature.temperature;
        temp["unit"] = "celsius";
        temp["timestamp"] = data.temperature.timestamp;
        temp["valid"] = true;
    }
    
    // Weight data
    if (data.weight.validReading) {
        JsonObject weight = doc.createNestedObject("weight");
        weight["value"] = data.weight.weight;
        weight["unit"] = "kg";
        weight["stable"] = data.weight.stable;
        weight["timestamp"] = data.weight.timestamp;
        weight["valid"] = true;
    }
      // Bioimpedance data
    if (data.bioimpedance.validReading) {
        JsonObject bio = doc.createNestedObject("bioimpedance");
        bio["impedance"] = data.bioimpedance.impedance;
        bio["resistance"] = data.bioimpedance.resistance;
        bio["reactance"] = data.bioimpedance.reactance;
        bio["phase"] = data.bioimpedance.phase;
        bio["frequency"] = data.bioimpedance.frequency;
        bio["unit"] = "ohms";
        bio["timestamp"] = data.bioimpedance.timestamp;
        bio["valid"] = true;
    }
    
    // ECG data
    if (data.ecg.validReading) {
        JsonObject ecg = doc.createNestedObject("ecg");
        ecg["avgFilteredValue"] = data.ecg.avgFilteredValue;
        ecg["avgBPM"] = data.ecg.avgBPM;
        ecg["peakCount"] = data.ecg.peakCount;
        ecg["leadOff"] = data.ecg.leadOff;
        ecg["timestamp"] = data.ecg.timestamp;
        ecg["valid"] = true;
    }
    
    // Glucose data
    if (data.glucose.validReading) {
        JsonObject glucose = doc.createNestedObject("glucose");
        glucose["glucoseLevel"] = data.glucose.glucoseLevel;
        glucose["irValue"] = data.glucose.irValue;
        glucose["redValue"] = data.glucose.redValue;
        glucose["ratio"] = data.glucose.ratio;
        glucose["signalQuality"] = data.glucose.signalQuality;
        glucose["stable"] = data.glucose.stable;
        glucose["unit"] = "mg/dL";
        glucose["timestamp"] = data.glucose.timestamp;
        glucose["valid"] = true;
    }
      // Blood Pressure data
    if (data.bloodPressure.validReading) {
        JsonObject bp = doc.createNestedObject("bloodPressure");
        bp["systolic"] = data.bloodPressure.systolic;
        bp["diastolic"] = data.bloodPressure.diastolic;
        bp["PTT"] = data.bloodPressure.pulseTransitTime;
        bp["PWV"] = data.bloodPressure.pulseWaveVelocity;
        bp["HRV"] = data.bloodPressure.heartRateVariability;
        bp["signalQuality"] = data.bloodPressure.signalQuality;
        bp["correlationCoeff"] = data.bloodPressure.correlationCoeff;
        bp["unit"] = "mmHg";
        bp["timestamp"] = data.bloodPressure.timestamp;
        bp["valid"] = true;
    }
    
    // Body Composition data
    if (data.bodyComposition.validReading) {
        JsonObject bc = doc.createNestedObject("bodyComposition");
        bc["bodyFatPercentage"] = data.bodyComposition.bodyFatPercentage;
        bc["muscleMassKg"] = data.bodyComposition.muscleMassKg;
        bc["fatMassKg"] = data.bodyComposition.fatMassKg;
        bc["fatFreeMass"] = data.bodyComposition.fatFreeMass;
        bc["bodyWaterPercentage"] = data.bodyComposition.bodyWaterPercentage;
        bc["visceralFatLevel"] = data.bodyComposition.visceralFatLevel;
        bc["boneMassKg"] = data.bodyComposition.boneMassKg;
        bc["metabolicAge"] = data.bodyComposition.metabolicAge;
        bc["BMR"] = data.bodyComposition.BMR;
        bc["muscleMassPercentage"] = data.bodyComposition.muscleMassPercentage;
        bc["measurementQuality"] = data.bodyComposition.measurementQuality;
        bc["phaseAngle"] = data.bodyComposition.phaseAngle;
        bc["resistance50kHz"] = data.bodyComposition.resistance50kHz;
        bc["reactance50kHz"] = data.bodyComposition.reactance50kHz;
        bc["impedance50kHz"] = data.bodyComposition.impedance50kHz;
        bc["timestamp"] = data.bodyComposition.timestamp;
        bc["valid"] = true;
    }
    
    String output;
    serializeJson(doc, output);
    return output;
}

void DataManager::analyzeDataForAlerts(const SensorReadings& data) {
    // Check heart rate alerts
    if (data.heartRate.validReading) {
        if (data.heartRate.heartRate > MAX_HEART_RATE) {
            addAlert("HIGH_HEART_RATE", 
                    "Heart rate too high: " + String(data.heartRate.heartRate) + " BPM", 
                    "high");
        } else if (data.heartRate.heartRate < MIN_HEART_RATE) {
            addAlert("LOW_HEART_RATE", 
                    "Heart rate too low: " + String(data.heartRate.heartRate) + " BPM", 
                    "high");
        }
        
        // SpO2 alerts
        if (data.heartRate.spO2 < 95) {
            String severity = data.heartRate.spO2 < 90 ? "critical" : "high";
            addAlert("LOW_SPO2", 
                    "Blood oxygen level low: " + String(data.heartRate.spO2) + "%", 
                    severity);
        }
    }
    
    // Check temperature alerts
    if (data.temperature.validReading) {
        if (data.temperature.temperature > MAX_TEMPERATURE) {
            addAlert("HIGH_TEMPERATURE", 
                    "Temperature too high: " + String(data.temperature.temperature) + "°C", 
                    "medium");
        } else if (data.temperature.temperature < MIN_TEMPERATURE) {
            addAlert("LOW_TEMPERATURE", 
                    "Temperature too low: " + String(data.temperature.temperature) + "°C", 
                    "medium");
        }
    }
    
    // Check weight stability
    if (data.weight.validReading && !data.weight.stable) {
        addAlert("UNSTABLE_WEIGHT", 
                "Weight reading unstable: " + String(data.weight.weight) + " kg", 
                "low");
    }
}

void DataManager::addAlert(const String& type, const String& message, const String& severity) {
    HealthAlert alert;
    alert.alertType = type;
    alert.message = message;
    alert.severity = severity;
    alert.timestamp = millis();
    alert.isAcknowledged = false;
    
    alertBuffer[alertBufferIndex] = alert;
    alertBufferIndex = (alertBufferIndex + 1) % MAX_BUFFER_SIZE;
    
    Serial.printf("🚨 Alert: [%s] %s\n", severity.c_str(), message.c_str());
    
    saveAlertsToFile();
}

bool DataManager::saveDataToFile(const SensorReadings& data) {
    File file = SPIFFS.open(DATA_FILE, FILE_APPEND);
    if (!file) {
        Serial.println("❌ Failed to open data file for writing");
        return false;
    }
    
    String jsonData = formatSensorDataJSON(data);
    file.println(jsonData);
    file.close();
    
    return true;
}

bool DataManager::loadDataFromFile() {
    if (!SPIFFS.exists(DATA_FILE)) {
        Serial.println("📁 No existing data file found");
        return true; // Not an error
    }
    
    File file = SPIFFS.open(DATA_FILE, FILE_READ);
    if (!file) {
        Serial.println("❌ Failed to open data file for reading");
        return false;
    }
    
    int lineCount = 0;
    while (file.available() && lineCount < MAX_BUFFER_SIZE) {
        String line = file.readStringUntil('\n');
        // Could parse and load recent data into buffer here
        lineCount++;
    }
    
    file.close();
    Serial.printf("📁 Loaded %d data entries from file\n", lineCount);
    return true;
}

String DataManager::getPendingDataJSON() {
    StaticJsonDocument<JSON_BUFFER_SIZE * 2> doc;
    JsonArray dataArray = doc.createNestedArray("readings");
    
    int count = 0;
    for (int i = 0; i < MAX_BUFFER_SIZE && count < 5; i++) {
        int index = (currentBufferIndex - 1 - i + MAX_BUFFER_SIZE) % MAX_BUFFER_SIZE;
        if (dataBuffer[index].systemTimestamp > 0) {
            JsonObject reading = dataArray.createNestedObject();
            String singleReading = formatSensorDataJSON(dataBuffer[index]);
            
            StaticJsonDocument<JSON_BUFFER_SIZE> singleDoc;
            deserializeJson(singleDoc, singleReading);
            reading.set(singleDoc.as<JsonObject>());
            count++;
        }
    }
    
    doc["deviceId"] = DEVICE_ID;
    doc["batchTimestamp"] = millis();
    doc["count"] = count;
    
    String output;
    serializeJson(doc, output);
    return output;
}

bool DataManager::isValidReading(const SensorReadings& data) {
    // At least one sensor must have a valid reading
    return data.heartRate.validReading || 
           data.temperature.validReading || 
           data.weight.validReading || 
           data.bioimpedance.validReading ||
           data.ecg.validReading ||
           data.glucose.validReading ||
           data.bloodPressure.validReading;
}

bool DataManager::hasUnacknowledgedAlerts() {
    for (int i = 0; i < MAX_BUFFER_SIZE; i++) {
        if (alertBuffer[i].timestamp > 0 && !alertBuffer[i].isAcknowledged) {
            return true;
        }
    }
    return false;
}

String DataManager::getSystemStats() {
    StaticJsonDocument<512> doc;
    
    doc["deviceId"] = DEVICE_ID;
    doc["totalReadings"] = totalReadings;
    doc["successfulUploads"] = successfulUploads;
    doc["failedUploads"] = failedUploads;
    doc["successRate"] = getUploadSuccessRate();
    doc["freeHeap"] = ESP.getFreeHeap();
    doc["uptime"] = millis() / 1000;
    doc["storageUsed"] = SPIFFS.usedBytes();
    doc["storageTotal"] = SPIFFS.totalBytes();
    doc["version"] = FIRMWARE_VERSION;
    
    String output;
    serializeJson(doc, output);
    return output;
}

float DataManager::getUploadSuccessRate() {
    unsigned long totalAttempts = successfulUploads + failedUploads;
    if (totalAttempts == 0) return 100.0;
    return (float)successfulUploads / totalAttempts * 100.0;
}

void DataManager::updateStatistics(bool uploadSuccess) {
    if (uploadSuccess) {
        successfulUploads++;
    } else {
        failedUploads++;
    }
}

bool DataManager::saveAlertsToFile() {
    File file = SPIFFS.open(ALERTS_FILE, FILE_WRITE);
    if (!file) {
        return false;
    }
    
    StaticJsonDocument<JSON_BUFFER_SIZE> doc;
    JsonArray alertsArray = doc.createNestedArray("alerts");
    
    for (int i = 0; i < MAX_BUFFER_SIZE; i++) {
        if (alertBuffer[i].timestamp > 0) {
            JsonObject alert = alertsArray.createNestedObject();
            alert["type"] = alertBuffer[i].alertType;
            alert["message"] = alertBuffer[i].message;
            alert["severity"] = alertBuffer[i].severity;
            alert["timestamp"] = alertBuffer[i].timestamp;
            alert["acknowledged"] = alertBuffer[i].isAcknowledged;
        }
    }
    
    String output;
    serializeJson(doc, output);
    file.print(output);
    file.close();
    
    return true;
}

bool DataManager::loadAlertsFromFile() {
    if (!SPIFFS.exists(ALERTS_FILE)) {
        return true; // Not an error
    }
    
    File file = SPIFFS.open(ALERTS_FILE, FILE_READ);
    if (!file) {
        return false;
    }
    
    String content = file.readString();
    file.close();
    
    StaticJsonDocument<JSON_BUFFER_SIZE> doc;
    DeserializationError error = deserializeJson(doc, content);
    
    if (error) {
        Serial.println("❌ Failed to parse alerts file");
        return false;
    }
    
    JsonArray alertsArray = doc["alerts"];
    int alertIndex = 0;
    
    for (JsonObject alert : alertsArray) {
        if (alertIndex >= MAX_BUFFER_SIZE) break;
        
        alertBuffer[alertIndex].alertType = alert["type"].as<String>();
        alertBuffer[alertIndex].message = alert["message"].as<String>();
        alertBuffer[alertIndex].severity = alert["severity"].as<String>();
        alertBuffer[alertIndex].timestamp = alert["timestamp"];
        alertBuffer[alertIndex].isAcknowledged = alert["acknowledged"];
        
        alertIndex++;
    }
    
    alertBufferIndex = alertIndex % MAX_BUFFER_SIZE;
    return true;
}

void DataManager::printBufferStatus() {
    Serial.println("=== Data Buffer Status ===");
    Serial.printf("Total readings: %lu\n", totalReadings);
    Serial.printf("Current buffer index: %d\n", currentBufferIndex);
    Serial.printf("Upload success rate: %.1f%%\n", getUploadSuccessRate());
    Serial.printf("Unacknowledged alerts: %d\n", getUnacknowledgedAlertsCount());
    Serial.println("==========================");
}

int DataManager::getUnacknowledgedAlertsCount() {
    int count = 0;
    for (int i = 0; i < MAX_BUFFER_SIZE; i++) {
        if (alertBuffer[i].timestamp > 0 && !alertBuffer[i].isAcknowledged) {
            count++;
        }
    }
    return count;
}

size_t DataManager::getAvailableStorage() {
    return SPIFFS.totalBytes() - SPIFFS.usedBytes();
}

SensorReadings DataManager::getLatestReading() {
    if (currentBufferIndex > 0) {
        return dataBuffer[currentBufferIndex - 1];
    }
      // Return empty reading if no data available
    SensorReadings emptyReading;    emptyReading.systemTimestamp = 0;
    emptyReading.heartRate = {0, 0, false, 0};
    emptyReading.temperature = {0, false, 0};
    emptyReading.weight = {0, false, false, 0};
    emptyReading.bioimpedance = {0, 0, 0, 0, 0, false, 0};
    emptyReading.ecg = {0, 0, 0, false, false, 0};
    emptyReading.glucose = {0, 0, 0, 0, 0, false, false, 0};
    emptyReading.bloodPressure = {0, 0, 0, 0, 0, 0, false, true, 0, 0, 0, false};
    emptyReading.bodyComposition = {}; // Initialize empty body composition
    emptyReading.bodyComposition.timestamp = 0;
    emptyReading.bodyComposition.validReading = false;
    
    return emptyReading;
}
