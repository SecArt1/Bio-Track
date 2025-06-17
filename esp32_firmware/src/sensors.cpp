#include "sensors.h"

SensorManager::SensorManager() : oneWire(DS18B20_PIN), temperatureSensor(&oneWire), loadCell(WEIGHT_SENSOR_DOUT, WEIGHT_SENSOR_SCK) {
    // Constructor - Initialize ECG buffer
    for (int i = 0; i < ECG_FILTER_SIZE; i++) {
        ecgBuffer[i] = 0;
    }
    ecgBufferIndex = 0;
    lastPeakTime = 0;
    currentBPM = 0;
    
    // Initialize calibration values
    temperatureOffset = 5.0;  // Default +5°C offset as specified in user code
    
    // Initialize glucose monitoring buffers
    for (int i = 0; i < GLUCOSE_WINDOW_SIZE; i++) {
        glucoseIrReadings[i] = 0;
        glucoseRedReadings[i] = 0;
    }
    glucoseReadIndex = 0;
    glucoseLastReading = 0;
}

bool SensorManager::begin() {
    Serial.println("🔄 Initializing sensors...");
    Serial.println("⚠️ WEIGHT-ONLY MODE: Only weight sensor will be initialized");
    
    bool success = true;
    
    // Skip I2C initialization to avoid MAX30102 issues
    // Wire.begin(MAX30102_SDA_PIN, MAX30102_SCL_PIN);
    
    // Skip heart rate sensor to prevent Error 263
    // if (initializeHeartRateSensor()) {
    //     Serial.println("✅ Heart rate sensor initialized");
    //     heartRateInitialized = true;
    // } else {
    //     Serial.println("❌ Heart rate sensor failed");
    //     success = false;
    // }
    Serial.println("⚠️ Heart rate sensor skipped (weight-only mode)");
    
    // Skip temperature sensor for now
    // if (initializeTemperatureSensor()) {
    //     Serial.println("✅ Temperature sensor initialized");
    //     temperatureInitialized = true;
    // } else {
    //     Serial.println("❌ Temperature sensor failed");
    //     success = false;
    // }
    Serial.println("⚠️ Temperature sensor skipped (weight-only mode)");
    
    // Initialize weight sensor ONLY
    if (initializeWeightSensor()) {
        Serial.println("✅ Weight sensor initialized");
        weightInitialized = true;
    } else {
        Serial.println("❌ Weight sensor failed");
        success = false;
    }    
    // Skip bioimpedance sensor
    // if (initializeBioimpedanceSensor()) {
    //     Serial.println("✅ Bioimpedance sensor initialized");
    //     bioimpedanceInitialized = true;
    // } else {
    //     Serial.println("⚠️ Bioimpedance sensor failed (optional)");
    //     // Don't fail initialization for bioimpedance
    // }
    Serial.println("⚠️ Bioimpedance sensor skipped (weight-only mode)");
    
    // Skip ECG sensor
    // if (initializeECGSensor()) {
    //     Serial.println("✅ ECG sensor initialized");
    //     ecgInitialized = true;
    // } else {
    //     Serial.println("⚠️ ECG sensor failed (optional)");
    //     // Don't fail initialization for ECG
    // }
    Serial.println("⚠️ ECG sensor skipped (weight-only mode)");
    
    // Skip glucose sensor
    // if (initializeGlucoseSensor()) {
    //     Serial.println("✅ Glucose sensor initialized");
    //     glucoseInitialized = true;
    // } else {
    //     Serial.println("⚠️ Glucose sensor failed (optional)");
    //     // Don't fail initialization for glucose
    // }
    Serial.println("⚠️ Glucose sensor skipped (weight-only mode)");
    
    // Skip blood pressure monitor
    // if (initializeBloodPressureMonitor()) {
    //     Serial.println("✅ Blood pressure monitor initialized");
    //     bpMonitorInitialized = true;
    // } else {
    //     Serial.println("⚠️ Blood pressure monitor failed (optional)");
    //     // Don't fail initialization for BP monitor
    // }    Serial.println("⚠️ Blood pressure monitor skipped (weight-only mode)");
    
    Serial.println("✅ WEIGHT-ONLY MODE: Sensor initialization completed");
    return success; // Will only be false if weight sensor fails
}

bool SensorManager::initializeHeartRateSensor() {
    Serial.println("🔄 Initializing MAX30102 heart rate sensor...");
    
    // Enable internal pull-up resistors for I2C pins (temporary fix)
    pinMode(MAX30102_SDA_PIN, INPUT_PULLUP);
    pinMode(MAX30102_SCL_PIN, INPUT_PULLUP);
    delay(100); // Allow pins to stabilize
    
    if (!heartRateSensor.begin()) {
        return false;
    }
    
    // Configure sensor settings
    heartRateSensor.setup();
    heartRateSensor.setPulseAmplitudeRed(0x0A);  // Turn Red LED to low to indicate sensor is running
    heartRateSensor.setPulseAmplitudeGreen(0);   // Turn off Green LED
    
    return true;
}

bool SensorManager::initializeTemperatureSensor() {
    Serial.println("🌡️ Initializing DS18B20 temperature sensor...");
    
    // Start communication with the DS18B20 sensor
    temperatureSensor.begin();
    
    // Check if sensor is connected
    int deviceCount = temperatureSensor.getDeviceCount();
    if (deviceCount == 0) {
        Serial.println("❌ No DS18B20 sensors found");
        return false;
    }
    
    Serial.printf("✅ Found %d DS18B20 sensor(s)\n", deviceCount);
    
    // Set resolution to 12-bit for maximum precision (0.0625°C resolution)
    temperatureSensor.setResolution(12);
    
    // Set wait for conversion to false for non-blocking operation
    temperatureSensor.setWaitForConversion(false);
    
    Serial.println("✅ DS18B20 temperature sensor initialized successfully");
    return true;
}

bool SensorManager::initializeWeightSensor() {
    Serial.println("🔄 Initializing HX711_ADC weight sensor...");
    
    // Initialize EEPROM for ESP32
    EEPROM.begin(512);
    
    // Load calibration value from EEPROM
    float calValue;
    EEPROM.get(WEIGHT_EEPROM_ADDRESS, calValue);
    if (calValue == 0xFFFFFFFF || calValue == 0.0) {
        calValue = LOAD_CELL_CALIBRATION_FACTOR; // Use default from config.h
        Serial.printf("Using default calibration factor: %.2f\n", calValue);
    } else {
        Serial.printf("Loaded calibration factor from EEPROM: %.2f\n", calValue);
    }
    
    // Initialize HX711_ADC with existing pins
    loadCell.begin();
    
    unsigned long stabilizingtime = 2000; // Stabilizing time
    boolean tare = true; // Set to true to perform tare
    
    loadCell.start(stabilizingtime, tare);
    
    if (loadCell.getTareTimeoutFlag() || loadCell.getSignalTimeoutFlag()) {
        Serial.println("❌ HX711 timeout - check wiring and pin designations");
        Serial.printf("Expected pins: DOUT=%d, SCK=%d\n", WEIGHT_SENSOR_DOUT, WEIGHT_SENSOR_SCK);
        return false;
    }
    
    loadCell.setCalFactor(calValue); // Set calibration factor
    Serial.println("✅ Weight sensor initialized with HX711_ADC");
    
    return true;
}

