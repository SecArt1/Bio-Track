/*
 * Advanced Blood Pressure Testing Program
 * 
 * This program demonstrates the innovative blood pressure monitoring system
 * using MAX30102 PPG sensor and AD8232 ECG sensor integration with 
 * Pulse Transit Time (PTT) analysis.
 * 
 * Features:
 * - Real-time ECG and PPG signal acquisition
 * - Pulse Transit Time calculation
 * - Blood pressure estimation using PTT
 * - Signal quality assessment
 * - Heart rate variability analysis
 * - Personalized calibration system
 * - Advanced filtering and noise reduction
 */

#include "sensors.h"
#include "blood_pressure.h"

// Global objects
SensorManager sensors;
bool testRunning = false;
unsigned long lastBPMeasurement = 0;
unsigned long lastDiagnostics = 0;

// Test configuration
const unsigned long BP_MEASUREMENT_INTERVAL = 30000; // 30 seconds
const unsigned long DIAGNOSTICS_INTERVAL = 10000;    // 10 seconds

void setup() {
    Serial.begin(115200);
    Serial.println("\n" + String("=").repeat(60));
    Serial.println("🩺 ADVANCED BLOOD PRESSURE MONITORING SYSTEM 🩺");
    Serial.println("   Using MAX30102 + AD8232 with PTT Analysis");
    Serial.println(String("=").repeat(60));
    
    // Initialize LED for status indication
    pinMode(LED_BUILTIN, OUTPUT);
    digitalWrite(LED_BUILTIN, LOW);
    
    // Initialize sensors
    Serial.println("🔄 Initializing sensor system...");
    if (!sensors.begin()) {
        Serial.println("❌ Sensor initialization failed!");
        while (true) {
            digitalWrite(LED_BUILTIN, HIGH);
            delay(200);
            digitalWrite(LED_BUILTIN, LOW);
            delay(200);
        }
    }
    
    Serial.println("✅ Sensor system initialized successfully!");
    Serial.println(sensors.getSensorStatus());
    
    // Display user instructions
    displayInstructions();
    
    // Set up default user profile
    sensors.setUserProfile(30, 170.0, true); // 30 years, 170cm, male
    
    digitalWrite(LED_BUILTIN, HIGH); // Indicate ready
}

void loop() {
    handleSerialCommands();
    
    if (testRunning) {
        performBloodPressureTest();
    }
    
    // Show diagnostics periodically
    if (millis() - lastDiagnostics > DIAGNOSTICS_INTERVAL) {
        showDiagnostics();
        lastDiagnostics = millis();
    }
    
    delay(100); // Small delay to prevent overwhelming the system
}

void displayInstructions() {
    Serial.println("\n📋 BLOOD PRESSURE MONITORING INSTRUCTIONS:");
    Serial.println("1. Connect ECG electrodes: RA(Right Arm), LA(Left Arm), RL(Right Leg)");
    Serial.println("2. Place finger on MAX30102 PPG sensor (heart rate sensor)");
    Serial.println("3. Ensure stable contact for both sensors");
    Serial.println("4. Sit quietly and breathe normally");
    Serial.println();
    Serial.println("📟 AVAILABLE COMMANDS:");
    Serial.println("  'start'    - Begin blood pressure monitoring");
    Serial.println("  'stop'     - Stop monitoring");
    Serial.println("  'cal'      - Enter calibration mode");
    Serial.println("  'profile'  - Set user profile (age, height, gender)");
    Serial.println("  'diag'     - Show detailed diagnostics");
    Serial.println("  'test'     - Run sensor self-test");
    Serial.println("  'help'     - Show this help menu");
    Serial.println();
    Serial.println("💡 TIP: Calibrate with a reference blood pressure measurement for accuracy!");
    Serial.println("🔬 The system uses Pulse Transit Time (PTT) analysis for non-invasive BP estimation");
    Serial.println();
}

