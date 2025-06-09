#include "sensors.h"

SensorManager::SensorManager() : oneWire(DS18B20_PIN), temperatureSensor(&oneWire) {
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
    
    bool success = true;
    
    // Initialize I2C for heart rate sensor
    Wire.begin(MAX30102_SDA_PIN, MAX30102_SCL_PIN);
    
    // Initialize heart rate sensor
    if (initializeHeartRateSensor()) {
        Serial.println("✅ Heart rate sensor initialized");
        heartRateInitialized = true;
    } else {
        Serial.println("❌ Heart rate sensor failed");
        success = false;
    }
    
    // Initialize temperature sensor
    if (initializeTemperatureSensor()) {
        Serial.println("✅ Temperature sensor initialized");
        temperatureInitialized = true;
    } else {
        Serial.println("❌ Temperature sensor failed");
        success = false;
    }
    
    // Initialize weight sensor
    if (initializeWeightSensor()) {
        Serial.println("✅ Weight sensor initialized");
        weightInitialized = true;
    } else {
        Serial.println("❌ Weight sensor failed");
        success = false;
    }
      // Initialize bioimpedance sensor
    if (initializeBioimpedanceSensor()) {
        Serial.println("✅ Bioimpedance sensor initialized");
        bioimpedanceInitialized = true;
    } else {
        Serial.println("⚠️ Bioimpedance sensor failed (optional)");
        // Don't fail initialization for bioimpedance
    }
      // Initialize ECG sensor
    if (initializeECGSensor()) {
        Serial.println("✅ ECG sensor initialized");
        ecgInitialized = true;
    } else {
        Serial.println("⚠️ ECG sensor failed (optional)");
        // Don't fail initialization for ECG
    }
    
    // Initialize glucose sensor
    if (initializeGlucoseSensor()) {
        Serial.println("✅ Glucose sensor initialized");
        glucoseInitialized = true;
    } else {
        Serial.println("⚠️ Glucose sensor failed (optional)");
        // Don't fail initialization for glucose
    }
    
    // Initialize blood pressure monitor
    if (initializeBloodPressureMonitor()) {
        Serial.println("✅ Blood pressure monitor initialized");
        bpMonitorInitialized = true;
    } else {
        Serial.println("⚠️ Blood pressure monitor failed (optional)");
        // Don't fail initialization for BP monitor
    }
    
    return success;
}

bool SensorManager::initializeHeartRateSensor() {
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
    loadCell.begin(LOAD_CELL_DOUT_PIN, LOAD_CELL_SCK_PIN);
    
    if (!loadCell.is_ready()) {
        return false;
    }
    
    // Set calibration factor
    loadCell.set_scale(weightCalibrationFactor);
    loadCell.tare(); // Reset scale to 0
    
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
    Serial.println("🔄 Initializing MAX30102 Glucose sensor...");
    
    // Initialize second I2C bus for glucose sensor
    Wire1.begin(GLUCOSE_SDA_PIN, GLUCOSE_SCL_PIN);
    
    if (!glucoseSensor.begin(Wire1, I2C_SPEED_FAST)) {
        Serial.println("❌ Glucose sensor not found on second I2C bus");
        return false;
    }
    
    // Configure glucose sensor settings
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
    
    if (!weightInitialized || !loadCell.is_ready()) {
        return data;
    }
    
    // Take multiple readings for stability
    float readings[5];
    for (int i = 0; i < 5; i++) {
        readings[i] = loadCell.get_units(3);
        delay(100);
    }
    
    // Calculate average
    float sum = 0;
    for (int i = 0; i < 5; i++) {
        sum += readings[i];
    }
    float average = sum / 5.0;
    
    // Check stability (readings should be within 0.1 kg)
    bool stable = true;
    for (int i = 0; i < 5; i++) {
        if (abs(readings[i] - average) > 0.1) {
            stable = false;
            break;
        }
    }
    
    data.weight = average;
    data.stable = stable;
    data.validReading = validateWeightReading(average) && stable;
    
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
    return weightInitialized && loadCell.is_ready();
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