bool SensorManager::initializeBioimpedanceSensor() {
    Serial.println("🔄 Initializing AD5940 BIA sensor...");
    
    if (!biaApp.initialize(AD5941_CS_PIN, AD5941_RESET_PIN, AD5941_INT_PIN)) {
        Serial.println("❌ Failed to initialize AD5940");
        return false;
    }
    
    // Configure BIA measurement
    BIAConfig config;
    config.StartFreq = 1000.0f;      // 1 kHz
    config.EndFreq = 100000.0f;      // 100 kHz
    config.NumOfPoints = 10;         // 10 frequency points for fast measurement
    config.ExcitVolt = 200.0f;       // 200mV excitation
    config.SweepEnable = false;      // Single frequency for regular readings
    
    if (!biaApp.configure(config)) {
        Serial.println("❌ Failed to configure BIA");
        return false;
    }
    
    // Perform self-test
    if (!biaApp.selfTest()) {
        Serial.println("⚠️ BIA self-test failed");
        return false;
    }
      Serial.println("✅ AD5940 BIA sensor initialized");
    return true;
}

bool SensorManager::initializeECGSensor() {
    Serial.println("🔄 Initializing AD8232 ECG sensor...");
    
    // Configure ECG pins
    pinMode(LO_PLUS_PIN, INPUT);
    pinMode(LO_MINUS_PIN, INPUT);
    pinMode(ECG_PIN, INPUT);
    
    // Initialize the filter buffer
    for (int i = 0; i < ECG_FILTER_SIZE; i++) {
        ecgBuffer[i] = 0;
    }
    ecgBufferIndex = 0;
    lastPeakTime = 0;
    currentBPM = 0;
    
    // Test ADC reading
    int testReading = analogRead(ECG_PIN);
    if (testReading == 0) {
        Serial.println("⚠️ ECG ADC might not be working");
        return false;
    }
      Serial.println("✅ AD8232 ECG sensor initialized");
    return true;
}

bool SensorManager::initializeGlucoseSensor() {
    Serial.println("🔄 Initializing MAX30102 for glucose estimation mode...");
    
    // Enable internal pull-up resistors for I2C pins (backup if external pull-ups missing)
    pinMode(MAX30102_SDA_PIN, INPUT_PULLUP);
    pinMode(MAX30102_SCL_PIN, INPUT_PULLUP);
    delay(100); // Allow pins to stabilize
    
    // Use the same I2C bus as heart rate sensor - single MAX30102 approach
    // No need for Wire1.begin() - already initialized in heart rate sensor init
    
    if (!glucoseSensor.begin(Wire, I2C_SPEED_FAST)) {
        Serial.println("❌ Cannot initialize MAX30102 in glucose mode");
        Serial.println("   Ensure heart rate sensor is properly initialized first");
        return false;
    }
    
    // Configure for glucose estimation mode - different settings than HR/SpO2
    glucoseSensor.setup();
    glucoseSensor.setPulseAmplitudeRed(0x0A);  // Low power for glucose monitoring
    glucoseSensor.setPulseAmplitudeIR(0x0A);   // Low power for glucose monitoring
    
    // Initialize glucose monitoring arrays
    for (int i = 0; i < GLUCOSE_WINDOW_SIZE; i++) {
        glucoseIrReadings[i] = 0;
        glucoseRedReadings[i] = 0;
    }
    glucoseReadIndex = 0;
    glucoseMaxIR = 0;
    glucoseMinIR = UINT32_MAX;
    glucoseMaxRed = 0;
    glucoseMinRed = UINT32_MAX;
    glucoseLastReading = 0;
    
    Serial.println("✅ MAX30102 Glucose sensor initialized");
    return true;
}

bool SensorManager::initializeBloodPressureMonitor() {
    Serial.println("🔄 Initializing Blood Pressure Monitor...");
    
    if (!bpMonitor.begin()) {
        Serial.println("❌ Failed to initialize BP monitor");
        return false;
    }
    
    // Set default user profile (can be updated later)
    bpMonitor.setPersonalParameters(30, 170.0, true);
    
    Serial.println("✅ Blood Pressure Monitor initialized");
    Serial.println("📋 Requires calibration with reference BP measurements");
    return true;
}

SensorReadings SensorManager::readAllSensors() {
    SensorReadings readings;
    readings.systemTimestamp = millis();
    
    // Read all sensors
    readings.heartRate = readHeartRateAndSpO2();
    readings.temperature = readTemperature();
    readings.weight = readWeight();
    readings.bioimpedance = readBioimpedance();
    readings.ecg = readECG();
    readings.glucose = readGlucose();
    readings.bloodPressure = readBloodPressure();  // Add BP reading
    
    // Perform body composition analysis if bioimpedance and weight are available
    if (readings.bioimpedance.validReading) {
        float weight = readings.weight.validReading ? readings.weight.weight : 0;
        readings.bodyComposition = getBodyComposition(weight);
    } else {
        // Initialize empty body composition data
        readings.bodyComposition = {};
        readings.bodyComposition.timestamp = millis();
        readings.bodyComposition.validReading = false;
    }
    
    return readings;
}

HeartRateData SensorManager::readHeartRateAndSpO2() {
    HeartRateData data = {0, 0, false, millis()};
    
    if (!heartRateInitialized) {
        return data;
    }

    // Collect fresh samples
    long irValue = 0;
    long redValue = 0;
    int samples = 0;
    
    for (int i = 0; i < 50; i++) {
        while (!heartRateSensor.available()) {
            heartRateSensor.check();
        }
        
        uint32_t ir = heartRateSensor.getIR();
        uint32_t red = heartRateSensor.getRed();
        
        // Feed data to blood pressure monitor for PPG analysis
        if (bpMonitorInitialized) {
            bpMonitor.addPPGSample(ir, red, millis());
        }
        
        redValue += red;
        irValue += ir;
        samples++;
        heartRateSensor.nextSample();
        delay(10);
    }
    
    if (samples > 0) {
        irValue /= samples;
        redValue /= samples;
        
        // Simple peak detection for heart rate (placeholder algorithm)        // In production, use proper heart rate calculation algorithms
        if (irValue > 50000) { // Finger detected
            data.heartRate = 75 + random(-15, 15); // Simulated reading
            data.spO2 = 98 + random(-3, 2);        // Simulated SpO2
            data.validReading = validateHeartRateReading(data.heartRate, data.spO2);
        }
    }
    
    return data;
}

