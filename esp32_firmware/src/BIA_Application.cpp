#include "BIA_Application.h"

BIAApplication::BIAApplication() {
    _initialized = false;
    _measuring = false;
    _calibrationGain = 1.0f;
    _calibrationPhase = 0.0f;
    _currentFreqIndex = 0;
    
    // Default configuration
    _config.StartFreq = 1000.0f;
    _config.EndFreq = 100000.0f;
    _config.NumOfPoints = 50;
    _config.ExcitVolt = 200.0f; // 200mV
    _config.SweepEnable = true;
}

bool BIAApplication::initialize(int csPin, int resetPin, int intPin) {
    Serial.println("Initializing BIA Application...");
    
    if (!AD5940.begin(csPin, resetPin, intPin)) {
        Serial.println("Failed to initialize AD5940");
        return false;
    }
    
    if (!AD5940.initializeBIA()) {
        Serial.println("Failed to configure AD5940 for BIA");
        return false;
    }
    
    // Perform self-test
    if (!selfTest()) {
        Serial.println("BIA self-test failed");
        return false;
    }
    
    _initialized = true;
    Serial.println("BIA Application initialized successfully");
    return true;
}

bool BIAApplication::configure(const BIAConfig& config) {
    if (!_initialized) return false;
    
    _config = config;
    
    // Validate configuration
    if (_config.StartFreq >= _config.EndFreq) {
        Serial.println("Invalid frequency range");
        return false;
    }
    
    if (_config.NumOfPoints < 1 || _config.NumOfPoints > 1000) {
        Serial.println("Invalid number of points");
        return false;
    }
    
    Serial.printf("BIA configured: %.1fHz - %.1fHz, %d points\n", 
                 _config.StartFreq, _config.EndFreq, _config.NumOfPoints);
    return true;
}

bool BIAApplication::startMeasurement() {
    if (!_initialized || _measuring) return false;
    
    if (!AD5940.startBIA()) {
        return false;
    }
    
    _measuring = true;
    _currentFreqIndex = 0;
    return true;
}

bool BIAApplication::stopMeasurement() {
    if (!_initialized || !_measuring) return false;
    
    if (!AD5940.stopBIA()) {
        return false;
    }
    
    _measuring = false;
    return true;
}

bool BIAApplication::isMeasuring() {
    return _measuring;
}

bool BIAApplication::getResult(BIAResult& result) {
    if (!_initialized) return false;
    
    fFreqPoint data;
    uint32_t count;
    
    if (!AD5940.getBIAData(&data, &count) || count == 0) {
        result.Valid = false;
        return false;
    }
    
    // Fill result structure
    result.Frequency = data.FreqHz;
    result.Magnitude = data.Impedance.Magnitude * _calibrationGain;
    result.Phase = data.Impedance.Phase + _calibrationPhase;
    result.Resistance = result.Magnitude * cos(result.Phase * PI / 180.0f);
    result.Reactance = result.Magnitude * sin(result.Phase * PI / 180.0f);
    result.Timestamp = millis();
    result.Valid = true;
    
    return true;
}

bool BIAApplication::performSingleMeasurement(float frequency, BIAResult& result) {
    if (!_initialized) return false;
    
    // Set frequency
    if (!setFrequency(frequency)) {
        result.Valid = false;
        return false;
    }
    
    // Start measurement
    if (!startMeasurement()) {
        result.Valid = false;
        return false;
    }
    
    // Wait for result
    if (!waitForResult()) {
        stopMeasurement();
        result.Valid = false;
        return false;
    }
    
    // Get result
    bool success = getResult(result);
    stopMeasurement();
    
    return success;
}

