#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <ArduinoOTA.h>
#include <NTPClient.h>
#include <WiFiUdp.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <SPI.h>
#include <Wire.h>

// Local includes
#include "config.h"
#include "sensors.h"
#include "secure_network.h"
#include "data_manager.h"
#include "ota_manager.h"
#include "blood_pressure.h"

// Global variables
SecureNetworkManager secureNetwork;
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org", 0, 60000);

// Test mode selection
enum TestMode {
    NORMAL_MODE,
    BLOOD_PRESSURE_TEST_MODE,
    SENSOR_DEBUG_MODE
};

TestMode currentMode = NORMAL_MODE;

// Sensor objects
SensorManager sensors;
DataManager dataManager;
OTAManager otaManager;
BloodPressureMonitor bpMonitor;

// FreeRTOS Task Handles
TaskHandle_t sensorTaskHandle = NULL;
TaskHandle_t networkTaskHandle = NULL;
TaskHandle_t dataTaskHandle = NULL;
TaskHandle_t securityTaskHandle = NULL;

// Function declarations
bool initializeSystem();
void createTasks();
void sendHeartbeat();
void handleIncomingCommand(String topic, String message);
void sendDeviceStatus();
void sensorTask(void* pvParameters);
void networkTask(void* pvParameters);
void dataTask(void* pvParameters);
void securityTask(void* pvParameters);
void checkSensorAlerts();
void processAndSendData();
void sendAlert(String type, float value);
void handleSerialCommands();
void runBloodPressureTestLoop();
void displayBPTestInstructions();
void handleBPTestCommands(bool& testRunning);
void calculateAndDisplayBPResults(SensorReadings& readings);
void provideBPHealthAssessment(BloodPressureData& bp);
void enterBPCalibrationMode();
void setBPUserProfile();
void showBPSystemStatus();
void showBPDetailedDiagnostics();
void showBPTestStatus();
void monitorSystemHealth();
void handleWatchdogTimeout();
void validatePinConfiguration();  // Add pin validation function

// Global state
bool systemInitialized = false;
unsigned long lastHeartbeatTime = 0;
unsigned long lastSensorReadTime = 0;

void setup() {
    Serial.begin(SERIAL_BAUD_RATE);
    delay(1000);
    
    Serial.println("🚀 BioTrack ESP32 Firmware Starting...");
    Serial.printf("Firmware Version: %s\n", FIRMWARE_VERSION);
    Serial.printf("Device ID: %s\n", DEVICE_ID);
    
    // Validate pin configuration
    validatePinConfiguration();
    
    // Display DS18B20 configuration
    Serial.printf("🌡️ DS18B20 Temperature Sensor: GPIO %d\n", DS18B20_PIN);
    
    // Initialize LED
    pinMode(LED_BUILTIN, OUTPUT);
    digitalWrite(LED_BUILTIN, LOW);
    
    Serial.println();
    Serial.println("=================================");
    Serial.println("    BioTrack ESP32 Firmware     ");
    Serial.println("         Version " FIRMWARE_VERSION);
    Serial.println("=================================");
    Serial.println();
    Serial.println("📋 SELECT OPERATION MODE:");
    Serial.println("1. Normal Mode (Full sensor system + cloud)");
    Serial.println("2. Blood Pressure Test Mode (BP monitoring only)");
    Serial.println("3. Sensor Debug Mode (All sensors, no cloud)");
    Serial.println();
    Serial.print("Enter mode (1-3): ");
    
    // Wait for user input with timeout
    unsigned long startTime = millis();
    while (!Serial.available() && (millis() - startTime < 10000)) {
        delay(100);
    }
    
    if (Serial.available()) {
        int mode = Serial.parseInt();
        switch (mode) {
            case 1:
                currentMode = NORMAL_MODE;
                Serial.println("1 - Normal Mode Selected");
                break;
            case 2:
                currentMode = BLOOD_PRESSURE_TEST_MODE;
                Serial.println("2 - Blood Pressure Test Mode Selected");
                break;
            case 3:
                currentMode = SENSOR_DEBUG_MODE;
                Serial.println("3 - Sensor Debug Mode Selected");
                break;
            default:
                currentMode = NORMAL_MODE;
                Serial.println("Invalid selection - defaulting to Normal Mode");
                break;
        }
    } else {
        currentMode = NORMAL_MODE;
        Serial.println("Timeout - defaulting to Normal Mode");
    }
    
    Serial.println();
    
    // Initialize components based on mode
    if (!initializeSystem()) {
        Serial.println("❌ System initialization failed!");
        ESP.restart();
    }
    
    // Create appropriate tasks based on mode
    createTasks();
    
    Serial.println("✅ System initialization complete!");
    systemInitialized = true;
}