TemperatureData SensorManager::readTemperature() {
    TemperatureData data = {0, false, millis()};
    
    if (!temperatureInitialized) {
        Serial.println("⚠️ Temperature sensor not initialized");
        return data;
    }
    
    // Request temperature reading from the DS18B20 sensor
    temperatureSensor.requestTemperatures();
    
    // Small delay to allow conversion to complete (can be removed if using async mode)
    delay(100);
    
    // Get the temperature in Celsius (index 0 for first sensor)
    float temperatureC = temperatureSensor.getTempCByIndex(0);
      // Check if reading is valid
    if (temperatureC != DEVICE_DISCONNECTED_C) {
        // Apply calibration offset (configurable, default +5°C as specified)
        data.temperature = temperatureC + temperatureOffset;
        data.validReading = validateTemperatureReading(data.temperature);
        
        if (DEBUG_ENABLED) {
            Serial.printf("🌡️ DS18B20 Raw: %.2f°C, Offset: %.2f°C, Final: %.2f°C\n", 
                         temperatureC, temperatureOffset, data.temperature);
        }
    } else {
        Serial.println("❌ Error reading DS18B20 temperature sensor");
        data.validReading = false;
    }
    
    return data;
}

WeightData SensorManager::readWeight() {
    WeightData data = {0, false, false, millis()};
    
    if (!weightInitialized) {
        return data;
    }
    
    // Update the load cell - required for HX711_ADC
    if (loadCell.update()) {
        // Get current weight reading
        float weight = loadCell.getData();
        
        data.weight = weight;
        data.stable = true; // HX711_ADC handles stability internally
        data.validReading = validateWeightReading(weight);
        
        if (DEBUG_ENABLED) {
            Serial.printf("⚖️ Weight: %.2f kg\n", weight);
        }
    } else {
        data.validReading = false;
        if (DEBUG_ENABLED) {
            Serial.println("⚠️ Weight sensor not ready");
        }
    }
    
    return data;
}

BioimpedanceData SensorManager::readBioimpedance() {
    BioimpedanceData data = {0, 0, 0, 0, 0, false, millis()};
    
    if (!bioimpedanceInitialized) {
        return data;
    }
    
    // Perform single measurement at 10 kHz
    BIAResult result;
    if (biaApp.performSingleMeasurement(10000.0f, result)) {
        data.resistance = result.Resistance;
        data.reactance = result.Reactance;
        data.impedance = result.Magnitude;
        data.phase = result.Phase;
        data.frequency = result.Frequency;
        data.validReading = result.Valid && validateBioimpedanceReading(result.Magnitude);    } else {
        Serial.println("⚠️ Failed to read bioimpedance");
    }
    
    return data;
}

ECGData SensorManager::readECG() {
    ECGData data = {0, 0, 0, false, false, millis()};
    
    if (!ecgInitialized) {
        return data;
    }
    
    long sumFiltered = 0;
    long sumBPM = 0;
    int readingCount = 0;
    int peakCount = 0;
    bool leadOffDetected = false;
    
    unsigned long startTime = millis();
    
    // Collect readings for 5 seconds (as per original code)
    while (millis() - startTime < 5000) {
        int filteredValue = 0;
        
        // Check for noise from LO_PLUS or LO_MINUS (lead-off detection)
        if (digitalRead(LO_PLUS_PIN) == 1 || digitalRead(LO_MINUS_PIN) == 1) {
            filteredValue = 0;
            leadOffDetected = true;
        } else {
            int rawValue = analogRead(ECG_PIN);
            
            // Feed ECG data to blood pressure monitor
            if (bpMonitorInitialized) {
                bpMonitor.addECGSample(rawValue, millis());
            }
            
            // Update the circular buffer
            ecgBuffer[ecgBufferIndex] = rawValue;
            ecgBufferIndex = (ecgBufferIndex + 1) % ECG_FILTER_SIZE;
            
            // Compute the average of the last ECG_FILTER_SIZE readings
            int sum = 0;
            for (int i = 0; i < ECG_FILTER_SIZE; i++) {
                sum += ecgBuffer[i];
            }
            filteredValue = sum / ECG_FILTER_SIZE;
            
            // BPM detection: detect a rising edge crossing the threshold
            static bool peakDetected = false;
            if (filteredValue > ecgThreshold && !peakDetected) {
                peakDetected = true;
                unsigned long currentTime = millis();
                unsigned long interval = currentTime - lastPeakTime;
                
                if (interval > 300) { // Ensure a minimum interval between peaks (200 BPM max)
                    currentBPM = 60000 / interval;
                    lastPeakTime = currentTime;
                    peakCount++;
                }
            } else if (filteredValue < ecgThreshold) {
                peakDetected = false;
            }
        }
        
        // Accumulate values for averaging
        sumFiltered += filteredValue;
        sumBPM += currentBPM;
        readingCount++;
        
        delay(50); // Wait 50ms between readings (20 Hz sampling rate)
    }
    
    // Compute averages from the 5-second window
    if (readingCount > 0) {
        data.avgFilteredValue = (float)sumFiltered / readingCount;
        data.avgBPM = sumBPM / readingCount;
        data.peakCount = peakCount;
        data.leadOff = leadOffDetected;
        data.validReading = validateECGReading(data.avgBPM, data.avgFilteredValue) && !leadOffDetected;
    }
      
    return data;
}

GlucoseData SensorManager::readGlucose() {
    GlucoseData data = {0, 0, 0, 0, 0, false, false, millis()};
    
    if (!glucoseInitialized) {
        return data;
    }
    
    // Read raw IR and Red values
    uint32_t ir = glucoseSensor.getIR();
    uint32_t red = glucoseSensor.getRed();
    
    // Signal quality checks
    if (ir < GLUCOSE_MIN_SIGNAL || red < GLUCOSE_MIN_SIGNAL) {
        // Signal too weak
        return data;
    }
    
    if (ir > GLUCOSE_MAX_SIGNAL || red > GLUCOSE_MAX_SIGNAL) {
        // Signal saturated
        return data;
    }
    
    // Calculate moving averages
    float avgIR = calculateGlucoseMovingAverage(glucoseIrReadings, (float)ir);
    float avgRed = calculateGlucoseMovingAverage(glucoseRedReadings, (float)red);
    
    // Calculate signal stability
    float irVariation = 0;
    if (glucoseLastReading > 0) {
        irVariation = abs(((float)ir - glucoseLastReading) / glucoseLastReading * 100);
    }
    
    // Update min/max for signal quality assessment
    glucoseMaxIR = max(glucoseMaxIR, ir);
    glucoseMinIR = min(glucoseMinIR, ir);
    glucoseMaxRed = max(glucoseMaxRed, red);
    glucoseMinRed = min(glucoseMinRed, red);
    
    // Calculate signal quality (variation percentage)
    float signalRange = 0;
    if (glucoseMaxIR > 0) {
        signalRange = ((float)(glucoseMaxIR - glucoseMinIR) / glucoseMaxIR) * 100;
    }
    
    // Store data
    data.irValue = avgIR;
    data.redValue = avgRed;
    data.ratio = (avgIR > 0) ? (avgRed / avgIR) : 0;
    data.signalQuality = signalRange;
    data.stable = (irVariation < GLUCOSE_STABILITY_THRESHOLD);
    
    // Calculate glucose only if signal is stable
    if (data.stable && irVariation < GLUCOSE_STABILITY_THRESHOLD) {
        data.glucoseLevel = calculateGlucoseLevel(avgIR, avgRed);
        data.validReading = validateGlucoseReading(data.glucoseLevel, data.signalQuality);
    }
    
    glucoseLastReading = ir;
    return data;
}