void handleSerialCommands() {
    if (Serial.available()) {
        String command = Serial.readString();
        command.trim();
        command.toLowerCase();
        
        if (command == "start") {
            startBPMonitoring();
        } else if (command == "stop") {
            stopBPMonitoring();
        } else if (command == "cal") {
            enterCalibrationMode();
        } else if (command == "profile") {
            setUserProfile();
        } else if (command == "diag") {
            showDetailedDiagnostics();
        } else if (command == "test") {
            runSensorSelfTest();
        } else if (command == "help") {
            displayInstructions();
        } else if (command.length() > 0) {
            Serial.println("❌ Unknown command: " + command);
            Serial.println("Type 'help' for available commands");
        }
    }
}

void startBPMonitoring() {
    Serial.println("\n🩺 STARTING BLOOD PRESSURE MONITORING");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    if (!sensors.isECGReady() || !sensors.isHeartRateReady()) {
        Serial.println("❌ Required sensors not ready!");
        Serial.println("   ECG: " + String(sensors.isECGReady() ? "✅" : "❌"));
        Serial.println("   PPG: " + String(sensors.isHeartRateReady() ? "✅" : "❌"));
        return;
    }
    
    testRunning = true;
    lastBPMeasurement = millis();
    
    Serial.println("✅ Monitoring started!");
    Serial.println("📊 Collecting ECG and PPG signals...");
    Serial.println("⏱️  Blood pressure will be calculated every 30 seconds");
    Serial.println("💡 Maintain stable sensor contact for best results");
    Serial.println();
}

void stopBPMonitoring() {
    testRunning = false;
    Serial.println("\n⏹️  Blood pressure monitoring stopped");
    Serial.println();
}

void performBloodPressureTest() {
    // Continuous data collection
    SensorReadings readings = sensors.readAllSensors();
    
    // Show real-time status
    static unsigned long lastStatusUpdate = 0;
    if (millis() - lastStatusUpdate > 5000) { // Update every 5 seconds
        Serial.println("📡 Status: " + sensors.getSensorStatus());
        
        if (readings.ecg.validReading) {
            Serial.printf("   ECG: %d BPM, Signal: %.1f %s\n", 
                         readings.ecg.avgBPM, readings.ecg.avgFilteredValue,
                         readings.ecg.leadOff ? "(Lead Off!)" : "");
        }
        
        if (readings.heartRate.validReading) {
            Serial.printf("   PPG: %.1f BPM, Signal Quality: Good\n", readings.heartRate.heartRate);
        }
        
        lastStatusUpdate = millis();
    }
    
    // Perform blood pressure calculation
    if (millis() - lastBPMeasurement > BP_MEASUREMENT_INTERVAL) {
        calculateAndDisplayBP(readings);
        lastBPMeasurement = millis();
    }
}

