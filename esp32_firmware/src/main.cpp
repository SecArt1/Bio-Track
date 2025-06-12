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
    SENSOR_DEBUG_MODE,
    INDIVIDUAL_TEST_MODE
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
void runIndividualTestLoop();
void displayIndividualTestMenu();
void runHeartRateTest();
void runTemperatureTest();
void runWeightTest();
void runBioimpedanceTest();
void runECGTest();
void runGlucoseTest();
void runBloodPressureIndividualTest();
void runAllSensorsTest();
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
void runBodyCompositionTest(); // Add function for body composition test

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
    Serial.println();    Serial.println("📋 SELECT OPERATION MODE:");
    Serial.println("1. Normal Mode (Full sensor system + cloud)");
    Serial.println("2. Blood Pressure Test Mode (BP monitoring only)");
    Serial.println("3. Sensor Debug Mode (All sensors, no cloud)");
    Serial.println("4. Individual Test Mode (Test specific sensors)");
    Serial.println();
    Serial.print("Enter mode (1-4): ");
    
    // Wait for user input with timeout
    unsigned long startTime = millis();
    while (!Serial.available() && (millis() - startTime < 10000)) {
        delay(100);
    }
    
    if (Serial.available()) {
        int mode = Serial.parseInt();        switch (mode) {
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
            case 4:
                currentMode = INDIVIDUAL_TEST_MODE;
                Serial.println("4 - Individual Test Mode Selected");
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
    
    if (currentMode == INDIVIDUAL_TEST_MODE) {
        // Run individual sensor test interface
        runIndividualTestLoop();
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

void showBPTestStatus() {    // Brief status update
    Serial.printf("📡 %s\n", sensors.getSensorStatus().c_str());
}

void runIndividualTestLoop() {
    static bool menuInitialized = false;
    
    if (!menuInitialized) {
        displayIndividualTestMenu();
        menuInitialized = true;
    }
    
    if (Serial.available()) {
        String command = Serial.readString();
        command.trim();
        command.toLowerCase();
        
        if (command == "1" || command == "hr" || command == "heart") {
            runHeartRateTest();
        } else if (command == "2" || command == "temp" || command == "temperature") {
            runTemperatureTest();
        } else if (command == "3" || command == "weight" || command == "scale") {
            runWeightTest();        } else if (command == "4" || command == "bio" || command == "bioimpedance") {
            runBioimpedanceTest();
        } else if (command == "5" || command == "body" || command == "composition") {
            runBodyCompositionTest();
        } else if (command == "6" || command == "ecg") {
            runECGTest();
        } else if (command == "7" || command == "glucose" || command == "sugar") {
            runGlucoseTest();
        } else if (command == "8" || command == "bp" || command == "blood") {
            runBloodPressureIndividualTest();
        } else if (command == "9" || command == "all") {
            runAllSensorsTest();
        } else if (command == "menu" || command == "help") {
            displayIndividualTestMenu();
        } else if (command == "exit" || command == "quit") {
            Serial.println("🔄 Restarting to mode selection...");
            delay(1000);
            ESP.restart();
        } else if (command.length() > 0) {
            Serial.println("❌ Unknown command: " + command);
            Serial.println("Type 'menu' to see available tests or 'exit' to restart");
        }
    }
    
    delay(100);
}

void displayIndividualTestMenu() {
    Serial.println("\n══════════════════════════════════════════════════════════");
    Serial.println("🧪 INDIVIDUAL SENSOR TEST MODE");
    Serial.println("   Test specific sensors independently");
    Serial.println("══════════════════════════════════════════════════════════");
    Serial.println();
    Serial.println("📋 AVAILABLE TESTS:");
    Serial.println("1. Heart Rate & SpO2 Test     (hr, heart)");
    Serial.println("2. Temperature Test           (temp, temperature)");
    Serial.println("3. Weight/Scale Test          (weight, scale)");    Serial.println("4. Bioimpedance Test          (bio, bioimpedance)");
    Serial.println("5. Body Composition Analysis  (body, composition)");
    Serial.println("6. ECG Test                   (ecg)");
    Serial.println("7. Glucose Test               (glucose, sugar)");
    Serial.println("8. Blood Pressure Test        (bp, blood)");
    Serial.println("9. All Sensors Test           (all)");
    Serial.println();
    Serial.println("📟 COMMANDS:");
    Serial.println("  menu/help  - Show this menu");
    Serial.println("  exit/quit  - Return to mode selection");
    Serial.println();
    Serial.println("💡 Enter test number (1-9) or use text commands");
    Serial.println("══════════════════════════════════════════════════════════");
    Serial.print("Select test: ");
}

void runHeartRateTest() {
    Serial.println("\n🫀 HEART RATE & SPO2 SENSOR TEST");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    if (!sensors.isHeartRateReady()) {
        Serial.println("❌ Heart rate sensor not ready!");
        Serial.println("   Check MAX30102 connections:");
        Serial.printf("   SDA: GPIO %d, SCL: GPIO %d\n", MAX30102_SDA_PIN, MAX30102_SCL_PIN);
        Serial.println("   Press any key to return to menu...");
        while (!Serial.available()) delay(100);
        Serial.read();
        return;
    }
    
    Serial.println("✅ Heart rate sensor ready");
    Serial.println("📋 Place finger firmly on sensor and hold still");
    Serial.println("📊 Reading for 30 seconds... (press any key to stop early)");
    Serial.println();
    
    unsigned long startTime = millis();
    unsigned long lastReading = 0;
    int readingCount = 0;
    float totalHR = 0;
    float totalSpO2 = 0;
    
    while ((millis() - startTime < 30000) && !Serial.available()) {
        if (millis() - lastReading > 2000) { // Read every 2 seconds
            HeartRateData hrData = sensors.readHeartRate();
            
            if (hrData.validReading) {
                readingCount++;
                totalHR += hrData.heartRate;
                totalSpO2 += hrData.spO2;
                  Serial.printf("📊 Reading %d: HR=%.0f bpm, SpO2=%.0f%%\n", 
                             readingCount, hrData.heartRate, hrData.spO2);
            } else {
                Serial.println("⚠️  No valid reading - check finger placement");
            }
            
            lastReading = millis();
        }
        delay(100);
    }
    
    if (Serial.available()) Serial.read(); // Clear input
    
    Serial.println("\n📊 HEART RATE TEST RESULTS:");
    if (readingCount > 0) {
        float avgHR = totalHR / readingCount;
        float avgSpO2 = totalSpO2 / readingCount;
        
        Serial.printf("   Average Heart Rate: %.0f bpm\n", avgHR);
        Serial.printf("   Average SpO2: %.0f%%\n", avgSpO2);
        Serial.printf("   Valid Readings: %d/%d\n", readingCount, 15);
        
        // Health assessment
        if (avgHR >= 60 && avgHR <= 100) {
            Serial.println("   ✅ Heart rate within normal range");
        } else {
            Serial.println("   ⚠️  Heart rate outside normal range (60-100 bpm)");
        }
        
        if (avgSpO2 >= 95) {
            Serial.println("   ✅ SpO2 within normal range");
        } else {
            Serial.println("   ⚠️  SpO2 below normal range (>95%)");
        }
    } else {
        Serial.println("   ❌ No valid readings obtained");
    }
    
    Serial.println("\nPress any key to return to menu...");
    while (!Serial.available()) delay(100);
    Serial.read();
}

void runTemperatureTest() {
    Serial.println("\n🌡️  TEMPERATURE SENSOR TEST");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    if (!sensors.isTemperatureReady()) {
        Serial.println("❌ Temperature sensor not ready!");
        Serial.println("   Check DS18B20 connections:");
        Serial.printf("   Data: GPIO %d\n", DS18B20_PIN);
        Serial.println("   VCC: 3.3V, GND: Ground, 4.7kΩ pullup resistor");
        Serial.println("   Press any key to return to menu...");
        while (!Serial.available()) delay(100);
        Serial.read();
        return;
    }
    
    Serial.println("✅ Temperature sensor ready");
    Serial.println("📊 Reading for 20 seconds... (press any key to stop early)");
    Serial.println();
    
    unsigned long startTime = millis();
    unsigned long lastReading = 0;
    int readingCount = 0;
    float totalTemp = 0;
    float minTemp = 999;
    float maxTemp = -999;
    
    while ((millis() - startTime < 20000) && !Serial.available()) {
        if (millis() - lastReading > 1000) { // Read every second
            TemperatureData tempData = sensors.getTemperature();
            
            if (tempData.validReading) {
                readingCount++;
                totalTemp += tempData.temperature;
                minTemp = min(minTemp, tempData.temperature);
                maxTemp = max(maxTemp, tempData.temperature);
                
                Serial.printf("🌡️  Reading %d: %.2f°C (%.2f°F)\n", 
                             readingCount, tempData.temperature, (tempData.temperature * 9.0/5.0) + 32);
            } else {
                Serial.println("⚠️  No valid reading");
            }
            
            lastReading = millis();
        }
        delay(100);
    }
    
    if (Serial.available()) Serial.read(); // Clear input
    
    Serial.println("\n📊 TEMPERATURE TEST RESULTS:");
    if (readingCount > 0) {
        float avgTemp = totalTemp / readingCount;
        
        Serial.printf("   Average Temperature: %.2f°C (%.2f°F)\n", avgTemp, (avgTemp * 9.0/5.0) + 32);
        Serial.printf("   Temperature Range: %.2f°C to %.2f°C\n", minTemp, maxTemp);
        Serial.printf("   Valid Readings: %d/%d\n", readingCount, 20);
        Serial.printf("   Current Offset: %.2f°C\n", sensors.getTemperatureOffset());
        
        // Health assessment for body temperature
        if (avgTemp >= 36.0 && avgTemp <= 37.5) {
            Serial.println("   ✅ Normal body temperature range");
        } else if (avgTemp > 37.5 && avgTemp < 38.0) {
            Serial.println("   ⚠️  Slightly elevated temperature");
        } else if (avgTemp >= 38.0) {
            Serial.println("   🔥 Fever detected");
        } else {
            Serial.println("   🧊 Below normal body temperature");
        }
    } else {
        Serial.println("   ❌ No valid readings obtained");
    }
    
    Serial.println("\n💡 Tip: Use 'temp_cal <offset>' command to calibrate if needed");
    Serial.println("Press any key to return to menu...");
    while (!Serial.available()) delay(100);
    Serial.read();
}

void runWeightTest() {
    Serial.println("\n⚖️  WEIGHT/SCALE SENSOR TEST");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    if (!sensors.isWeightReady()) {
        Serial.println("❌ Weight sensor not ready!");
        Serial.println("   Check HX711 load cell connections:");
        Serial.printf("   DOUT: GPIO %d, SCK: GPIO %d\n", LOAD_CELL_DOUT_PIN, LOAD_CELL_SCK_PIN);
        Serial.println("   VCC: 3.3V, GND: Ground");
        Serial.println("   Press any key to return to menu...");
        while (!Serial.available()) delay(100);
        Serial.read();
        return;
    }
    
    Serial.println("✅ Weight sensor ready");
    Serial.println("📋 Instructions:");
    Serial.println("   1. Ensure scale is empty for tare");
    Serial.println("   2. Place known weight for testing");
    Serial.println("   3. Remove weight to see tare function");
    Serial.println();
    Serial.println("📊 Monitoring weight... (press any key to stop)");
    Serial.println();
    
    // Tare the scale first
    Serial.println("🔄 Taring scale...");
    sensors.tareWeight();
    delay(1000);
    
    unsigned long lastReading = 0;
    int readingCount = 0;
    
    while (!Serial.available()) {
        if (millis() - lastReading > 500) { // Read every 500ms
            WeightData weightData = sensors.getWeight();
            
            if (weightData.validReading) {
                readingCount++;
                  Serial.printf("⚖️  Reading %d: %.2f kg (%.2f lbs)\n", 
                             readingCount, weightData.weight, weightData.weight * 2.20462);
                
                // Weight status
                if (abs(weightData.weight) < 0.1) {
                    Serial.println("   📊 Scale appears empty");
                } else if (weightData.weight > 0) {
                    Serial.printf("   📦 Weight detected: %.2f kg\n", weightData.weight);
                } else {
                    Serial.println("   ⚠️  Negative weight (check calibration)");
                }
            } else {
                Serial.println("⚠️  No valid reading");
            }
            
            lastReading = millis();
        }
        delay(100);
    }
    
    if (Serial.available()) Serial.read(); // Clear input
    
    Serial.println("\n📊 WEIGHT TEST COMPLETED");
    Serial.printf("   Total Readings: %d\n", readingCount);
    Serial.println("   ✅ Scale monitoring finished");
    
    Serial.println("\n💡 Tips:");
    Serial.println("   - Use known weights to verify accuracy");
    Serial.println("   - Calibrate using sensor.calibrateWeight() if needed");
    Serial.println("   - Ensure stable platform for accurate readings");
    
    Serial.println("\nPress any key to return to menu...");
    while (!Serial.available()) delay(100);
    Serial.read();
}

void runBioimpedanceTest() {
    Serial.println("\n⚡ BIOIMPEDANCE SENSOR TEST");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    if (!sensors.isBioimpedanceReady()) {
        Serial.println("❌ Bioimpedance sensor not ready!");
        Serial.println("   Check AD5941 connections:");
        Serial.printf("   CS: GPIO %d, MOSI: GPIO %d, MISO: GPIO %d, SCK: GPIO %d\n", 
                      AD5941_CS_PIN, AD5941_MOSI_PIN, AD5941_MISO_PIN, AD5941_SCK_PIN);
        Serial.println("   VCC: 3.3V, GND: Ground");
        Serial.println("   Press any key to return to menu...");
        while (!Serial.available()) delay(100);
        Serial.read();
        return;
    }
    
    Serial.println("✅ Bioimpedance sensor ready");
    Serial.println("📋 Instructions:");
    Serial.println("   1. Connect electrodes for body composition measurement");
    Serial.println("   2. Ensure good skin contact");
    Serial.println("   3. Stay still during measurement");
    Serial.println();
    Serial.println("📊 Running bioimpedance analysis... (press any key to stop)");
    Serial.println();
    
    unsigned long lastReading = 0;
    int readingCount = 0;
    float totalImpedance = 0;
    
    while (!Serial.available()) {
        if (millis() - lastReading > 2000) { // Read every 2 seconds
            BioimpedanceData bioData = sensors.getBioimpedance();
            
            if (bioData.validReading) {
                readingCount++;
                totalImpedance += bioData.impedance;
                
                Serial.printf("⚡ Reading %d: %.2f Ω at %.0f Hz\n", 
                             readingCount, bioData.impedance, bioData.frequency);                Serial.printf("   Phase: %.2f°, Impedance: %.2f Ω\n", 
                             bioData.phase, bioData.impedance);
                
                // Basic body composition estimates (simplified)
                if (bioData.impedance > 300 && bioData.impedance < 800) {
                    Serial.println("   📊 Impedance within normal range for body composition");
                } else {
                    Serial.println("   ⚠️  Impedance outside typical range - check electrode contact");
                }
            } else {
                Serial.println("⚠️  No valid reading - check connections");
            }
            
            lastReading = millis();
        }
        delay(100);
    }
    
    if (Serial.available()) Serial.read(); // Clear input
    
    Serial.println("\n📊 BIOIMPEDANCE TEST RESULTS:");
    if (readingCount > 0) {
        float avgImpedance = totalImpedance / readingCount;
        
        Serial.printf("   Average Impedance: %.2f Ω\n", avgImpedance);
        Serial.printf("   Valid Readings: %d\n", readingCount);
        
        // Basic assessment
        if (avgImpedance >= 300 && avgImpedance <= 800) {
            Serial.println("   ✅ Impedance suggests good electrode contact");
        } else {
            Serial.println("   ⚠️  Check electrode placement and skin contact");
        }
    } else {
        Serial.println("   ❌ No valid readings obtained");
    }
    
    Serial.println("\n💡 Note: This is a basic impedance test");
    Serial.println("   Full body composition analysis requires calibration");
    
    Serial.println("\nPress any key to return to menu...");
    while (!Serial.available()) delay(100);
    Serial.read();
}

void runECGTest() {
    Serial.println("\n💓 ECG SENSOR TEST");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    if (!sensors.isECGReady()) {
        Serial.println("❌ ECG sensor not ready!");
        Serial.println("   Check AD8232 ECG connections:");
        Serial.printf("   Signal: GPIO %d, LO+: GPIO %d, LO-: GPIO %d\n", 
                      ECG_PIN, LO_PLUS_PIN, LO_MINUS_PIN);
        Serial.println("   Connect electrodes: RA (right arm), LA (left arm), RL (right leg)");
        Serial.println("   Press any key to return to menu...");
        while (!Serial.available()) delay(100);
        Serial.read();
        return;
    }
    
    Serial.println("✅ ECG sensor ready");
    Serial.println();
    Serial.println("📋 SELECT ECG TEST MODE:");
    Serial.println("1. Heart Rate Analysis & CSV Export  (for diagrams)");
    Serial.println("2. Real-time ECG Waveform Monitor    (visual display)");
    Serial.println("3. Basic ECG Test                    (original test)");
    Serial.println();
    Serial.print("Enter choice (1-3): ");
    
    // Wait for user input
    while (!Serial.available()) delay(100);
    int choice = Serial.parseInt();
    Serial.println(choice);
    
    switch (choice) {
        case 1:
            Serial.println("\n🫀 Starting Heart Rate Analysis & CSV Export...");
            Serial.println("   This test generates CSV data for heart rate diagrams");
            delay(1000);
            sensors.testAD8232ECG();
            break;
            
        case 2:
            Serial.println("\n📊 Starting Real-time ECG Waveform Monitor...");
            Serial.println("   This shows a visual representation of the ECG signal");
            delay(1000);
            sensors.runECGMonitor();
            break;
            
        case 3:
        default:
            // Original ECG test implementation
            Serial.println("\n📊 Starting Basic ECG Test...");
            delay(1000);
            
            Serial.println("📋 Instructions:");
            Serial.println("   1. Attach ECG electrodes properly");
            Serial.println("   2. Sit still and breathe normally");
            Serial.println("   3. Avoid movement during recording");
            Serial.println();
            Serial.println("📊 Recording ECG for 30 seconds... (press any key to stop early)");
            Serial.println();
            
            unsigned long startTime = millis();
            unsigned long lastReading = 0;
            int readingCount = 0;
            int peakCount = 0;
            float avgHeartRate = 0;
            
            while ((millis() - startTime < 30000) && !Serial.available()) {
                if (millis() - lastReading > 100) { // Sample at 10Hz for ECG display
                    ECGData ecgData = sensors.getECG();
                    
                    if (ecgData.validReading) {
                        readingCount++;
                          // Simple ECG signal display every 10 readings
                        if (readingCount % 10 == 0) {
                            Serial.printf("💓 ECG: %.2f mV, BPM: %d, Peaks: %d\n", 
                                         ecgData.avgFilteredValue, ecgData.avgBPM, ecgData.peakCount);
                            
                            if (ecgData.avgBPM > 0) {
                                avgHeartRate = (avgHeartRate * peakCount + ecgData.avgBPM) / (peakCount + 1);
                                peakCount++;
                            }
                        }
                        
                        // Lead-off detection
                        if (ecgData.leadOff) {
                            Serial.println("⚠️  Lead-off detected - check electrode connections");
                        }
                    } else {
                        if (readingCount % 50 == 0) { // Show status every 5 seconds
                            Serial.println("⚠️  No valid ECG signal");
                        }
                    }
                    
                    lastReading = millis();
                }
                delay(10);
            }
            
            if (Serial.available()) Serial.read(); // Clear input
            
            Serial.println("\n📊 ECG TEST RESULTS:");
            if (readingCount > 0) {
                Serial.printf("   Total Samples: %d\n", readingCount);
                Serial.printf("   Valid Heart Rate Readings: %d\n", peakCount);
                
                if (peakCount > 0) {
                    Serial.printf("   Average Heart Rate: %.0f bpm\n", avgHeartRate);
                    
                    if (avgHeartRate >= 60 && avgHeartRate <= 100) {
                        Serial.println("   ✅ Heart rate within normal range");
                    } else {
                        Serial.println("   ⚠️  Heart rate outside normal range");
                    }
                }
                
                Serial.printf("   Recording Duration: %.1f seconds\n", (millis() - startTime) / 1000.0);
            } else {
                Serial.println("   ❌ No valid ECG data recorded");
                Serial.println("   Check electrode placement and connections");
            }
            break;
    }
    
    Serial.println("\n💡 Tips for better ECG readings:");
    Serial.println("   - Ensure electrodes have good skin contact");
    Serial.println("   - Use conductive gel if available");
    Serial.println("   - Minimize movement and muscle tension");
    
    Serial.println("\nPress any key to return to menu...");
    while (!Serial.available()) delay(100);
    Serial.read();
}

void runGlucoseTest() {
    Serial.println("\n🩸 GLUCOSE SENSOR TEST");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    if (!sensors.isGlucoseReady()) {
        Serial.println("❌ Glucose sensor not ready!");
        Serial.println("   Check second MAX30102 connections:");
        Serial.printf("   SDA: GPIO %d, SCL: GPIO %d\n", GLUCOSE_SDA_PIN, GLUCOSE_SCL_PIN);
        Serial.println("   This sensor uses PPG for non-invasive glucose estimation");
        Serial.println("   Press any key to return to menu...");
        while (!Serial.available()) delay(100);
        Serial.read();
        return;
    }
    
    Serial.println("✅ Glucose sensor ready");
    Serial.println("📋 Instructions:");
    Serial.println("   1. Place finger firmly on sensor");
    Serial.println("   2. Keep finger still during measurement");
    Serial.println("   3. Ensure good contact with sensor surface");
    Serial.println();
    Serial.println("⚠️  Note: This is experimental non-invasive glucose monitoring");
    Serial.println("📊 Collecting data for 45 seconds... (press any key to stop early)");
    Serial.println();
    
    unsigned long startTime = millis();
    unsigned long lastReading = 0;
    int readingCount = 0;
    float totalGlucose = 0;
    
    while ((millis() - startTime < 45000) && !Serial.available()) {
        if (millis() - lastReading > 3000) { // Read every 3 seconds
            GlucoseData glucoseData = sensors.getGlucose();
            
            if (glucoseData.validReading) {
                readingCount++;
                totalGlucose += glucoseData.glucoseLevel;
                  Serial.printf("🩸 Reading %d: %.0f mg/dL (%.1f mmol/L) - Quality: %.1f%%\n", 
                             readingCount, glucoseData.glucoseLevel, 
                             glucoseData.glucoseLevel / 18.0, // Convert to mmol/L
                             glucoseData.signalQuality);
                             
                Serial.printf("   IR: %.2f, Red: %.2f, Ratio: %.3f\n", 
                             glucoseData.irValue, glucoseData.redValue, glucoseData.ratio);
                
                // Basic glucose level assessment
                if (glucoseData.glucoseLevel >= 70 && glucoseData.glucoseLevel <= 140) {
                    Serial.println("   📊 Estimated glucose in normal range");
                } else if (glucoseData.glucoseLevel > 140) {
                    Serial.println("   ⚠️  Estimated glucose elevated");
                } else {
                    Serial.println("   ⚠️  Estimated glucose low");
                }
            } else {
                Serial.println("⚠️  No valid reading - check finger placement");
            }
            
            lastReading = millis();
        }
        delay(100);
    }
    
    if (Serial.available()) Serial.read(); // Clear input
    
    Serial.println("\n📊 GLUCOSE TEST RESULTS:");
    if (readingCount > 0) {
        float avgGlucose = totalGlucose / readingCount;
        
        Serial.printf("   Average Glucose: %.0f mg/dL (%.1f mmol/L)\n", 
                     avgGlucose, avgGlucose / 18.0);
        Serial.printf("   Valid Readings: %d/%d\n", readingCount, 15);
        
        // Assessment
        if (avgGlucose >= 70 && avgGlucose <= 140) {
            Serial.println("   ✅ Average glucose in normal range");
        } else {
            Serial.println("   ⚠️  Average glucose outside normal range");
        }
    } else {
        Serial.println("   ❌ No valid readings obtained");
    }
    
    Serial.println("\n⚠️  IMPORTANT DISCLAIMER:");
    Serial.println("   This is experimental technology for research purposes");
    Serial.println("   NOT intended for medical diagnosis or treatment");
    Serial.println("   Always use proper medical glucose meters for health decisions");
    
    Serial.println("\nPress any key to return to menu...");
    while (!Serial.available()) delay(100);
    Serial.read();
}

void runBloodPressureIndividualTest() {
    Serial.println("\n🩺 BLOOD PRESSURE INDIVIDUAL TEST");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    if (!sensors.isBloodPressureReady()) {
        Serial.println("❌ Blood pressure sensors not ready!");
        Serial.println("   Requires both ECG and PPG sensors working");
        Serial.println("   Check all electrode and sensor connections");
        Serial.println("   Press any key to return to menu...");
        while (!Serial.available()) delay(100);
        Serial.read();
        return;
    }
    
    Serial.println("✅ Blood pressure monitoring ready");
    Serial.println("📋 Instructions:");
    Serial.println("   1. Connect ECG electrodes (RA, LA, RL)");
    Serial.println("   2. Place finger on PPG sensor");
    Serial.println("   3. Sit comfortably and breathe normally");
    Serial.println("   4. Avoid movement during measurement");
    Serial.println();
    Serial.println("🔬 This uses Pulse Transit Time (PTT) analysis");
    Serial.println("📊 Measuring for 60 seconds... (press any key to stop early)");
    Serial.println();
    
    unsigned long startTime = millis();
    unsigned long lastReading = 0;
    int readingCount = 0;
    float totalSystolic = 0;
    float totalDiastolic = 0;
    
    while ((millis() - startTime < 60000) && !Serial.available()) {
        if (millis() - lastReading > 10000) { // BP reading every 10 seconds
            BloodPressureData bpData = sensors.getBloodPressure();
            
            if (bpData.validReading) {
                readingCount++;
                totalSystolic += bpData.systolic;
                totalDiastolic += bpData.diastolic;
                
                Serial.printf("🩺 Reading %d: %d/%d mmHg (MAP: %.0f)\n", 
                             readingCount, (int)bpData.systolic, (int)bpData.diastolic, 
                             bpData.meanArterialPressure);
                Serial.printf("   PTT: %.1f ms, PWV: %.2f m/s, Quality: %.0f%%\n", 
                             bpData.pulseTransitTime, bpData.pulseWaveVelocity, bpData.signalQuality);
                
                // BP category
                String category = BPAnalysis::interpretBPReading(bpData.systolic, bpData.diastolic);
                Serial.printf("   Category: %s\n", category.c_str());
                
                if (bpData.needsCalibration) {
                    Serial.println("   ⚠️  Calibration recommended for accuracy");
                }
            } else {
                Serial.println("⚠️  No valid BP reading - check sensor placement");
            }
            
            lastReading = millis();
        }
        
        // Show real-time status every 5 seconds
        static unsigned long lastStatus = 0;
        if (millis() - lastStatus > 5000) {
            Serial.printf("📡 Status: ECG=%s, PPG=%s\n", 
                         sensors.isECGReady() ? "✅" : "❌",
                         sensors.isHeartRateReady() ? "✅" : "❌");
            lastStatus = millis();
        }
        
        delay(100);
    }
    
    if (Serial.available()) Serial.read(); // Clear input
    
    Serial.println("\n📊 BLOOD PRESSURE TEST RESULTS:");
    if (readingCount > 0) {
        float avgSystolic = totalSystolic / readingCount;
        float avgDiastolic = totalDiastolic / readingCount;
        
        Serial.printf("   Average BP: %.0f/%.0f mmHg\n", avgSystolic, avgDiastolic);
        Serial.printf("   Valid Readings: %d\n", readingCount);
        
        // Overall assessment
        String category = BPAnalysis::interpretBPReading(avgSystolic, avgDiastolic);
        Serial.printf("   Average Category: %s\n", category.c_str());
        
        if (avgSystolic < 120 && avgDiastolic < 80) {
            Serial.println("   ✅ Normal blood pressure");
        } else if (avgSystolic >= 140 || avgDiastolic >= 90) {
            Serial.println("   ⚠️  Elevated blood pressure detected");
        } else {
            Serial.println("   📊 Blood pressure elevated but not hypertensive");
        }
    } else {
        Serial.println("   ❌ No valid BP readings obtained");
    }
    
    Serial.println("\n💡 For better accuracy:");
    Serial.println("   - Calibrate with reference BP measurement");
    Serial.println("   - Use 'cal' command in BP test mode");
    Serial.println("   - Ensure stable sensor connections");
    
    Serial.println("\nPress any key to return to menu...");
    while (!Serial.available()) delay(100);
    Serial.read();
}

void runAllSensorsTest() {
    Serial.println("\n🔬 ALL SENSORS COMPREHENSIVE TEST");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Serial.println("📊 Testing all available sensors sequentially...");
    Serial.println("⏱️  This will take approximately 2-3 minutes");
    Serial.println("🔄 Press any key to skip current test and move to next");
    Serial.println();
    
    // Test each sensor one by one
    Serial.println("1️⃣ Starting Heart Rate Test...");
    delay(2000);
    runHeartRateTest();
    
    Serial.println("\n2️⃣ Starting Temperature Test...");
    delay(2000);
    runTemperatureTest();
    
    Serial.println("\n3️⃣ Starting Weight Test...");
    delay(2000);
    runWeightTest();
      Serial.println("\n4️⃣ Starting Bioimpedance Test...");
    delay(2000);
    runBioimpedanceTest();
    
    Serial.println("\n5️⃣ Starting Body Composition Analysis...");
    delay(2000);
    runBodyCompositionTest();
    
    Serial.println("\n6️⃣ Starting ECG Test...");
    delay(2000);
    runECGTest();
    
    Serial.println("\n7️⃣ Starting Glucose Test...");
    delay(2000);
    runGlucoseTest();
    
    Serial.println("\n8️⃣ Starting Blood Pressure Test...");
    delay(2000);
    runBloodPressureIndividualTest();
    
    // Final summary
    Serial.println("\n🏁 ALL SENSORS TEST COMPLETED!");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Serial.println("📋 Final System Status:");
    Serial.printf("   Heart Rate: %s\n", sensors.isHeartRateReady() ? "✅ Ready" : "❌ Not Ready");
    Serial.printf("   Temperature: %s\n", sensors.isTemperatureReady() ? "✅ Ready" : "❌ Not Ready");
    Serial.printf("   Weight: %s\n", sensors.isWeightReady() ? "✅ Ready" : "❌ Not Ready");
    Serial.printf("   Bioimpedance: %s\n", sensors.isBioimpedanceReady() ? "✅ Ready" : "❌ Not Ready");
    Serial.printf("   ECG: %s\n", sensors.isECGReady() ? "✅ Ready" : "❌ Not Ready");
    Serial.printf("   Glucose: %s\n", sensors.isGlucoseReady() ? "✅ Ready" : "❌ Not Ready");
    Serial.printf("   Blood Pressure: %s\n", sensors.isBloodPressureReady() ? "✅ Ready" : "❌ Not Ready");
    
    Serial.println("\n💾 System Information:");
    Serial.printf("   Free Heap: %d bytes\n", ESP.getFreeHeap());
    Serial.printf("   Uptime: %.1f minutes\n", millis() / 60000.0);
    Serial.printf("   CPU Temperature: %.1f°C\n", temperatureRead());
    
    Serial.println("\n✅ Comprehensive testing completed!");
    Serial.println("Press any key to return to menu...");
    while (!Serial.available()) delay(100);
    Serial.read();
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
    } else if (currentMode == INDIVIDUAL_TEST_MODE) {
        Serial.println("🧪 Initializing Individual Test Mode...");
        // Sensors only, no network - similar to debug mode
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
    Serial.println("🚀 Creating FreeRTOS tasks optimized for WROOM-32...");
    
    // Only create tasks for normal mode (test modes run in main loop)
    if (currentMode != NORMAL_MODE) {
        Serial.println("ℹ️ Test mode - using main loop instead of tasks");
        return;
    }
    
    // Check available memory before creating tasks
    uint32_t beforeHeap = ESP.getFreeHeap();
    Serial.printf("📊 Free heap before task creation: %d bytes\n", beforeHeap);
    
    // Sensor reading task (Core 0) - Highest priority for real-time data
    // Reduced stack size for WROOM-32 memory constraints
    xTaskCreatePinnedToCore(
        sensorTask,           // Task function
        "SensorTask",         // Task name
        TASK_STACK_SIZE_LARGE, // Stack size (4096 bytes)
        NULL,                 // Parameters
        3,                    // Priority (highest)
        &sensorTaskHandle,    // Task handle
        0                     // Core number
    );
    
    // Security and network monitoring task (Core 0)
    // Reduced stack size for WROOM-32
    xTaskCreatePinnedToCore(
        securityTask,         // Task function
        "SecurityTask",       // Task name
        TASK_STACK_SIZE_MEDIUM, // Stack size (3072 bytes)
        NULL,                 // Parameters
        2,                    // Priority (high)
        &securityTaskHandle,  // Task handle
        0                     // Core number
    );
    
    // Network communication task (Core 1)
    // Optimized for WROOM-32 memory limits
    xTaskCreatePinnedToCore(
        networkTask,          // Task function
        "NetworkTask",        // Task name
        TASK_STACK_SIZE_LARGE, // Stack size (4096 bytes)
        NULL,                 // Parameters
        2,                    // Priority (high)
        &networkTaskHandle,   // Task handle
        1                     // Core number
    );
    
    // Data processing task (Core 1)
    // Reduced stack size for WROOM-32
    xTaskCreatePinnedToCore(
        dataTask,             // Task function
        "DataTask",           // Task name
        TASK_STACK_SIZE_MEDIUM, // Stack size (3072 bytes)
        NULL,                 // Parameters
        1,                    // Priority (normal)
        &dataTaskHandle,      // Task handle
        1                     // Core number
    );
    
    uint32_t afterHeap = ESP.getFreeHeap();
    uint32_t usedMemory = beforeHeap - afterHeap;
    
    Serial.println("✅ All tasks created successfully");
    Serial.printf("📊 Memory usage for tasks: %d bytes\n", usedMemory);
    Serial.printf("📊 Free heap after task creation: %d bytes\n", afterHeap);
    
    // Warn if memory usage is high for WROOM-32
    if (afterHeap < 100000) {  // Less than 100KB free
        Serial.println("⚠️ Low memory warning for WROOM-32 - consider reducing task stack sizes");
    }
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
    Serial.println("🔧 Validating ESP32 WROOM-32 pin configuration...");
    
    // Check for pin conflicts and WROOM-32 compatibility
    bool hasConflicts = false;
    bool hasInvalidPins = false;
    
    // Validate all sensor pins for WROOM-32 compatibility
    if (!isValidWROOMPin(DS18B20_PIN)) {
        Serial.printf("❌ INVALID PIN: DS18B20 (GPIO %d) not suitable for WROOM-32\n", DS18B20_PIN);
        hasInvalidPins = true;
    }
    
    if (!isValidWROOMPin(MAX30102_SDA_PIN) || !isValidWROOMPin(MAX30102_SCL_PIN)) {
        Serial.printf("❌ INVALID PIN: MAX30102 I2C pins not suitable for WROOM-32\n");
        hasInvalidPins = true;
    }
    
    if (!isValidWROOMPin(GLUCOSE_SDA_PIN) || !isValidWROOMPin(GLUCOSE_SCL_PIN)) {
        Serial.printf("❌ INVALID PIN: Glucose I2C pins not suitable for WROOM-32\n");
        hasInvalidPins = true;
    }
    
    if (!isValidWROOMPin(LOAD_CELL_DOUT_PIN) || !isValidWROOMPin(LOAD_CELL_SCK_PIN)) {
        Serial.printf("❌ INVALID PIN: Load cell pins not suitable for WROOM-32\n");
        hasInvalidPins = true;
    }
    
    // Check for pin conflicts
    if (GLUCOSE_SDA_PIN == LOAD_CELL_DOUT_PIN || GLUCOSE_SCL_PIN == LOAD_CELL_SCK_PIN) {
        Serial.printf("⚠️  PIN CONFLICT: Glucose I2C conflicts with Load Cell pins\n");
        hasConflicts = true;
    }
    
    // Check boot-sensitive pins
    if (BP_PUMP_PIN == 12) {
        Serial.printf("⚠️  BOOT WARNING: GPIO12 (BP_PUMP_PIN) affects flash voltage on boot\n");
    }
    
    // Display WROOM-32 optimized pin assignments
    Serial.println("📍 ESP32 WROOM-32 Pin Assignments:");
    Serial.printf("  DS18B20 Temperature: GPIO %d\n", DS18B20_PIN);
    Serial.printf("  MAX30102 HR I2C: SDA=%d, SCL=%d\n", MAX30102_SDA_PIN, MAX30102_SCL_PIN);
    Serial.printf("  Glucose I2C: SDA=%d, SCL=%d\n", GLUCOSE_SDA_PIN, GLUCOSE_SCL_PIN);
    Serial.printf("  Load Cell: DOUT=%d, SCK=%d\n", LOAD_CELL_DOUT_PIN, LOAD_CELL_SCK_PIN);
    Serial.printf("  AD5941 SPI: CS=%d, MOSI=%d, MISO=%d, SCK=%d\n", 
                  AD5941_CS_PIN, AD5941_MOSI_PIN, AD5941_MISO_PIN, AD5941_SCK_PIN);
    Serial.printf("  ECG: DATA=%d, LO+=%d, LO-=%d\n", ECG_PIN, LO_PLUS_PIN, LO_MINUS_PIN);
    Serial.printf("  Blood Pressure: EN=%d, PUMP=%d\n", BP_ENABLE_PIN, BP_PUMP_PIN);
    
    // Memory information for WROOM-32
    Serial.println("💾 WROOM-32 Memory Info:");
    Serial.printf("  Total heap: %d bytes\n", ESP.getHeapSize());
    Serial.printf("  Free heap: %d bytes\n", ESP.getFreeHeap());
    Serial.printf("  PSRAM: %s\n", psramFound() ? "Found" : "Not available (WROOM-32)");
    
    if (!hasConflicts && !hasInvalidPins) {
        Serial.println("✅ Pin configuration validated - WROOM-32 compatible, no conflicts detected");
    } else {
        if (hasInvalidPins) {
            Serial.println("❌ Invalid pins detected for WROOM-32! Please review pin assignments.");
        }
        if (hasConflicts) {
            Serial.println("❌ Pin conflicts detected! Please review hardware connections.");
        }
    }
 }
 
void runBodyCompositionTest() {
    Serial.println("\n🧬 BODY COMPOSITION ANALYSIS TEST");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    if (!sensors.isBioimpedanceReady()) {
        Serial.println("❌ Bioimpedance sensor not ready!");
        Serial.println("   Body composition analysis requires AD5941 BIA sensor");
        Serial.println("   Check sensor connections and initialization");
        Serial.println("   Press any key to return to menu...");
        while (!Serial.available()) delay(100);
        Serial.read();
        return;
    }
    
    Serial.println("✅ BIA sensor ready for body composition analysis");
    Serial.println();
    Serial.println("📋 SETUP INSTRUCTIONS:");
    Serial.println("   1. Remove shoes and socks");
    Serial.println("   2. Clean electrode contact points with alcohol");
    Serial.println("   3. Attach electrodes to hands and feet");
    Serial.println("   4. Lie down and relax for 5 minutes before measurement");
    Serial.println("   5. Stay completely still during analysis");
    Serial.println();
    
    // User profile setup
    Serial.println("👤 USER PROFILE REQUIRED FOR ACCURATE ANALYSIS");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    // Get user profile information
    Serial.print("Enter age (18-100): ");
    while (!Serial.available()) delay(100);
    int age = Serial.parseInt();
    Serial.println(age);
    
    Serial.print("Enter height in cm (120-220): ");
    while (!Serial.available()) delay(100);
    float height = Serial.parseFloat();
    Serial.println(height);
    
    Serial.print("Enter weight in kg (30-200): ");
    while (!Serial.available()) delay(100);
    float weight = Serial.parseFloat();
    Serial.println(weight);
    
    Serial.print("Enter gender (M/F): ");
    while (!Serial.available()) delay(100);
    String gender = Serial.readString();
    gender.trim();
    gender.toUpperCase();
    bool isMale = (gender == "M");
    Serial.println(gender);
    
    Serial.print("Activity level (1=Sedentary, 2=Light, 3=Moderate, 4=Active, 5=Athlete): ");
    while (!Serial.available()) delay(100);
    int activityLevel = Serial.parseInt();
    Serial.println(activityLevel);
    
    Serial.print("Are you a professional athlete? (Y/N): ");
    while (!Serial.available()) delay(100);
    String athleteStr = Serial.readString();
    athleteStr.trim();
    athleteStr.toUpperCase();
    bool isAthlete = (athleteStr == "Y");
    Serial.println(athleteStr);
    
    // Set up body composition profile
    UserProfile profile;
    profile.age = age;
    profile.height = height;
    profile.weight = weight;
    profile.isMale = isMale;
    profile.activityLevel = activityLevel;
    profile.isAthlete = isAthlete;
    
    sensors.setBodyCompositionProfile(profile);
    
    Serial.println();
    Serial.println("🔬 PERFORMING BODY COMPOSITION ANALYSIS");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Serial.println("📊 This analysis performs multi-frequency bioimpedance sweep");
    Serial.println("⏱️  Analysis will take approximately 30-60 seconds");
    Serial.println("🤫 Please remain completely still and quiet");
    Serial.println();
    Serial.println("Press ENTER when ready to begin analysis...");
    
    while (Serial.read() != '\n' && Serial.read() != '\r') delay(100);
    
    Serial.println("🔄 Starting body composition analysis...");
    
    // Perform body composition analysis
    BodyComposition result = sensors.getBodyComposition(weight);
    
    Serial.println();
    Serial.println("📊 BODY COMPOSITION ANALYSIS RESULTS");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    if (result.validReading) {
        Serial.println("✅ Analysis completed successfully!");
        Serial.printf("📈 Measurement Quality: %.1f%%\n", result.measurementQuality);
        Serial.println();
        
        Serial.println("🧬 BODY COMPOSITION BREAKDOWN:");
        Serial.printf("   Body Fat:           %.1f%% (%.1f kg)\n", result.bodyFatPercentage, result.fatMassKg);
        Serial.printf("   Muscle Mass:        %.1f kg (%.1f%%)\n", result.muscleMassKg, result.muscleMassPercentage);
        Serial.printf("   Body Water:         %.1f%%\n", result.bodyWaterPercentage);
        Serial.printf("   Bone Mass:          %.1f kg\n", result.boneMassKg);
        Serial.printf("   Fat-Free Mass:      %.1f kg\n", result.fatFreeMass);
        Serial.println();
        
        Serial.println("📊 METABOLIC METRICS:");
        Serial.printf("   BMR:                %.0f kcal/day\n", result.BMR);
        Serial.printf("   Metabolic Age:      %.1f years\n", result.metabolicAge);
        Serial.printf("   Visceral Fat Level: %.1f (1-59 scale)\n", result.visceralFatLevel);
        Serial.println();
        
        Serial.println("🔬 TECHNICAL DATA:");
        Serial.printf("   Phase Angle:        %.1f°\n", result.phaseAngle);
        Serial.printf("   Impedance @50kHz:   %.1f Ω\n", result.impedance50kHz);
        Serial.printf("   Resistance @50kHz:  %.1f Ω\n", result.resistance50kHz);
        Serial.printf("   Reactance @50kHz:   %.1f Ω\n", result.reactance50kHz);
        Serial.println();
        
        // Health assessment
        Serial.println("🏥 HEALTH ASSESSMENT:");
        if (result.bodyFatPercentage >= 3 && result.bodyFatPercentage <= (isMale ? 25 : 32)) {
            Serial.println("   ✅ Body fat percentage within healthy range");
        } else if (result.bodyFatPercentage > (isMale ? 25 : 32)) {
            Serial.println("   ⚠️  Body fat percentage above recommended range");
        } else {
            Serial.println("   ⚠️  Body fat percentage below recommended range");
        }
        
        if (result.visceralFatLevel <= 12) {
            Serial.println("   ✅ Visceral fat level healthy");
        } else if (result.visceralFatLevel <= 15) {
            Serial.println("   ⚠️  Visceral fat level elevated - consider lifestyle changes");
        } else {
            Serial.println("   ❌ Visceral fat level high - consult healthcare provider");
        }
        
        if (result.phaseAngle >= 5.0) {
            Serial.println("   ✅ Phase angle indicates good cellular health");
        } else {
            Serial.println("   ⚠️  Phase angle suggests reduced cellular integrity");
        }
        
        Serial.println();
        Serial.println("💡 RECOMMENDATIONS:");
        if (result.bodyFatPercentage > (isMale ? 20 : 28)) {
            Serial.println("   • Consider increasing cardiovascular exercise");
            Serial.println("   • Focus on caloric deficit for fat loss");
        }
        if (result.muscleMassPercentage < (isMale ? 35 : 28)) {
            Serial.println("   • Include resistance training in workout routine");
            Serial.println("   • Ensure adequate protein intake (1.6-2.2g/kg body weight)");
        }
        if (result.bodyWaterPercentage < (isMale ? 60 : 55)) {
            Serial.println("   • Increase daily water intake");
            Serial.println("   • Monitor hydration status regularly");
        }
        
    } else {
        Serial.println("❌ Analysis failed or low quality measurement");
        Serial.printf("📉 Measurement Quality: %.1f%%\n", result.measurementQuality);
        Serial.println();
        Serial.println("🔧 TROUBLESHOOTING:");
        Serial.println("   • Check electrode connections and contact");
        Serial.println("   • Ensure electrodes are clean and properly positioned");
        Serial.println("   • Verify user is lying down and completely still");
        Serial.println("   • Wait 5 minutes after physical activity before measuring");
        Serial.println("   • Ensure proper hydration (not dehydrated or over-hydrated)");
    }
    
    Serial.println();
    Serial.println("⚠️  IMPORTANT DISCLAIMERS:");
    Serial.println("   • This analysis is for educational and research purposes");
    Serial.println("   • Results should not replace professional medical assessment");
    Serial.println("   • Accuracy may vary based on hydration, temperature, and other factors");
    Serial.println("   • Consult healthcare providers for medical decisions");
    
    Serial.println("\nPress any key to return to menu...");
    while (!Serial.available()) delay(100);
    Serial.read();
}