void loop() {
    if (currentMode == BLOOD_PRESSURE_TEST_MODE) {
        // Run specialized blood pressure test
        runBloodPressureTestLoop();
        return;
    }
    
    // Normal mode operations
    // Main loop handles OTA and keeps watchdog happy
    ArduinoOTA.handle();
    
    // Handle serial commands
    handleSerialCommands();
    
    // Send heartbeat every 30 seconds
    if (millis() - lastHeartbeatTime > 30000) {
        sendHeartbeat();
        lastHeartbeatTime = millis();
    }
    
    // Small delay to prevent watchdog issues
    delay(100);
}

void runBloodPressureTestLoop() {
    static bool testInitialized = false;
    static bool testRunning = false;
    static unsigned long lastBPMeasurement = 0;
    static unsigned long lastDiagnostics = 0;
    
    if (!testInitialized) {
        displayBPTestInstructions();
        testInitialized = true;
    }
    
    // Handle BP test commands
    handleBPTestCommands(testRunning);
    
    if (testRunning) {
        // Continuous data collection and BP calculation
        SensorReadings readings = sensors.readAllSensors();
        
        // Show real-time status every 5 seconds
        static unsigned long lastStatusUpdate = 0;
        if (millis() - lastStatusUpdate > 5000) {
            Serial.printf("📡 ECG: %s | PPG: %s | BP: %s\n",
                         sensors.isECGReady() ? "✅" : "❌",
                         sensors.isHeartRateReady() ? "✅" : "❌",
                         sensors.isBloodPressureReady() ? "✅" : "❌");
            lastStatusUpdate = millis();
        }
        
        // Calculate BP every 30 seconds
        if (millis() - lastBPMeasurement > 30000) {
            calculateAndDisplayBPResults(readings);
            lastBPMeasurement = millis();
        }
    }
    
    // Show diagnostics periodically
    if (millis() - lastDiagnostics > 10000) {
        if (testRunning) {
            showBPTestStatus();
        }
        lastDiagnostics = millis();
    }
    
    delay(100);
}

void displayBPTestInstructions() {
    Serial.println("\n============================================================");
    Serial.println("🩺 BLOOD PRESSURE MONITORING TEST MODE 🩺");
    Serial.println("   Advanced PTT-based BP estimation system");
    Serial.println("============================================================");
    Serial.println();
    Serial.println("📋 SETUP INSTRUCTIONS:");
    Serial.println("1. Connect ECG electrodes:");
    Serial.println("   • RA (Right Arm) - positive electrode");
    Serial.println("   • LA (Left Arm) - negative electrode");
    Serial.println("   • RL (Right Leg) - ground reference");
    Serial.println("2. Place finger firmly on PPG sensor (heart rate sensor)");
    Serial.println("3. Sit comfortably and breathe normally");
    Serial.println("4. Avoid movement during measurements");
    Serial.println();
    Serial.println("📟 AVAILABLE COMMANDS:");
    Serial.println("  'start'    - Begin BP monitoring");
    Serial.println("  'stop'     - Stop monitoring");
    Serial.println("  'cal'      - Calibrate with reference BP");
    Serial.println("  'profile'  - Set user profile (age/height/gender)");
    Serial.println("  'status'   - Show system status");
    Serial.println("  'diag'     - Show detailed diagnostics");
    Serial.println("  'help'     - Show this help");
    Serial.println();
    Serial.println("💡 TIP: For best accuracy, calibrate with a reference BP measurement!");
    Serial.println("🔬 This system uses Pulse Transit Time analysis for non-invasive BP estimation");
    Serial.println();
}

void handleBPTestCommands(bool& testRunning) {
    if (Serial.available()) {
        String command = Serial.readString();
        command.trim();
        command.toLowerCase();
        
        if (command == "start") {
            if (!sensors.isECGReady() || !sensors.isHeartRateReady()) {
                Serial.println("❌ Required sensors not ready!");
                Serial.printf("   ECG: %s | PPG: %s\n",
                             sensors.isECGReady() ? "✅" : "❌",
                             sensors.isHeartRateReady() ? "✅" : "❌");
                return;
            }
            testRunning = true;
            Serial.println("🩺 Starting blood pressure monitoring...");
            Serial.println("📊 Collecting ECG and PPG signals...");
            
        } else if (command == "stop") {
            testRunning = false;
            Serial.println("⏹️  Blood pressure monitoring stopped");
            
        } else if (command == "cal") {
            enterBPCalibrationMode();
            
        } else if (command == "profile") {
            setBPUserProfile();
            
        } else if (command == "status") {
            showBPSystemStatus();
            
        } else if (command == "diag") {
            showBPDetailedDiagnostics();
            
        } else if (command == "help") {
            displayBPTestInstructions();
            
        } else if (command.length() > 0) {
            Serial.println("❌ Unknown command: " + command);
            Serial.println("Type 'help' for available commands");
        }
    }
}