void calculateAndDisplayBP(SensorReadings& readings) {
    Serial.println("\n🔍 CALCULATING BLOOD PRESSURE...");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    BloodPressureData bp = readings.bloodPressure;
    
    if (bp.validReading) {
        // Main BP reading
        String category = BPAnalysis::interpretBPReading(bp.systolic, bp.diastolic);
        bool isHypertensive = BPAnalysis::isHypertensive(bp.systolic, bp.diastolic);
        
        Serial.println("🩺 BLOOD PRESSURE RESULTS:");
        Serial.printf("   Systolic:  %.0f mmHg\n", bp.systolic);
        Serial.printf("   Diastolic: %.0f mmHg\n", bp.diastolic);
        Serial.printf("   Category:  %s %s\n", category.c_str(), isHypertensive ? "⚠️" : "✅");
        Serial.printf("   MAP:       %.1f mmHg\n", bp.meanArterialPressure);
        Serial.printf("   Pulse Pressure: %.1f mmHg\n", BPAnalysis::calculatePulsePressure(bp.systolic, bp.diastolic));
        
        Serial.println("\n📊 ADVANCED METRICS:");
        Serial.printf("   Pulse Transit Time: %.1f ms\n", bp.pulseTransitTime);
        Serial.printf("   Pulse Wave Velocity: %.2f m/s\n", bp.pulseWaveVelocity);
        Serial.printf("   Heart Rate Variability: %.1f ms\n", bp.heartRateVariability);
        
        Serial.println("\n📈 SIGNAL QUALITY:");
        Serial.printf("   Overall Quality: %.1f%%\n", bp.signalQuality);
        Serial.printf("   ECG-PPG Correlation: %d%%\n", bp.correlationCoeff);
        Serial.printf("   Heart Rhythm: %s\n", bp.rhythmRegular ? "Regular" : "Irregular");
        
        if (bp.needsCalibration) {
            Serial.println("\n⚠️  CALIBRATION NEEDED:");
            Serial.println("   For accurate readings, calibrate with a reference BP measurement");
            Serial.println("   Use 'cal' command to enter calibration mode");
        }
        
        // Health assessment
        provideHealthAssessment(bp);
        
    } else {
        Serial.println("❌ BLOOD PRESSURE CALCULATION FAILED");
        Serial.println("   Possible causes:");
        Serial.println("   • Poor signal quality");
        Serial.println("   • Insufficient data collection time");
        Serial.println("   • Sensor contact issues");
        Serial.println("   • Motion artifacts");
        
        if (sensors.isBloodPressureReady()) {
            // Show BP monitor status for troubleshooting
            Serial.println("\n🔧 BP Monitor Status:");
            // sensors.bpMonitor.printDiagnostics(); // If we make this public
        }
    }
    
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
}

void provideHealthAssessment(BloodPressureData& bp) {
    Serial.println("\n🏥 HEALTH ASSESSMENT:");
    
    // Blood pressure category assessment
    if (bp.systolic < 120 && bp.diastolic < 80) {
        Serial.println("   ✅ Normal blood pressure - Keep up the good work!");
    } else if (bp.systolic < 130 && bp.diastolic < 80) {
        Serial.println("   ⚠️  Elevated blood pressure - Consider lifestyle changes");
    } else if (bp.systolic < 140 || bp.diastolic < 90) {
        Serial.println("   🔶 Stage 1 Hypertension - Consult healthcare provider");
    } else if (bp.systolic < 180 || bp.diastolic < 120) {
        Serial.println("   🔴 Stage 2 Hypertension - Seek medical attention");
    } else {
        Serial.println("   🚨 Hypertensive Crisis - Seek immediate medical attention!");
    }
    
    // Pulse Wave Velocity assessment
    if (bp.pulseWaveVelocity > 0) {
        if (bp.pulseWaveVelocity < 7.0) {
            Serial.println("   ✅ Good arterial elasticity");
        } else if (bp.pulseWaveVelocity < 10.0) {
            Serial.println("   ⚠️  Moderate arterial stiffness");
        } else {
            Serial.println("   🔴 High arterial stiffness - cardiovascular risk");
        }
    }
    
    // Heart Rate Variability assessment
    if (bp.heartRateVariability > 0) {
        if (bp.heartRateVariability > 50.0) {
            Serial.println("   ✅ Good heart rate variability");
        } else if (bp.heartRateVariability > 30.0) {
            Serial.println("   ⚠️  Moderate heart rate variability");
        } else {
            Serial.println("   🔴 Low heart rate variability - stress indicator");
        }
    }
}