BloodPressureData SensorManager::readBloodPressure() {
    BloodPressureData data = {0, 0, 0, 0, 0, 0, false, true, millis(), 0, 0, false};
    
    if (!bpMonitorInitialized) {
        return data;
    }
    
    // Check if monitor is ready for measurement
    if (!bpMonitor.isReadyForMeasurement()) {
        Serial.println("⏳ Blood pressure monitor not ready - collecting data...");
        return data;
    }
    
    // Calculate blood pressure using PTT analysis
    data = bpMonitor.calculateBloodPressure();
    
    return data;
}

GlucoseData SensorManager::getGlucose() {
    return readGlucose();
}

BloodPressureData SensorManager::getBloodPressure() {
    return readBloodPressure();
}

bool SensorManager::allSensorsReady() {
    return heartRateInitialized && temperatureInitialized && weightInitialized;
    // Note: BIA, ECG, Glucose, and BP are optional sensors
}

bool SensorManager::isGlucoseReady() {
    return glucoseInitialized;
}

bool SensorManager::isBloodPressureReady() {
    return bpMonitorInitialized;
}

String SensorManager::getSensorStatus() {
    String status = "Sensors: ";
    status += heartRateInitialized ? "HR✅ " : "HR❌ ";
    status += temperatureInitialized ? "TEMP✅ " : "TEMP❌ ";
    status += weightInitialized ? "WEIGHT✅ " : "WEIGHT❌ ";
    status += bioimpedanceInitialized ? "BIO✅ " : "BIO❌ ";
    status += ecgInitialized ? "ECG✅ " : "ECG❌ ";
    status += glucoseInitialized ? "GLUCOSE✅ " : "GLUCOSE❌ ";
    status += bpMonitorInitialized ? "BP✅" : "BP❌";
    return status;
}

bool SensorManager::calibrateBioimpedance(float knownResistance) {
    if (!bioimpedanceInitialized) {
        Serial.println("❌ Bioimpedance sensor not initialized");
        return false;
    }
    
    Serial.printf("🔧 Calibrating bioimpedance with known resistance: %.2fΩ\n", knownResistance);
    return biaApp.calibrate(knownResistance);
}

bool SensorManager::calibrateBloodPressure(float systolic, float diastolic) {
    if (!bpMonitorInitialized) {
        Serial.println("❌ Blood pressure monitor not initialized");
        return false;
    }
    
    Serial.printf("🔧 Calibrating blood pressure with reference: %d/%d mmHg\n", 
                  (int)systolic, (int)diastolic);
    Serial.println("Ensure stable ECG and PPG signals, then press any key...");
    
    // Wait for user input
    while (!Serial.available()) {
        delay(100);
    }
    Serial.read(); // Clear buffer
    
    return bpMonitor.addCalibrationPoint(systolic, diastolic);
}

void SensorManager::setUserProfile(int age, float height, bool isMale) {
    if (bpMonitorInitialized) {
        bpMonitor.setPersonalParameters(age, height, isMale);
        Serial.printf("👤 User profile updated: Age=%d, Height=%.1fcm, Gender=%s\n",
                      age, height, isMale ? "Male" : "Female");
    }
    
    // Also update body composition analyzer profile
    UserProfile profile;
    profile.age = age;
    profile.height = height;
    profile.weight = 70.0f; // Default weight, will be updated during measurements
    profile.isMale = isMale;
    profile.activityLevel = 3; // Default moderate activity
    profile.isAthlete = false;
    
    bodyCompositionAnalyzer.setUserProfile(profile);
    Serial.println("✅ Body composition profile updated");
}

void SensorManager::setBodyCompositionProfile(const UserProfile& profile) {
    bodyCompositionAnalyzer.setUserProfile(profile);
    Serial.printf("👤 Body composition profile set: Age=%d, Height=%.1fcm, Weight=%.1fkg\n",
                  profile.age, profile.height, profile.weight);
    Serial.printf("   Gender=%s, Activity=%d, Athlete=%s\n",
                  profile.isMale ? "Male" : "Female", profile.activityLevel,
                  profile.isAthlete ? "Yes" : "No");
}

// Validation functions
bool SensorManager::validateHeartRateReading(float heartRate, float spO2) {
    return (heartRate >= 30 && heartRate <= 220) && (spO2 >= 70 && spO2 <= 100);
}

bool SensorManager::validateTemperatureReading(float temperature) {
    return (temperature >= 20.0 && temperature <= 45.0); // Reasonable range for body temperature
}

bool SensorManager::validateWeightReading(float weight) {
    return (weight >= 0.1 && weight <= 500.0); // Reasonable weight range
}

bool SensorManager::validateBioimpedanceReading(float impedance) {
    return (impedance >= 10.0 && impedance <= 10000.0); // Reasonable impedance range
}

bool SensorManager::validateECGReading(float bpm, float filteredValue) {
    return (bpm >= 30 && bpm <= 220) && (filteredValue > 0);
}

bool SensorManager::validateGlucoseReading(float glucose, float signalQuality) {
    return (glucose >= 50 && glucose <= 500) && (signalQuality > 30); // mg/dL range and signal quality
}

// Glucose helper functions
float SensorManager::calculateGlucoseMovingAverage(float* readings, float newValue) {
    // Add new value to circular buffer
    readings[glucoseReadIndex] = newValue;
    glucoseReadIndex = (glucoseReadIndex + 1) % GLUCOSE_WINDOW_SIZE;
    
    // Calculate average
    float sum = 0;
    for (int i = 0; i < GLUCOSE_WINDOW_SIZE; i++) {
        sum += readings[i];
    }
    return sum / GLUCOSE_WINDOW_SIZE;
}

float SensorManager::calculateGlucoseLevel(float irValue, float redValue) {
    // Simplified glucose estimation based on IR/Red ratio
    // In practice, this would use a calibrated algorithm
    if (irValue == 0) return 0;
    
    float ratio = redValue / irValue;
    // Convert ratio to glucose estimate (mg/dL)
    // This is a placeholder algorithm - real implementation would be calibrated
    float glucose = 100 + (ratio - 0.5) * 200; // Range roughly 80-120 mg/dL
    
    return constrain(glucose, 50, 400);
}