void calculateAndDisplayBPResults(SensorReadings& readings) {
    Serial.println("\n🔍 CALCULATING BLOOD PRESSURE...");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    BloodPressureData bp = readings.bloodPressure;
    
    if (bp.validReading) {
        // Main results
        String category = BPAnalysis::interpretBPReading(bp.systolic, bp.diastolic);
        Serial.printf("🩺 SYSTOLIC:  %.0f mmHg\n", bp.systolic);
        Serial.printf("🩺 DIASTOLIC: %.0f mmHg\n", bp.diastolic);
        Serial.printf("📊 CATEGORY:  %s\n", category.c_str());
        Serial.printf("📈 MAP:       %.1f mmHg\n", bp.meanArterialPressure);
        
        // Advanced metrics
        Serial.println("\n📊 PULSE TRANSIT TIME ANALYSIS:");
        Serial.printf("   PTT: %.1f ms\n", bp.pulseTransitTime);
        Serial.printf("   PWV: %.2f m/s\n", bp.pulseWaveVelocity);
        Serial.printf("   HRV: %.1f ms\n", bp.heartRateVariability);
        
        // Signal quality
        Serial.println("\n📈 SIGNAL QUALITY:");
        Serial.printf("   Overall: %.1f%%\n", bp.signalQuality);
        Serial.printf("   Correlation: %d%%\n", bp.correlationCoeff);
        Serial.printf("   Rhythm: %s\n", bp.rhythmRegular ? "Regular" : "Irregular");
        
        if (bp.needsCalibration) {
            Serial.println("\n⚠️  CALIBRATION RECOMMENDED");
            Serial.println("   Use 'cal' command for better accuracy");
        }
        
        // Health assessment
        provideBPHealthAssessment(bp);
        
    } else {
        Serial.println("❌ BLOOD PRESSURE CALCULATION FAILED");
        Serial.println("   Check sensor placement and signal quality");
    }
    
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
}

void provideBPHealthAssessment(BloodPressureData& bp) {
    Serial.println("\n🏥 HEALTH ASSESSMENT:");
    
    if (bp.systolic < 120 && bp.diastolic < 80) {
        Serial.println("   ✅ Normal blood pressure");
    } else if (bp.systolic < 130 && bp.diastolic < 80) {
        Serial.println("   ⚠️  Elevated blood pressure");
    } else if (bp.systolic < 140 || bp.diastolic < 90) {
        Serial.println("   🔶 Stage 1 Hypertension");
    } else if (bp.systolic < 180 || bp.diastolic < 120) {
        Serial.println("   🔴 Stage 2 Hypertension");
    } else {
        Serial.println("   🚨 Hypertensive Crisis");
    }
}

void enterBPCalibrationMode() {
    Serial.println("\n🔧 BLOOD PRESSURE CALIBRATION");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Serial.println("Take a reference BP measurement, then:");
    
    Serial.print("Enter SYSTOLIC pressure (80-250): ");
    while (!Serial.available()) delay(100);
    float systolic = Serial.parseFloat();
    Serial.println(systolic);
    
    Serial.print("Enter DIASTOLIC pressure (40-150): ");
    while (!Serial.available()) delay(100);
    float diastolic = Serial.parseFloat();
    Serial.println(diastolic);
    
    if (sensors.calibrateBloodPressure(systolic, diastolic)) {
        Serial.println("✅ Calibration successful!");
    } else {
        Serial.println("❌ Calibration failed");
    }
}

void setBPUserProfile() {
    Serial.println("\n👤 USER PROFILE SETUP");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━");
    
    Serial.print("Age (18-100): ");
    while (!Serial.available()) delay(100);
    int age = Serial.parseInt();
    Serial.println(age);
    
    Serial.print("Height in cm (120-220): ");
    while (!Serial.available()) delay(100);
    float height = Serial.parseFloat();
    Serial.println(height);
      Serial.print("Gender (M/F): ");
    while (!Serial.available()) delay(100);
    String gender = Serial.readString();
    gender.trim();
    gender.toLowerCase();
    bool isMale = (gender == "m");
    Serial.println(gender);
    
    sensors.setUserProfile(age, height, isMale);
    Serial.println("✅ Profile updated!");
}