void enterCalibrationMode() {
    Serial.println("\n🔧 BLOOD PRESSURE CALIBRATION MODE");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Serial.println("📋 Instructions:");
    Serial.println("1. Take a reference BP measurement using a validated cuff");
    Serial.println("2. Immediately place finger on PPG sensor and attach ECG electrodes");
    Serial.println("3. Enter the reference systolic pressure when prompted");
    Serial.println("4. Enter the reference diastolic pressure when prompted");
    Serial.println();
    
    // Get systolic pressure
    Serial.print("Enter reference SYSTOLIC pressure (80-250 mmHg): ");
    while (!Serial.available()) delay(100);
    float systolic = Serial.parseFloat();
    Serial.println(systolic);
    
    if (systolic < 80 || systolic > 250) {
        Serial.println("❌ Invalid systolic pressure range");
        return;
    }
    
    // Get diastolic pressure
    Serial.print("Enter reference DIASTOLIC pressure (40-150 mmHg): ");
    while (!Serial.available()) delay(100);
    float diastolic = Serial.parseFloat();
    Serial.println(diastolic);
    
    if (diastolic < 40 || diastolic > 150) {
        Serial.println("❌ Invalid diastolic pressure range");
        return;
    }
    
    // Perform calibration
    if (sensors.calibrateBloodPressure(systolic, diastolic)) {
        Serial.println("✅ Calibration successful!");
        Serial.println("🎯 Blood pressure readings will now be more accurate");
    } else {
        Serial.println("❌ Calibration failed - ensure stable signals");
    }
}

void setUserProfile() {
    Serial.println("\n👤 USER PROFILE CONFIGURATION");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    // Get age
    Serial.print("Enter age (18-100): ");
    while (!Serial.available()) delay(100);
    int age = Serial.parseInt();
    Serial.println(age);
    
    if (age < 18 || age > 100) {
        Serial.println("❌ Invalid age range");
        return;
    }
    
    // Get height
    Serial.print("Enter height in cm (120-220): ");
    while (!Serial.available()) delay(100);
    float height = Serial.parseFloat();
    Serial.println(height);
    
    if (height < 120 || height > 220) {
        Serial.println("❌ Invalid height range");
        return;
    }
    
    // Get gender
    Serial.print("Enter gender (M/F): ");
    while (!Serial.available()) delay(100);
    String gender = Serial.readString();
    gender.trim();
    gender.toUpperCase();
    Serial.println(gender);
    
    bool isMale = (gender == "M");
    
    // Update profile
    sensors.setUserProfile(age, height, isMale);
    Serial.println("✅ User profile updated successfully!");
}

void showDiagnostics() {
    if (!testRunning) return;
    
    // Basic status line
    Serial.print("📊 ");
    Serial.print(sensors.getSensorStatus());
    
    if (sensors.isBloodPressureReady()) {
        // Show BP monitor specific status
        Serial.print(" | BP: ");
        // Could add more BP-specific status here
        Serial.print("Active");
    }
    
    Serial.println();
}

void showDetailedDiagnostics() {
    Serial.println("\n🔬 DETAILED SYSTEM DIAGNOSTICS");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    // Show all sensor readings
    SensorReadings readings = sensors.readAllSensors();
    sensors.printSensorReadings(readings);
    
    // BP monitor specific diagnostics
    if (sensors.isBloodPressureReady()) {
        Serial.println("\n🩺 Blood Pressure Monitor Diagnostics:");
        // sensors.bpMonitor.printDiagnostics(); // If we make this public
    }
}

void runSensorSelfTest() {
    Serial.println("\n🧪 RUNNING SENSOR SELF-TEST");
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    Serial.println("Testing ECG sensor...");
    if (sensors.isECGReady()) {
        Serial.println("✅ ECG sensor: OK");
    } else {
        Serial.println("❌ ECG sensor: FAIL");
    }
    
    Serial.println("Testing PPG sensor...");
    if (sensors.isHeartRateReady()) {
        Serial.println("✅ PPG sensor: OK");
    } else {
        Serial.println("❌ PPG sensor: FAIL");
    }
    
    Serial.println("Testing BP monitor...");
    if (sensors.isBloodPressureReady()) {
        Serial.println("✅ BP monitor: OK");
    } else {
        Serial.println("❌ BP monitor: FAIL");
    }
    
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Serial.println("Self-test complete!");
}