// Status and diagnostic functions
bool SensorManager::isECGReady() {
    return ecgInitialized;
}

bool SensorManager::isHeartRateReady() {
    return heartRateInitialized;
}

String SensorManager::getBIAStatus() {
    if (!bioimpedanceInitialized) {
        return "BIA: Not initialized";
    }
    return "BIA: Ready for measurements";
}

bool SensorManager::performBIASweep(BIAResult* results, unsigned int maxResults, unsigned int* resultCount) {
    if (!bioimpedanceInitialized || !results || !resultCount) {
        return false;
    }
    
    *resultCount = 0;
    // Perform frequency sweep measurements
    float frequencies[] = {1000, 5000, 10000, 50000, 100000}; // Hz
    int numFreq = sizeof(frequencies) / sizeof(frequencies[0]);
    
    for (int i = 0; i < numFreq && i < maxResults; i++) {
        BIAResult result;
        if (biaApp.performSingleMeasurement(frequencies[i], result)) {
            results[i] = result;
            (*resultCount)++;
        }
    }
    
    return (*resultCount > 0);
}

void SensorManager::printSensorReadings(const SensorReadings& readings) {
    displaySensorReadings(readings);
}

// In the loop or wherever you display the readings
void displaySensorReadings(const SensorReadings& readings) {
    Serial.println("=======================");
    Serial.printf("System Uptime: %lu ms\n", millis());
    
    // Heart Rate and SpO2
    if (readings.heartRate.validReading) {
        Serial.printf("Heart Rate: %d bpm, SpO2: %.1f%%\n", 
                     readings.heartRate.heartRate, readings.heartRate.spO2);
    } else {
        Serial.println("Heart Rate: Invalid reading");
    }
    
    // Temperature
    if (readings.temperature.validReading) {
        Serial.printf("Temperature: %.1f°C\n", readings.temperature.temperature);
    } else {
        Serial.println("Temperature: Invalid reading");
    }
    
    // Weight
    if (readings.weight.validReading) {
        Serial.printf("Weight: %.1f kg %s\n", readings.weight.weight,
                     readings.weight.stable ? "(Stable)" : "(Unstable)");
    } else {
        Serial.println("Weight: Invalid reading");
    }
      // Bioimpedance
    if (readings.bioimpedance.validReading) {
        Serial.printf("Bioimpedance: %.1fΩ (R: %.1f, X: %.1f, Z: %.1f, Phase: %.1f°)\n",
                     readings.bioimpedance.impedance, readings.bioimpedance.resistance,
                     readings.bioimpedance.reactance, readings.bioimpedance.impedance,
                     readings.bioimpedance.phase);
    } else {
        Serial.println("Bioimpedance: Invalid reading");
    }
    
    // ECG
    if (readings.ecg.validReading) {
        Serial.printf("ECG: BPM: %.1f, Filtered: %.1f\n", readings.ecg.avgBPM, readings.ecg.avgFilteredValue);
        Serial.printf("  Peaks: %d, Lead-off: %s\n", readings.ecg.peakCount, readings.ecg.leadOff ? "Yes" : "No");
    } else {
        Serial.println("ECG: Invalid reading");
    }
    
    // Glucose
    if (readings.glucose.validReading) {
        Serial.printf("Glucose: %.1f mg/dL (IR: %.1f, Red: %.1f, Ratio: %.3f, Quality: %.1f%%) %s\n",
                     readings.glucose.glucoseLevel, readings.glucose.irValue, readings.glucose.redValue,
                     readings.glucose.ratio, readings.glucose.signalQuality,
                     readings.glucose.stable ? "(Stable)" : "(Unstable)");
    } else {
        Serial.println("Glucose: Invalid reading");
    }
    
    // Blood Pressure Display
    if (readings.bloodPressure.validReading) {
        String bpCategory = BPAnalysis::interpretBPReading(readings.bloodPressure.systolic, readings.bloodPressure.diastolic);
        Serial.printf("Blood Pressure: %.0f/%.0f mmHg (%s)\n", 
                     readings.bloodPressure.systolic, readings.bloodPressure.diastolic, bpCategory.c_str());
        Serial.printf("  PTT: %.1fms, PWV: %.2fm/s, HRV: %.1fms\n",
                     readings.bloodPressure.pulseTransitTime, readings.bloodPressure.pulseWaveVelocity,
                     readings.bloodPressure.heartRateVariability);
        Serial.printf("  Quality: %.1f%%, Correlation: %d%%, %s\n",
                     readings.bloodPressure.signalQuality, readings.bloodPressure.correlationCoeff,
                     readings.bloodPressure.rhythmRegular ? "Regular" : "Irregular");        if (readings.bloodPressure.needsCalibration) {
            Serial.println("  ⚠️ Needs calibration with reference BP measurement");
        }
    } else {
        Serial.println("Blood Pressure: Invalid reading");
    }
    
    // Body Composition Display
    if (readings.bodyComposition.validReading) {
        Serial.printf("Body Composition (Quality: %.1f%%):\n", readings.bodyComposition.measurementQuality);
        Serial.printf("  Body Fat: %.1f%%, Muscle Mass: %.1fkg (%.1f%%)\n",
                     readings.bodyComposition.bodyFatPercentage, 
                     readings.bodyComposition.muscleMassKg,
                     readings.bodyComposition.muscleMassPercentage);
        Serial.printf("  Body Water: %.1f%%, Fat Mass: %.1fkg\n",
                     readings.bodyComposition.bodyWaterPercentage,
                     readings.bodyComposition.fatMassKg);
        Serial.printf("  BMR: %.0f kcal/day, Metabolic Age: %.1f years\n",
                     readings.bodyComposition.BMR,
                     readings.bodyComposition.metabolicAge);
        Serial.printf("  Visceral Fat: %.1f, Bone Mass: %.1fkg\n",
                     readings.bodyComposition.visceralFatLevel,
                     readings.bodyComposition.boneMassKg);
        Serial.printf("  Phase Angle: %.1f°, Impedance@50kHz: %.1fΩ\n",
                     readings.bodyComposition.phaseAngle,
                     readings.bodyComposition.impedance50kHz);
    } else {
        Serial.println("Body Composition: Invalid or unavailable");
    }
    
    Serial.println("=======================");
}

// Additional status check methods (only missing ones)
bool SensorManager::isTemperatureReady() {
    return temperatureInitialized && temperatureSensor.getDeviceCount() > 0;
}

bool SensorManager::isBioimpedanceReady() {
    return bioimpedanceInitialized; // Remove invalid IsReady() call
}

bool SensorManager::isWeightReady() {
    return weightInitialized; // HX711_ADC doesn't have is_ready() method
}