void showBPSystemStatus() {
    Serial.println("\n📊 SYSTEM STATUS");
    Serial.println("━━━━━━━━━━━━━━━━━━━━");
    Serial.println(sensors.getSensorStatus());
}

void showBPDetailedDiagnostics() {
    Serial.println("\n🔬 DETAILED DIAGNOSTICS");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━");
    SensorReadings readings = sensors.readAllSensors();
    sensors.printSensorReadings(readings);
}

void showBPTestStatus() {
    // Brief status update
    Serial.printf("📡 %s\n", sensors.getSensorStatus().c_str());
}

bool initializeSystem() {
    Serial.println("🔄 Initializing system components...");
    
    // Enable watchdog timer for system reliability
    esp_task_wdt_init(30, true); // 30 second timeout
    esp_task_wdt_add(NULL);
    
    // Initialize basic components for all modes
    pinMode(LED_BUILTIN, OUTPUT);
    digitalWrite(LED_BUILTIN, LOW);
    
    // Initialize sensors first (required for all modes)
    if (!sensors.begin()) {
        Serial.println("❌ Sensor initialization failed");
        return false;
    }
    
    // Initialize blood pressure monitor
    if (!bpMonitor.begin()) {
        Serial.println("⚠️ Blood pressure monitor initialization failed");
    }
    
    // Mode-specific initialization
    if (currentMode == NORMAL_MODE) {
        Serial.println("🌐 Initializing full system (Secure Network + Cloud)...");
        
        // Initialize secure network manager
        if (!secureNetwork.begin()) {
            Serial.println("❌ Secure network initialization failed");
            return false;
        }
        
        // Initialize time client
        timeClient.begin();
        if (!timeClient.update()) {
            Serial.println("⚠️ NTP time sync failed, using system time");
        }
        
        // Initialize data manager
        if (!dataManager.begin()) {
            Serial.println("❌ Data manager initialization failed");
            return false;
        }
        
        // Initialize OTA with secure updates
        if (!otaManager.begin()) {
            Serial.println("⚠️ OTA initialization failed, continuing without updates");
        }
        
    } else if (currentMode == BLOOD_PRESSURE_TEST_MODE) {
        Serial.println("🩺 Initializing Blood Pressure Test Mode...");
        // No network components needed for test mode
        
    } else if (currentMode == SENSOR_DEBUG_MODE) {
        Serial.println("🔧 Initializing Sensor Debug Mode...");
        // Sensors only, no network
    }
    
    return true;
}

void handleIncomingCommand(String topic, String message) {
    DynamicJsonDocument doc(512);
    DeserializationError error = deserializeJson(doc, message);
    
    if (error) {
        Serial.println("❌ Failed to parse incoming JSON command");
        return;
    }
    
    String command = doc["command"];
    
    if (command == "calibrate_sensors") {
        sensors.calibrateWeight(1.0); // Default 1kg calibration
        Serial.println("🔧 Sensor calibration initiated");
    }
    else if (command == "restart_device") {
        Serial.println("🔄 Device restart requested");
        ESP.restart();
    }
    else if (command == "update_config") {
        // Handle configuration updates
        Serial.println("⚙️ Configuration update requested");
    }
    else if (command == "get_status") {
        sendDeviceStatus();
    }
    else {
        Serial.println("❓ Unknown command: " + command);
    }
}

void createTasks() {
    Serial.println("🚀 Creating FreeRTOS tasks...");
    
    // Only create tasks for normal mode (test modes run in main loop)
    if (currentMode != NORMAL_MODE) {
        Serial.println("ℹ️ Test mode - using main loop instead of tasks");
        return;
    }
    
    // Sensor reading task (Core 0) - Highest priority for real-time data
    xTaskCreatePinnedToCore(
        sensorTask,           // Task function
        "SensorTask",         // Task name
        8192,                 // Stack size
        NULL,                 // Parameters
        3,                    // Priority (highest)
        &sensorTaskHandle,    // Task handle
        0                     // Core number
    );
    
    // Security and network monitoring task (Core 0)
    xTaskCreatePinnedToCore(
        securityTask,         // Task function
        "SecurityTask",       // Task name
        6144,                 // Stack size
        NULL,                 // Parameters
        2,                    // Priority (high)
        &securityTaskHandle,  // Task handle
        0                     // Core number
    );
    
    // Network communication task (Core 1)
    xTaskCreatePinnedToCore(
        networkTask,          // Task function
        "NetworkTask",        // Task name
        8192,                 // Stack size
        NULL,                 // Parameters
        2,                    // Priority (high)
        &networkTaskHandle,   // Task handle
        1                     // Core number
    );
      // Data processing task (Core 1)
    xTaskCreatePinnedToCore(
        dataTask,             // Task function
        "DataTask",           // Task name
        6144,                 // Stack size
        NULL,                 // Parameters
        1,                    // Priority (normal)
        &dataTaskHandle,      // Task handle
        1                     // Core number
    );
    
    Serial.println("✅ All tasks created successfully");
    Serial.printf("📊 Free heap after task creation: %d bytes\n", ESP.getFreeHeap());
}