bool BIAApplication::performFrequencySweep(BIAResult* results, uint32_t maxResults, uint32_t* actualCount) {
    if (!_initialized || !_config.SweepEnable) return false;
    
    *actualCount = 0;
    uint32_t numPoints = min(_config.NumOfPoints, maxResults);
    
    Serial.printf("Starting frequency sweep: %d points\n", numPoints);
    
    for (uint32_t i = 0; i < numPoints; i++) {
        // Calculate frequency for this point
        float frequency;
        if (numPoints == 1) {
            frequency = _config.StartFreq;
        } else {
            float logStart = log10(_config.StartFreq);
            float logEnd = log10(_config.EndFreq);
            float logStep = (logEnd - logStart) / (numPoints - 1);
            frequency = pow(10, logStart + i * logStep);
        }
        
        // Perform measurement at this frequency
        BIAResult result;
        if (performSingleMeasurement(frequency, result)) {
            results[*actualCount] = result;
            (*actualCount)++;
            
            Serial.printf("%.1f Hz: %.1f Ω, %.1f°\n", 
                         result.Frequency, result.Magnitude, result.Phase);
        }
        
        delay(50); // Small delay between measurements
    }
    
    Serial.printf("Frequency sweep complete: %d valid measurements\n", *actualCount);
    return (*actualCount > 0);
}

bool BIAApplication::calibrate(float knownResistance) {
    if (!_initialized) return false;
    
    Serial.printf("Calibrating with %.1f ohm resistor...\n", knownResistance);
    
    // Perform measurement at mid-frequency
    float calibFreq = sqrt(_config.StartFreq * _config.EndFreq);
    BIAResult result;
    
    if (!performSingleMeasurement(calibFreq, result)) {
        Serial.println("Calibration measurement failed");
        return false;
    }
    
    if (result.Magnitude > 0) {
        _calibrationGain = knownResistance / result.Magnitude;
        _calibrationPhase = -result.Phase; // Assuming resistor should have 0 phase
        
        Serial.printf("Calibration complete: Gain=%.4f, Phase=%.2f°\n", 
                     _calibrationGain, _calibrationPhase);
        return true;
    }
    
    Serial.println("Invalid calibration measurement");
    return false;
}

bool BIAApplication::setCalibrationFactors(float gainFactor, float phaseOffset) {
    _calibrationGain = gainFactor;
    _calibrationPhase = phaseOffset;
    
    Serial.printf("Calibration factors set: Gain=%.4f, Phase=%.2f°\n", 
                 _calibrationGain, _calibrationPhase);
    return true;
}

String BIAApplication::getStatus() {
    String status = "BIA Status: ";
    
    if (!_initialized) {
        status += "Not initialized";
    } else if (_measuring) {
        status += "Measuring";
    } else {
        status += "Ready";
    }
    
    status += String(", Freq: ") + String(_config.StartFreq, 1) + 
              "-" + String(_config.EndFreq, 1) + "Hz";
    
    return status;
}

bool BIAApplication::selfTest() {
    if (!_initialized) return false;
    
    Serial.println("Performing BIA self-test...");
    
    // Check AD5940 communication
    uint32_t id = AD5940.readID();
    if (id != 0x5502) {
        Serial.printf("Self-test failed: Invalid ID 0x%04X\n", id);
        return false;
    }
    
    // Perform test measurement with internal calibration
    BIAResult testResult;
    if (performSingleMeasurement(10000.0f, testResult)) {
        Serial.printf("Self-test measurement: %.1f Ω, %.1f°\n", 
                     testResult.Magnitude, testResult.Phase);
        
        // Basic sanity check
        if (testResult.Magnitude > 10 && testResult.Magnitude < 100000) {
            Serial.println("BIA self-test passed");
            return true;
        }
    }
    
    Serial.println("BIA self-test failed: Invalid measurement");
    return false;
}

bool BIAApplication::setFrequency(float frequency) {
    // This would need to be implemented based on AD5940 register map
    // For now, assume frequency is set correctly
    return true;
}

bool BIAApplication::waitForResult(uint32_t timeoutMs) {
    uint32_t startTime = millis();
    
    while ((millis() - startTime) < timeoutMs) {
        if (AD5940.isReady()) {
            return true;
        }
        delay(10);
    }
    
    return false;
}