// DS18B20 standalone test function (for debugging and validation)
void SensorManager::testDS18B20() {
    Serial.println("🔬 DS18B20 Standalone Test Mode");
    Serial.println("===============================");
    
    if (!temperatureInitialized) {
        Serial.println("❌ Temperature sensor not initialized");
        return;
    }
    
    for (int i = 0; i < 10; i++) {
        // Request temperature reading from the DS18B20 sensor
        temperatureSensor.requestTemperatures();
        
        // Get the temperature in Celsius (use getTempFahrenheit for Fahrenheit)
        float temperatureC = temperatureSensor.getTempCByIndex(0);
          // Print the temperature to Serial Monitor
        if (temperatureC != DEVICE_DISCONNECTED_C) {
            Serial.print("Temperature: ");
            Serial.print(temperatureC + temperatureOffset); // Apply configurable calibration offset
            Serial.println(" °C");
        } else {
            Serial.println("Error reading temperature");
        }
        
        // Wait 1 second before taking another reading
        delay(1000);
    }
    
    Serial.println("===============================");
    Serial.println("✅ DS18B20 test completed");
}

void SensorManager::setTemperatureOffset(float offset) {
    temperatureOffset = offset;
    Serial.printf("🌡️ DS18B20 temperature offset set to: %.2f°C\n", offset);
}

float SensorManager::getTemperatureOffset() {
    return temperatureOffset;
}

// Wrapper methods for individual test functions
HeartRateData SensorManager::readHeartRate() {
    return readHeartRateAndSpO2();
}

TemperatureData SensorManager::getTemperature() {
    return readTemperature();
}

WeightData SensorManager::getWeight() {
    return readWeight();
}

BioimpedanceData SensorManager::getBioimpedance() {
    return readBioimpedance();
}

ECGData SensorManager::getECG() {
    return readECG();
}

void SensorManager::tareWeight() {
    if (weightInitialized) {
        loadCell.tareNoDelay();
        Serial.println("⚖️ Weight sensor tare initiated...");
        
        // Wait for tare to complete
        while (!loadCell.getTareStatus()) {
            loadCell.update();
            delay(10);
        }
        Serial.println("✅ Weight sensor tare complete");
    } else {
        Serial.println("❌ Weight sensor not initialized");
    }
}

void SensorManager::calibrateWeight(float knownWeight) {
    if (!weightInitialized) {
        Serial.println("❌ Weight sensor not initialized");
        return;
    }
    
    Serial.println("***");
    Serial.println("🔧 Starting weight calibration...");
    Serial.printf("📏 Known weight: %.2f kg\n", knownWeight);
    
    // Refresh data set for accurate calibration
    loadCell.refreshDataSet();
    
    // Calculate new calibration factor
    float newCalFactor = loadCell.getNewCalibration(knownWeight);
    
    Serial.printf("📊 New calibration factor: %.2f\n", newCalFactor);
    Serial.println("💾 Save to EEPROM? Send 'y' to save, 'n' to skip");
    
    // Set the new calibration factor temporarily
    loadCell.setCalFactor(newCalFactor);
    
    // Note: In a real implementation, you'd wait for user input here
    // For now, auto-save the calibration factor
    EEPROM.put(WEIGHT_EEPROM_ADDRESS, newCalFactor);
    EEPROM.commit();
    Serial.printf("✅ Calibration factor %.2f saved to EEPROM\n", newCalFactor);
    
    Serial.println("✅ Calibration complete!");
    Serial.println("***");
}

// Individual AD8232 ECG test for heart rate diagram
void SensorManager::testAD8232ECG() {
    Serial.println("🫀 AD8232 ECG Individual Test - Heart Rate Diagram");
    Serial.println("=================================================");
    
    if (!ecgInitialized) {
        Serial.println("❌ ECG sensor not initialized");
        return;
    }
    
    Serial.println("📊 Real-time ECG readings for heart rate analysis");
    Serial.println("💡 Press any key to stop the test");
    Serial.println("📈 Format: Timestamp(ms), RawValue, FilteredValue, BPM, LeadOff");
    Serial.println("-------------------------------------------------");
    
    // Reset ECG analysis variables
    for (int i = 0; i < ECG_FILTER_SIZE; i++) {
        ecgBuffer[i] = 0;
    }
    ecgBufferIndex = 0;
    lastPeakTime = 0;
    currentBPM = 0;
    
    // Peak detection variables
    bool peakDetected = false;
    int lastFilteredValue = 0;
    int peakCount = 0;
    unsigned long testStartTime = millis();
    unsigned long lastDisplayTime = 0;
    
    // Running averages for heart rate calculation
    float bpmReadings[10] = {0};
    int bpmIndex = 0;
    
    while (true) {
        // Check if user wants to stop
        if (Serial.available()) {
            Serial.read(); // Clear buffer
            break;
        }
        
        unsigned long currentTime = millis();
        int rawValue = 0;
        int filteredValue = 0;
        bool leadOff = false;
        
        // Check for lead-off detection
        if (digitalRead(LO_PLUS_PIN) == 1 || digitalRead(LO_MINUS_PIN) == 1) {
            leadOff = true;
            filteredValue = 0;
            rawValue = 0;
        } else {
            // Read raw ECG value
            rawValue = analogRead(ECG_PIN);
            
            // Update circular buffer for filtering
            ecgBuffer[ecgBufferIndex] = rawValue;
            ecgBufferIndex = (ecgBufferIndex + 1) % ECG_FILTER_SIZE;
            
            // Calculate filtered value (moving average)
            int sum = 0;
            for (int i = 0; i < ECG_FILTER_SIZE; i++) {
                sum += ecgBuffer[i];
            }
            filteredValue = sum / ECG_FILTER_SIZE;
            
            // Peak detection for heart rate calculation
            // Look for rising edge crossing threshold
            if (filteredValue > ecgThreshold && !peakDetected && filteredValue > lastFilteredValue) {
                peakDetected = true;
                unsigned long interval = currentTime - lastPeakTime;
                
                // Ensure minimum interval between peaks (300ms = 200 BPM max)
                if (interval > 300 && lastPeakTime > 0) {
                    float instantBPM = 60000.0 / interval;
                    
                    // Validate BPM range
                    if (instantBPM >= 30 && instantBPM <= 200) {
                        // Add to running average
                        bpmReadings[bpmIndex] = instantBPM;
                        bpmIndex = (bpmIndex + 1) % 10;
                        
                        // Calculate average BPM
                        float sumBPM = 0;
                        int validReadings = 0;
                        for (int i = 0; i < 10; i++) {
                            if (bpmReadings[i] > 0) {
                                sumBPM += bpmReadings[i];
                                validReadings++;
                            }
                        }
                        
                        if (validReadings > 0) {
                            currentBPM = sumBPM / validReadings;
                        }
                        
                        peakCount++;
                    }
                }
                lastPeakTime = currentTime;
            } else if (filteredValue < ecgThreshold - 50) { // Hysteresis
                peakDetected = false;
            }
            
            lastFilteredValue = filteredValue;
        }
        
        // Display data every 50ms for real-time monitoring
        if (currentTime - lastDisplayTime >= 50) {
            // Output format: Timestamp, Raw, Filtered, BPM, LeadOff, PeakDetected
            Serial.printf("%lu,%d,%d,%.1f,%d,%d\n", 
                         currentTime - testStartTime,
                         rawValue,
                         filteredValue,
                         currentBPM,
                         leadOff ? 1 : 0,
                         peakDetected ? 1 : 0);
            
            lastDisplayTime = currentTime;
        }
        
        // Show status every 5 seconds
        if ((currentTime - testStartTime) % 5000 < 50) {
            Serial.printf("# Status: BPM=%.1f, Peaks=%d, Time=%lus, LeadOff=%s\n",
                         currentBPM, peakCount, (currentTime - testStartTime) / 1000,
                         leadOff ? "YES" : "NO");
        }
        
        delay(20); // 50Hz sampling rate
    }
    
    unsigned long totalTime = millis() - testStartTime;
    
    Serial.println("-------------------------------------------------");
    Serial.println("📊 ECG Test Summary:");
    Serial.printf("⏱️  Test Duration: %.2f seconds\n", totalTime / 1000.0);
    Serial.printf("💓 Final Heart Rate: %.1f BPM\n", currentBPM);
    Serial.printf("📈 Total Peaks Detected: %d\n", peakCount);
    Serial.printf("📊 Average Peak Interval: %.1f ms\n", 
                 peakCount > 1 ? (float)totalTime / (peakCount - 1) : 0);
    
    // Heart rate analysis
    if (currentBPM > 0) {
        String hrCategory;
        if (currentBPM < 60) hrCategory = "Bradycardia (Slow)";
        else if (currentBPM > 100) hrCategory = "Tachycardia (Fast)";
        else hrCategory = "Normal";
        
        Serial.printf("🫀 Heart Rate Category: %s\n", hrCategory.c_str());
    }
    
    Serial.println("=================================================");
    Serial.println("✅ AD8232 ECG test completed");
}