void sensorTask(void *parameter) {
    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xFrequency = pdMS_TO_TICKS(1000); // 1 second
    
    while (true) {
        if (systemInitialized) {
            // Check if it's time to read sensors based on intervals
            unsigned long currentTime = millis();
            
            if (currentTime - lastSensorReadTime > 5000) { // Read every 5 seconds
                SensorReadings readings = sensors.readAllSensors();
                if (dataManager.isValidReading(readings)) {
                    dataManager.addSensorData(readings);
                    Serial.println("📊 Sensors read and data stored");
                }
                lastSensorReadTime = currentTime;
            }
            
            // Check for any sensor alerts
            checkSensorAlerts();
        }
        
        vTaskDelayUntil(&xLastWakeTime, xFrequency);
    }
}

void networkTask(void *parameter) {
    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xFrequency = pdMS_TO_TICKS(500); // 500ms
    
    while (true) {
        if (systemInitialized) {
            // Maintain secure network connections
            secureNetwork.checkConnections();
            
            // Update time
            timeClient.update();
            
            // Handle OTA updates
            otaManager.handleAutoUpdates();
            
            // Feed the watchdog
            esp_task_wdt_reset();
        }
        
        vTaskDelayUntil(&xLastWakeTime, xFrequency);
    }
}

void securityTask(void *parameter) {
    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xFrequency = pdMS_TO_TICKS(10000); // 10 seconds
    
    while (true) {
        if (systemInitialized) {
            // Monitor system health
            monitorSystemHealth();
            
            // Check for security threats
            if (!secureNetwork.isSecureConnection()) {
                Serial.println("⚠️ Security threat detected - insecure connection");
                // Implement security response
            }
            
            // Monitor network statistics
            auto stats = secureNetwork.getNetworkStatistics();
            if (stats.failedRequests > stats.successfulRequests) {
                Serial.println("⚠️ High network failure rate detected");
            }
            
            // Memory leak detection
            static unsigned long lastFreeHeap = ESP.getFreeHeap();
            unsigned long currentHeap = ESP.getFreeHeap();
            if (currentHeap < lastFreeHeap - 1000) {
                Serial.printf("⚠️ Potential memory leak: %lu -> %lu bytes\n", 
                             lastFreeHeap, currentHeap);
            }
            lastFreeHeap = currentHeap;
            
            // Feed the watchdog        esp_task_wdt_reset();
        }
        
        vTaskDelayUntil(&xLastWakeTime, xFrequency);
    }
}

void dataTask(void *parameter) {
    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xFrequency = pdMS_TO_TICKS(2000); // 2 seconds
    
    while (true) {
        if (systemInitialized) {
            // Process and send sensor data with secure transmission
            processAndSendData();
            
            // Feed the watchdog
            esp_task_wdt_reset();
        }
        
        vTaskDelayUntil(&xLastWakeTime, xFrequency);
    }
}

void processAndSendData() {
    // Get latest sensor readings
    SensorReadings data = sensors.readAllSensors();
    
    if (dataManager.isValidReading(data)) {
        // Store data locally first for reliability
        dataManager.addSensorData(data);
        
        // Create encrypted JSON payload
        String jsonData = dataManager.formatSensorDataJSON(data);
        
        // Send via secure network manager with priority based on data type
        TransmissionPriority priority = PRIORITY_NORMAL;
        
        // Critical health alerts get high priority
        if (data.heartRate.heartRate > MAX_HEART_RATE || 
            data.heartRate.heartRate < MIN_HEART_RATE ||
            data.heartRate.spO2 < 90 ||
            data.temperature.temperature > 39.5) {
            priority = PRIORITY_CRITICAL;
        }
        
        bool success = secureNetwork.sendSensorData(jsonData, priority);
        
        if (success) {
            Serial.println("✅ Sensor data transmitted securely");
        } else {
            Serial.println("⚠️ Data queued for retry transmission");
        }
        
        // Log data summary
        Serial.printf("📊 HR: %.0f bpm, SpO2: %.0f%%, Temp: %.1f°C\n", 
                     data.heartRate.heartRate, 
                     data.heartRate.spO2, 
                     data.temperature.temperature);
    }
}