// Individual real-time ECG monitor (continuous display)
void SensorManager::runECGMonitor() {
    Serial.println("🫀 AD8232 Real-Time ECG Monitor");
    Serial.println("==============================");
    
    if (!ecgInitialized) {
        Serial.println("❌ ECG sensor not initialized");
        return;
    }
    
    Serial.println("📊 Real-time ECG waveform display");
    Serial.println("💡 Press any key to stop monitoring");
    Serial.println("📈 Visual representation of ECG signal:");
    Serial.println("");
    
    // Display settings
    const int displayWidth = 60;
    const int baselinePos = displayWidth / 2;
    
    while (true) {
        if (Serial.available()) {
            Serial.read();
            break;
        }
        
        // Read ECG value
        bool leadOff = (digitalRead(LO_PLUS_PIN) == 1 || digitalRead(LO_MINUS_PIN) == 1);
        
        if (leadOff) {
            Serial.println("❌ LEAD OFF - Check electrode connections");
        } else {
            int rawValue = analogRead(ECG_PIN);
            
            // Update filter buffer
            ecgBuffer[ecgBufferIndex] = rawValue;
            ecgBufferIndex = (ecgBufferIndex + 1) % ECG_FILTER_SIZE;
            
            // Calculate filtered value
            int sum = 0;
            for (int i = 0; i < ECG_FILTER_SIZE; i++) {
                sum += ecgBuffer[i];
            }
            int filteredValue = sum / ECG_FILTER_SIZE;
            
            // Scale value for display (assuming 12-bit ADC, 0-4095 range)
            int scaledValue = map(filteredValue, 1500, 2500, 0, displayWidth);
            scaledValue = constrain(scaledValue, 0, displayWidth - 1);
            
            // Create visual waveform
            String waveform = "";
            for (int i = 0; i < displayWidth; i++) {
                if (i == scaledValue) {
                    waveform += "█";
                } else if (i == baselinePos) {
                    waveform += "─";
                } else {
                    waveform += " ";
                }
            }
            
            Serial.printf("%s %d\n", waveform.c_str(), filteredValue);
        }
        
        delay(100); // 10Hz display update
    }
    
    Serial.println("==============================");
    Serial.println("✅ ECG monitoring stopped");
}

BodyComposition SensorManager::getBodyComposition(float currentWeight) {
    BodyComposition composition = {};
    composition.timestamp = millis();
    composition.validReading = false;
    
    if (!bioimpedanceInitialized) {
        Serial.println("⚡ Bioimpedance sensor not initialized for body composition");
        return composition;
    }
    
    // Perform multi-frequency BIA sweep for accurate body composition
    const int maxResults = 10;
    BIAResult results[maxResults];
    unsigned int resultCount = 0;
    
    // Perform frequency sweep: 1kHz, 5kHz, 10kHz, 50kHz, 100kHz
    float frequencies[] = {1000.0f, 5000.0f, 10000.0f, 50000.0f, 100000.0f};
    int numFreq = sizeof(frequencies) / sizeof(frequencies[0]);
    
    Serial.println("🔄 Performing BIA frequency sweep for body composition...");
    
    for (int i = 0; i < numFreq && resultCount < maxResults; i++) {
        BIAResult result;
        if (biaApp.performSingleMeasurement(frequencies[i], result)) {
            if (result.Valid && result.Resistance > 10 && result.Resistance < 2000) {
                results[resultCount] = result;
                resultCount++;
                Serial.printf("   %.0fHz: R=%.1fΩ, X=%.1fΩ, Z=%.1fΩ\n", 
                             frequencies[i], result.Resistance, result.Reactance, result.Magnitude);
            }
        }
        delay(100); // Brief delay between measurements
    }
    
    if (resultCount == 0) {
        Serial.println("❌ No valid BIA measurements for body composition analysis");
        return composition;
    }
    
    // Use current weight if provided, otherwise try to get it from weight sensor
    if (currentWeight <= 0 && weightInitialized) {
        WeightData weightData = readWeight();
        if (weightData.validReading && weightData.stable) {
            currentWeight = weightData.weight;
        }
    }
    
    // Perform body composition analysis
    composition = bodyCompositionAnalyzer.analyzeBodyComposition(results, resultCount, currentWeight);
    
    if (composition.validReading) {
        Serial.println("✅ Body composition analysis completed");
        Serial.printf("📊 Results: BF=%.1f%%, Muscle=%.1fkg, Water=%.1f%%, BMR=%.0fkcal/day\n",
                     composition.bodyFatPercentage, composition.muscleMassKg, 
                     composition.bodyWaterPercentage, composition.BMR);
        Serial.printf("📈 Quality: %.1f%%, Phase Angle: %.1f°\n", 
                     composition.measurementQuality, composition.phaseAngle);
    } else {
        Serial.println("⚠️ Body composition analysis completed with low confidence");
        Serial.println("   Ensure proper electrode placement and stable contact");
    }
    
    return composition;
}

// ===================================================
// MAX30102 Staged Testing Implementation (Single Sensor)
// ===================================================

bool SensorManager::setMAX30102Mode(MAX30102_Mode mode) {
    if (mode == currentMAX30102Mode) {
        return true; // Already in requested mode
    }
    
    Serial.printf("🔄 Switching MAX30102 from %s to %s mode\n", 
                  getMAX30102ModeString().c_str(), 
                  getModeString(mode).c_str());
    
    currentMAX30102Mode = mode;
    modeStartTime = millis();
    
    // Configure sensor settings based on mode
    switch (mode) {
        case MODE_HEART_RATE_SPO2:
            return switchToHeartRateMode();
        case MODE_GLUCOSE_ESTIMATION:
            return switchToGlucoseMode();
        case MODE_BLOOD_PRESSURE:
            return switchToBloodPressureMode();
        case MODE_CALIBRATION:
            return switchToCalibrationMode();
        default:
            Serial.println("❌ Unknown MAX30102 mode requested");
            return false;
    }
}

MAX30102_Mode SensorManager::getCurrentMAX30102Mode() {
    return currentMAX30102Mode;
}

bool SensorManager::switchToHeartRateMode() {
    Serial.println("💓 Configuring MAX30102 for Heart Rate & SpO2 measurement");
    
    if (!heartRateInitialized) {
        Serial.println("❌ Heart rate sensor not initialized");
        return false;
    }
    
    // Configure for optimal heart rate and SpO2 measurement
    heartRateSensor.setup();
    heartRateSensor.setPulseAmplitudeRed(0x0A);    // Medium power for good signal
    heartRateSensor.setPulseAmplitudeIR(0x1F);     // Higher power for SpO2 accuracy
    heartRateSensor.setSampleRate(2);              // Sample rate 2 (200 Hz)
    heartRateSensor.setPulseWidth(215);            // 215 microseconds pulse width
    
    Serial.println("✅ MAX30102 configured for Heart Rate & SpO2 mode");
    return true;
}

bool SensorManager::switchToGlucoseMode() {
    Serial.println("🩸 Configuring MAX30102 for Glucose Estimation");
    
    if (!glucoseInitialized) {
        Serial.println("❌ Glucose sensor mode not initialized");
        return false;
    }
    
    // Configure for glucose estimation using PPG morphology
    glucoseSensor.setup();
    glucoseSensor.setPulseAmplitudeRed(0x08);      // Lower power for glucose
    glucoseSensor.setPulseAmplitudeIR(0x08);       // Lower power, focused on morphology
    glucoseSensor.setSampleRate(2);               // Sample rate 2 (200 Hz)
    glucoseSensor.setPulseWidth(118);              // Shorter pulse width
    
    Serial.println("✅ MAX30102 configured for Glucose Estimation mode");
    return true;
}

bool SensorManager::switchToBloodPressureMode() {
    Serial.println("🩺 Configuring MAX30102 for Blood Pressure PTT");
    
    // Use heart rate sensor for PPG in blood pressure mode
    if (!heartRateInitialized) {
        Serial.println("❌ Heart rate sensor not initialized for BP mode");
        return false;
    }
    
    // Configure for pulse transit time measurement
    heartRateSensor.setup();
    heartRateSensor.setPulseAmplitudeRed(0x0C);    // Medium-high power for clear pulse
    heartRateSensor.setPulseAmplitudeIR(0x0C);     // Balanced for PTT detection
    heartRateSensor.setSampleRate(3);              // Sample rate 3 (400 Hz) for timing precision
    heartRateSensor.setPulseWidth(215);            // Standard pulse width
    
    Serial.println("✅ MAX30102 configured for Blood Pressure PTT mode");
    return true;
}

bool SensorManager::switchToCalibrationMode() {
    Serial.println("⚙️ Configuring MAX30102 for Calibration");
    
    // Use standard settings for calibration
    if (!heartRateInitialized) {
        Serial.println("❌ Sensor not initialized for calibration mode");
        return false;
    }
    
    // Calibration mode uses moderate settings
    heartRateSensor.setup();
    heartRateSensor.setPulseAmplitudeRed(0x0F);    // Moderate power
    heartRateSensor.setPulseAmplitudeIR(0x0F);     // Moderate power
    heartRateSensor.setSampleRate(2);              // Sample rate 2 (200 Hz)
    heartRateSensor.setPulseWidth(215);            // Standard pulse width
    
    Serial.println("✅ MAX30102 configured for Calibration mode");
    return true;
}

void SensorManager::cycleMAX30102Modes() {
    if (!autoModeCycling) {
        return; // Auto-cycling disabled
    }
    
    unsigned long currentTime = millis();
    unsigned long timeInCurrentMode = currentTime - modeStartTime;
    
    // Check if it's time to switch modes
    bool shouldSwitch = false;
    
    switch (currentMAX30102Mode) {
        case MODE_HEART_RATE_SPO2:
            shouldSwitch = (timeInCurrentMode >= MODE_DURATION_HR_SPO2);
            break;
        case MODE_GLUCOSE_ESTIMATION:
            shouldSwitch = (timeInCurrentMode >= MODE_DURATION_GLUCOSE);
            break;
        case MODE_BLOOD_PRESSURE:
            shouldSwitch = (timeInCurrentMode >= MODE_DURATION_BP);
            break;
        case MODE_CALIBRATION:
            shouldSwitch = (timeInCurrentMode >= MODE_DURATION_CALIBRATION);
            break;
    }
    
    if (shouldSwitch) {
        // Cycle to next mode
        MAX30102_Mode nextMode;
        switch (currentMAX30102Mode) {
            case MODE_HEART_RATE_SPO2:
                nextMode = MODE_GLUCOSE_ESTIMATION;
                break;
            case MODE_GLUCOSE_ESTIMATION:
                nextMode = MODE_BLOOD_PRESSURE;
                break;
            case MODE_BLOOD_PRESSURE:
                nextMode = MODE_CALIBRATION;
                break;
            case MODE_CALIBRATION:
            default:
                nextMode = MODE_HEART_RATE_SPO2;
                break;
        }
        
        setMAX30102Mode(nextMode);
        lastModeCycle = currentTime;
    }
}

String SensorManager::getMAX30102ModeString() {
    return getModeString(currentMAX30102Mode);
}

String getModeString(MAX30102_Mode mode) {
    switch (mode) {
        case MODE_HEART_RATE_SPO2:
            return "Heart Rate & SpO2";
        case MODE_GLUCOSE_ESTIMATION:
            return "Glucose Estimation";
        case MODE_BLOOD_PRESSURE:
            return "Blood Pressure PTT";
        case MODE_CALIBRATION:
            return "Calibration";
        default:
            return "Unknown";
    }
}