void sendToFirebase(String data) {
    if (secureNetwork.sendSensorData(data, PRIORITY_NORMAL)) {
        Serial.println("✅ Data published to Firebase");
    } else {
        Serial.println("❌ Failed to publish data to Firebase");
        // Data is already stored locally by dataManager
    }
}

void reconnectMQTT() {
    // This functionality is now handled by secureNetwork.checkConnections()
    // Keeping this function for compatibility
    secureNetwork.checkConnections();
}

void checkSensorAlerts() {
    // Get latest readings from data manager
    SensorReadings data = dataManager.getLatestReading();
    
    // Check heart rate alerts
    if (data.heartRate.validReading) {
        if (data.heartRate.heartRate > MAX_HEART_RATE || data.heartRate.heartRate < MIN_HEART_RATE) {
            sendAlert("heart_rate", data.heartRate.heartRate);
        }
        
        // Check SpO2 alerts
        if (data.heartRate.spO2 < 95) {
            sendAlert("spo2", data.heartRate.spO2);
        }
    }
    
    // Check temperature alerts
    if (data.temperature.validReading) {
        if (data.temperature.temperature > MAX_TEMPERATURE || data.temperature.temperature < MIN_TEMPERATURE) {
            sendAlert("temperature", data.temperature.temperature);
        }
    }
}

void sendAlert(String type, float value) {
    DynamicJsonDocument doc(512);
    doc["type"] = type;
    doc["value"] = value;
    doc["timestamp"] = millis();
    doc["device_id"] = DEVICE_ID;
    doc["severity"] = "high";    String alertJson;
    serializeJson(doc, alertJson);
    
    secureNetwork.sendAlert(alertJson, PRIORITY_CRITICAL);
    Serial.printf("🚨 Alert sent: %s = %.2f\n", type.c_str(), value);
}

void sendHeartbeat() {
    DynamicJsonDocument heartbeatDoc(512);
    heartbeatDoc["deviceId"] = DEVICE_ID;
    heartbeatDoc["firmwareVersion"] = FIRMWARE_VERSION;
    heartbeatDoc["uptime"] = millis();
    heartbeatDoc["freeHeap"] = ESP.getFreeHeap();
    heartbeatDoc["cpuTemperature"] = temperatureRead();
    heartbeatDoc["wifiRSSI"] = WiFi.RSSI();
    heartbeatDoc["securityLevel"] = secureNetwork.getCurrentSecurityLevel();
    heartbeatDoc["queuedData"] = secureNetwork.getQueueSize();
      // Add sensor status
    heartbeatDoc["sensors"]["heartRate"] = sensors.isHeartRateReady();
    heartbeatDoc["sensors"]["temperature"] = sensors.isTemperatureReady();
    heartbeatDoc["sensors"]["bioimpedance"] = sensors.isBioimpedanceReady();
    heartbeatDoc["sensors"]["ecg"] = sensors.isECGReady();
    
    String heartbeatJson;
    serializeJson(heartbeatDoc, heartbeatJson);
    
    bool success = secureNetwork.sendHeartbeat(heartbeatJson);
    if (success) {
        Serial.println("💓 Secure heartbeat sent");
    } else {
        Serial.println("❌ Heartbeat transmission failed");
    }
}

void monitorSystemHealth() {
    static unsigned long lastHealthCheck = 0;
    unsigned long currentTime = millis();
    
    if (currentTime - lastHealthCheck > 30000) { // Check every 30 seconds
        // Memory health check
        unsigned long freeHeap = ESP.getFreeHeap();
        if (freeHeap < 20000) { // Less than 20KB free
            Serial.printf("⚠️ Low memory warning: %lu bytes free\n", freeHeap);
        }
        
        // Flash storage health
        size_t freeSketchSpace = ESP.getFreeSketchSpace();
        if (freeSketchSpace < 100000) { // Less than 100KB for OTA
            Serial.printf("⚠️ Low flash space: %lu bytes free\n", freeSketchSpace);
        }
        
        // Network health
        if (secureNetwork.isFullyConnected()) {
            auto stats = secureNetwork.getNetworkStatistics();
            float successRate = (float)stats.successfulRequests / 
                               (stats.successfulRequests + stats.failedRequests) * 100.0;
            
            if (successRate < 80.0) {
                Serial.printf("⚠️ Network health degraded: %.1f%% success rate\n", successRate);
            }
        }
        
        // Sensor health check
        if (!sensors.isHeartRateReady() || !sensors.isECGReady()) {
            Serial.println("⚠️ Critical sensors not responding");
        }
        
        // Temperature monitoring (prevent overheating)
        float cpuTemp = temperatureRead();
        if (cpuTemp > 70.0) {
            Serial.printf("🔥 High CPU temperature: %.1f°C\n", cpuTemp);
        }
          lastHealthCheck = currentTime;
    }
}

// Enhanced device status reporting
void sendDeviceStatus() {
    DynamicJsonDocument statusDoc(1024);
    
    // Device information
    statusDoc["deviceId"] = DEVICE_ID;
    statusDoc["firmwareVersion"] = FIRMWARE_VERSION;
    statusDoc["hardwareRevision"] = "ESP32-v1.0";
    statusDoc["uptime"] = millis();
    statusDoc["lastRestart"] = "power_on"; // Could track restart reasons
    
    // System health
    statusDoc["system"]["freeHeap"] = ESP.getFreeHeap();
    statusDoc["system"]["cpuFreq"] = ESP.getCpuFreqMHz();
    statusDoc["system"]["flashSize"] = ESP.getFlashChipSize();
    statusDoc["system"]["freeSketchSpace"] = ESP.getFreeSketchSpace();
    statusDoc["system"]["cpuTemperature"] = temperatureRead();
    
    // Network status
    statusDoc["network"]["connected"] = secureNetwork.isFullyConnected();
    statusDoc["network"]["securityLevel"] = secureNetwork.getCurrentSecurityLevel();
    statusDoc["network"]["signalStrength"] = secureNetwork.getSignalStrength();
    statusDoc["network"]["queuedData"] = secureNetwork.getQueueSize();
    
    auto netStats = secureNetwork.getNetworkStatistics();
    statusDoc["network"]["stats"]["sent"] = netStats.totalBytesSent;
    statusDoc["network"]["stats"]["successful"] = netStats.successfulRequests;
    statusDoc["network"]["stats"]["failed"] = netStats.failedRequests;
      // Sensor status
    statusDoc["sensors"]["heartRate"]["ready"] = sensors.isHeartRateReady();
    statusDoc["sensors"]["temperature"]["ready"] = sensors.isTemperatureReady();
    statusDoc["sensors"]["bioimpedance"]["ready"] = sensors.isBioimpedanceReady();
    statusDoc["sensors"]["ecg"]["ready"] = sensors.isECGReady();
    statusDoc["sensors"]["weight"]["ready"] = sensors.isWeightReady();
    
    // Configuration
    statusDoc["config"]["mode"] = (currentMode == NORMAL_MODE) ? "normal" : 
                                  (currentMode == BLOOD_PRESSURE_TEST_MODE) ? "bp_test" : "debug";
    statusDoc["config"]["secureTransmission"] = USE_TLS_ENCRYPTION;
    statusDoc["config"]["certificateVerification"] = VERIFY_FIREBASE_CERT;
    
    String statusJson;
    serializeJson(statusDoc, statusJson);
    
    bool success = secureNetwork.sendSensorData(statusJson, PRIORITY_LOW);
    if (success) {
        Serial.println("📋 Device status transmitted");
    }
}

// Watchdog timeout handler
void handleWatchdogTimeout() {
    Serial.println("🚨 Watchdog timeout detected - system restart required");
    
    // Log critical information before restart
    Serial.printf("Last known state: heap=%lu, uptime=%lu\n", 
                  ESP.getFreeHeap(), millis());
    
    // Attempt to send emergency status
    sendAlert("watchdog_timeout", millis());
    
    delay(1000);
    ESP.restart();
}

// Enhanced serial command handler with security features
void handleSerialCommands() {
    if (Serial.available()) {
        String command = Serial.readStringUntil('\n');
        command.trim();
        command.toLowerCase();
        
        if (command == "status") {
            Serial.println("\n=== BIOTRACK DEVICE STATUS ===");
            Serial.printf("Device ID: %s\n", DEVICE_ID);
            Serial.printf("Firmware: %s\n", FIRMWARE_VERSION);
            Serial.printf("Uptime: %lu ms (%.1f hours)\n", millis(), millis() / 3600000.0);
            Serial.printf("Free heap: %lu bytes\n", ESP.getFreeHeap());
            Serial.printf("CPU temp: %.1f°C\n", temperatureRead());
            Serial.println();
            
            Serial.println("Network Status:");
            Serial.println(secureNetwork.getConnectionInfo());
            Serial.println();
            
            Serial.println("Sensor Status:");
            Serial.println(sensors.getSensorStatus());
            
        } else if (command == "security") {
            Serial.println("\n=== SECURITY STATUS ===");
            Serial.printf("Security Level: %d\n", secureNetwork.getCurrentSecurityLevel());
            Serial.printf("Secure Connection: %s\n", secureNetwork.isSecureConnection() ? "Yes" : "No");
            Serial.printf("Certificate Verification: %s\n", VERIFY_FIREBASE_CERT ? "Enabled" : "Disabled");
            Serial.printf("Queued Data: %d items\n", secureNetwork.getQueueSize());
            
            auto stats = secureNetwork.getNetworkStatistics();
            float successRate = (stats.successfulRequests + stats.failedRequests > 0) ?
                               (float)stats.successfulRequests / (stats.successfulRequests + stats.failedRequests) * 100.0 : 0;
            Serial.printf("Success Rate: %.1f%%\n", successRate);
            
        } else if (command == "network") {
            Serial.println("\n=== NETWORK DIAGNOSTICS ===");
            Serial.println(secureNetwork.getNetworkDiagnostics());
            
        } else if (command == "sensors") {
            Serial.println("\n=== SENSOR READINGS ===");
            SensorReadings readings = sensors.readAllSensors();
            sensors.printSensorReadings(readings);
            
        } else if (command == "test_alert") {
            Serial.println("Sending test alert...");
            sendAlert("test", 123.45);
            
        } else if (command == "test_heartbeat") {
            Serial.println("Sending test heartbeat...");
            sendHeartbeat();
            
        } else if (command == "restart") {
            Serial.println("🔄 Restarting device in 3 seconds...");
            delay(3000);
            ESP.restart();
            
        } else if (command == "temp_test") {
            Serial.println("🌡️ Starting DS18B20 temperature test...");
            sensors.testDS18B20();
            
        } else if (command.startsWith("temp_cal ")) {
            String offsetStr = command.substring(9);
            float offset = offsetStr.toFloat();
            sensors.setTemperatureOffset(offset);
            Serial.printf("✅ Temperature offset set to %.2f°C\n", offset);
            
        } else if (command == "temp_cal") {
            float currentOffset = sensors.getTemperatureOffset();
            Serial.printf("🌡️ Current temperature offset: %.2f°C\n", currentOffset);
            Serial.println("Usage: temp_cal <offset_value>");
            Serial.println("Example: temp_cal 5.0");
            
        } else if (command == "help") {
            Serial.println("\n=== AVAILABLE COMMANDS ===");
            Serial.println("status          - Show device status");
            Serial.println("security        - Show security status");
            Serial.println("network         - Show network diagnostics");
            Serial.println("sensors         - Read all sensors");
            Serial.println("test_alert      - Send test alert");
            Serial.println("test_heartbeat  - Send test heartbeat");
            Serial.println("temp_test       - Test DS18B20 temperature sensor");
            Serial.println("temp_cal [val]  - Set/show temperature calibration offset");
            Serial.println("restart         - Restart the device");
            Serial.println("help            - Show this help");
            Serial.println("=============================");
            
        } else if (command.length() > 0) {
            Serial.println("❌ Unknown command. Type 'help' for available commands.");
        }
    }
}

void validatePinConfiguration() {
    Serial.println("🔧 Validating pin configuration...");
    
    // Check for pin conflicts
    bool hasConflicts = false;
    
    // DS18B20 vs other sensors
    if (DS18B20_PIN == AD5941_CS_PIN) {
        Serial.printf("⚠️  PIN CONFLICT: DS18B20 (GPIO %d) conflicts with AD5941 CS\n", DS18B20_PIN);
        hasConflicts = true;
    }
    
    // Display pin assignments
    Serial.println("📍 Pin Assignments:");
    Serial.printf("  DS18B20 Temperature: GPIO %d\n", DS18B20_PIN);
    Serial.printf("  MAX30102 I2C: SDA=%d, SCL=%d\n", MAX30102_SDA_PIN, MAX30102_SCL_PIN);
    Serial.printf("  Glucose I2C: SDA=%d, SCL=%d\n", GLUCOSE_SDA_PIN, GLUCOSE_SCL_PIN);
    Serial.printf("  Load Cell: DOUT=%d, SCK=%d\n", LOAD_CELL_DOUT_PIN, LOAD_CELL_SCK_PIN);
    Serial.printf("  AD5941 SPI: CS=%d, MOSI=%d, MISO=%d, SCK=%d\n", 
                  AD5941_CS_PIN, AD5941_MOSI_PIN, AD5941_MISO_PIN, AD5941_SCK_PIN);
    Serial.printf("  ECG: DATA=%d, LO+=%d, LO-=%d\n", ECG_PIN, LO_PLUS_PIN, LO_MINUS_PIN);
    
    if (!hasConflicts) {
        Serial.println("✅ Pin configuration validated - no conflicts detected");
    } else {
        Serial.println("❌ Pin conflicts detected! Please review hardware connections.");
    }
}
