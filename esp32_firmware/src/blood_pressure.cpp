#include "blood_pressure.h"
#include <math.h>

BloodPressureMonitor::BloodPressureMonitor() {
    // Initialize buffers
    for (int i = 0; i < BP_BUFFER_SIZE; i++) {
        ecgBuffer[i] = 0;
        ppgBuffer[i] = 0;
        ecgTimestamps[i] = 0;
        ppgTimestamps[i] = 0;
    }
    
    // Initialize filter buffers
    for (int i = 0; i < 10; i++) {
        ecgFilterBuffer[i] = 0;
        ppgFilterBuffer[i] = 0;
    }
    
    // Initialize peak arrays
    for (int i = 0; i < 20; i++) {
        ecgPeaks[i] = {0, 0, 0};
        ppgPeaks[i] = {0, 0, 0};
    }
    
    // Initialize RR intervals
    for (int i = 0; i < 50; i++) {
        rrIntervals[i] = 0;
    }
    
    // Initialize calibration points
    for (int i = 0; i < 5; i++) {
        calibrationPoints[i] = {0, 0, 0, 0};
    }
}

bool BloodPressureMonitor::begin() {
    Serial.println("🔄 Initializing Blood Pressure Monitor...");
    
    // Reset all buffers and counters
    reset();
    
    // Perform self-test
    if (!selfTest()) {
        Serial.println("❌ Blood Pressure Monitor self-test failed");
        return false;
    }
    
    Serial.println("✅ Blood Pressure Monitor initialized");
    Serial.println("📋 Need calibration with reference BP measurements");
    return true;
}

void BloodPressureMonitor::reset() {
    ecgBufferIndex = 0;
    ppgBufferIndex = 0;
    ecgPeakCount = 0;
    ppgPeakCount = 0;
    rrCount = 0;
    filterIndex = 0;
    lastValidReading = 0;
}

void BloodPressureMonitor::addECGSample(float ecgValue, unsigned long timestamp) {
    // Apply bandpass filter (0.5-40 Hz for ECG)
    float filteredECG = applyBandpassFilter(ecgFilterBuffer, ecgValue);
    
    updateECGBuffer(filteredECG, timestamp);
    
    // Detect R-peaks in ECG
    if (detectECGPeak(filteredECG, ecgBufferIndex)) {
        // Store peak information
        int peakIndex = ecgPeakCount % 20;
        ecgPeaks[peakIndex] = {ecgBufferIndex, filteredECG, timestamp};
        ecgPeakCount++;
        
        // Calculate R-R interval for HRV
        if (ecgPeakCount > 1) {
            int prevIndex = (ecgPeakCount - 2) % 20;
            float rrInterval = timestamp - ecgPeaks[prevIndex].timestamp;
            
            if (rrInterval > 300 && rrInterval < 2000) { // Valid RR interval (30-200 BPM)
                rrIntervals[rrCount % 50] = rrInterval;
                rrCount++;
            }
        }
    }
    
    // Adaptive threshold adjustment
    if (adaptiveThresholding) {
        adaptThresholds();
    }
}

void BloodPressureMonitor::addPPGSample(float irValue, float redValue, unsigned long timestamp) {
    // Use IR channel for pulse detection (more reliable for PTT)
    float ppgValue = irValue;
    
    // Apply bandpass filter (0.5-8 Hz for PPG)
    float filteredPPG = applyBandpassFilter(ppgFilterBuffer, ppgValue);
    
    updatePPGBuffer(filteredPPG, timestamp);
    
    // Detect pulse peaks in PPG
    if (detectPPGPeak(filteredPPG, ppgBufferIndex)) {
        // Store peak information
        int peakIndex = ppgPeakCount % 20;
        ppgPeaks[peakIndex] = {ppgBufferIndex, filteredPPG, timestamp};
        ppgPeakCount++;
    }
}

BloodPressureData BloodPressureMonitor::calculateBloodPressure() {
    BloodPressureData data = {0, 0, 0, 0, 0, 0, false, true, millis(), 0, 0, false};
    
    // Check if we have enough data
    if (ecgPeakCount < 3 || ppgPeakCount < 3) {
        Serial.println("⚠️ Insufficient peak data for BP calculation");
        return data;
    }
    
    // Calculate Pulse Transit Time
    float ptt = calculatePTT();
    if (ptt <= 0) {
        Serial.println("⚠️ Invalid PTT calculation");
        return data;
    }
    
    data.pulseTransitTime = ptt;
    data.pulseWaveVelocity = calculatePWV(ptt);
    
    // Calculate blood pressure using calibrated relationship
    if (calibrationCount > 0) {
        // Use calibrated linear relationship: BP = slope * PTT + intercept
        data.systolic = systolicSlope * ptt + systolicIntercept;
        data.diastolic = diastolicSlope * ptt + diastolicIntercept;
        data.needsCalibration = false;
    } else {
        // Use default relationship (less accurate)
        data.systolic = -1.2 * ptt + 180.0;  // Typical relationship
        data.diastolic = -0.8 * ptt + 120.0;
        data.needsCalibration = true;
    }
    
    // Apply personal compensation factors
    data.systolic = BPAnalysis::compensateForAge(data.systolic, userAge);
    data.systolic = BPAnalysis::compensateForGender(data.systolic, userIsMale);
    data.diastolic = BPAnalysis::compensateForAge(data.diastolic, userAge);
    data.diastolic = BPAnalysis::compensateForGender(data.diastolic, userIsMale);
    
    // Calculate Mean Arterial Pressure
    data.meanArterialPressure = data.diastolic + (data.systolic - data.diastolic) / 3.0;
    
    // Calculate Heart Rate Variability
    data.heartRateVariability = calculateHRV();
    
    // Assess signal quality
    data.signalQuality = assessSignalQuality();
    data.correlationCoeff = calculateCorrelation();
    data.rhythmRegular = checkRhythmRegularity();
    
    // Validate reading
    data.validReading = (data.signalQuality > 70.0 && 
                        data.systolic > 70 && data.systolic < 250 &&
                        data.diastolic > 40 && data.diastolic < 150 &&
                        data.pulseTransitTime > 50 && data.pulseTransitTime < 500);
    
    if (data.validReading) {
        lastValidReading = millis();
    }
    
    return data;
}

float BloodPressureMonitor::calculatePTT() {
    if (ecgPeakCount < 2 || ppgPeakCount < 2) {
        return -1;
    }
    
    float totalPTT = 0;
    int validPairs = 0;
    
    // Find matching ECG and PPG peaks within reasonable time window
    for (int i = max(0, ecgPeakCount - 10); i < ecgPeakCount; i++) {
        int ecgIndex = i % 20;
        unsigned long ecgTime = ecgPeaks[ecgIndex].timestamp;
        
        // Look for corresponding PPG peak within 50-400ms after ECG peak
        for (int j = max(0, ppgPeakCount - 10); j < ppgPeakCount; j++) {
            int ppgIndex = j % 20;
            unsigned long ppgTime = ppgPeaks[ppgIndex].timestamp;
            
            if (ppgTime > ecgTime && (ppgTime - ecgTime) >= 50 && (ppgTime - ecgTime) <= 400) {
                float ptt = ppgTime - ecgTime;
                totalPTT += ptt;
                validPairs++;
                break; // Take first valid match
            }
        }
    }
    
    if (validPairs > 0) {
        return totalPTT / validPairs;
    }
    
    return -1;
}

float BloodPressureMonitor::calculatePWV(float ptt) {
    // Pulse Wave Velocity = Distance / Time
    // Using estimated arterial path length based on height
    float pathLength = userHeight * 0.4; // Approximate path from heart to finger (cm)
    pathLength /= 100.0; // Convert to meters
    
    if (ptt > 0) {
        return pathLength / (ptt / 1000.0); // Convert PTT from ms to seconds
    }
    return 0;
}

float BloodPressureMonitor::calculateHRV() {
    if (rrCount < 10) {
        return 0;
    }
    
    // Calculate RMSSD (Root Mean Square of Successive Differences)
    float sumSquaredDiff = 0;
    int validDiffs = 0;
    
    for (int i = 1; i < min(rrCount, 50); i++) {
        float diff = rrIntervals[i] - rrIntervals[i-1];
        sumSquaredDiff += diff * diff;
        validDiffs++;
    }
    
    if (validDiffs > 0) {
        return sqrt(sumSquaredDiff / validDiffs);
    }
    return 0;
}

bool BloodPressureMonitor::detectECGPeak(float value, int index) {
    static float lastValue = 0;
    static float lastDerivative = 0;
    static bool risingEdge = false;
    static unsigned long lastPeakTime = 0;
    
    float derivative = value - lastValue;
    
    // Detect R-peak: positive peak above threshold with minimum interval
    if (value > ecgThreshold && derivative > 0 && lastDerivative <= 0) {
        risingEdge = true;
    }
    
    if (risingEdge && derivative < 0 && lastDerivative >= 0) {
        // Peak detected
        unsigned long currentTime = millis();
        if (currentTime - lastPeakTime > 300) { // Minimum 300ms between peaks
            lastPeakTime = currentTime;
            risingEdge = false;
            lastValue = value;
            lastDerivative = derivative;
            return true;
        }
        risingEdge = false;
    }
    
    lastValue = value;
    lastDerivative = derivative;
    return false;
}

bool BloodPressureMonitor::detectPPGPeak(float value, int index) {
    static float lastValue = 0;
    static float lastDerivative = 0;
    static bool risingEdge = false;
    static unsigned long lastPeakTime = 0;
    
    float derivative = value - lastValue;
    
    // Detect PPG peak: positive peak above threshold
    if (value > ppgThreshold && derivative > 0 && lastDerivative <= 0) {
        risingEdge = true;
    }
    
    if (risingEdge && derivative < 0 && lastDerivative >= 0) {
        // Peak detected
        unsigned long currentTime = millis();
        if (currentTime - lastPeakTime > 400) { // Minimum 400ms between peaks
            lastPeakTime = currentTime;
            risingEdge = false;
            lastValue = value;
            lastDerivative = derivative;
            return true;
        }
        risingEdge = false;
    }
    
    lastValue = value;
    lastDerivative = derivative;
    return false;
}

float BloodPressureMonitor::applyBandpassFilter(float* buffer, float newValue) {
    // Simple moving average filter for now
    // In production, use proper Butterworth or Chebyshev filter
    buffer[filterIndex] = newValue;
    filterIndex = (filterIndex + 1) % 10;
    
    float sum = 0;
    for (int i = 0; i < 10; i++) {
        sum += buffer[i];
    }
    return sum / 10.0;
}

float BloodPressureMonitor::assessSignalQuality() {
    float quality = 100.0;
    
    // Check signal stability
    if (ecgPeakCount < 5 || ppgPeakCount < 5) {
        quality -= 30;
    }
    
    // Check peak regularity
    if (!checkRhythmRegularity()) {
        quality -= 20;
    }
    
    // Check correlation between ECG and PPG
    int correlation = calculateCorrelation();
    if (abs(correlation) < 50) {
        quality -= 25;
    }
    
    // Check recent peak detection
    if (millis() - lastValidReading > 10000) {
        quality -= 25;
    }
    
    return max(0.0f, quality);
}

int BloodPressureMonitor::calculateCorrelation() {
    // Simplified correlation calculation
    // In production, use proper Pearson correlation coefficient
    if (ecgPeakCount < 3 || ppgPeakCount < 3) {
        return 0;
    }
    
    // For now, return high correlation if we have matching peaks
    return 85; // Placeholder - implement proper correlation
}

bool BloodPressureMonitor::checkRhythmRegularity() {
    if (rrCount < 5) {
        return false;
    }
    
    // Check if RR intervals are relatively consistent
    float mean = 0;
    for (int i = 0; i < min(rrCount, 10); i++) {
        mean += rrIntervals[i];
    }
    mean /= min(rrCount, 10);
    
    float variance = 0;
    for (int i = 0; i < min(rrCount, 10); i++) {
        float diff = rrIntervals[i] - mean;
        variance += diff * diff;
    }
    variance /= min(rrCount, 10);
    
    // Regular if standard deviation is less than 20% of mean
    return sqrt(variance) < (mean * 0.2);
}

bool BloodPressureMonitor::addCalibrationPoint(float systolic, float diastolic) {
    if (calibrationCount >= 5) {
        Serial.println("⚠️ Maximum calibration points reached");
        return false;
    }
    
    // Calculate current PTT
    float currentPTT = calculatePTT();
    if (currentPTT <= 0) {
        Serial.println("❌ Cannot calibrate: Invalid PTT");
        return false;
    }
    
    // Store calibration point
    calibrationPoints[calibrationCount] = {currentPTT, systolic, diastolic, millis()};
    calibrationCount++;
    
    // Update calibration relationship
    updateCalibration();
    
    Serial.printf("✅ Calibration point added: PTT=%.1fms, BP=%d/%d\n", 
                  currentPTT, (int)systolic, (int)diastolic);
    return true;
}

void BloodPressureMonitor::updateCalibration() {
    if (calibrationCount < 2) {
        return; // Need at least 2 points for linear regression
    }
    
    // Simple linear regression: BP = slope * PTT + intercept
    float sumX = 0, sumY_sys = 0, sumY_dia = 0;
    float sumXY_sys = 0, sumXY_dia = 0, sumX2 = 0;
    
    for (int i = 0; i < calibrationCount; i++) {
        float x = calibrationPoints[i].ptt;
        float y_sys = calibrationPoints[i].systolic;
        float y_dia = calibrationPoints[i].diastolic;
        
        sumX += x;
        sumY_sys += y_sys;
        sumY_dia += y_dia;
        sumXY_sys += x * y_sys;
        sumXY_dia += x * y_dia;
        sumX2 += x * x;
    }
    
    int n = calibrationCount;
    
    // Calculate slopes and intercepts
    systolicSlope = (n * sumXY_sys - sumX * sumY_sys) / (n * sumX2 - sumX * sumX);
    systolicIntercept = (sumY_sys - systolicSlope * sumX) / n;
    
    diastolicSlope = (n * sumXY_dia - sumX * sumY_dia) / (n * sumX2 - sumX * sumX);
    diastolicIntercept = (sumY_dia - diastolicSlope * sumX) / n;
    
    Serial.printf("📊 Calibration updated: Sys=%.3f*PTT+%.1f, Dia=%.3f*PTT+%.1f\n",
                  systolicSlope, systolicIntercept, diastolicSlope, diastolicIntercept);
}

void BloodPressureMonitor::adaptThresholds() {
    // Adaptive threshold adjustment based on signal statistics
    static unsigned long lastUpdate = 0;
    
    if (millis() - lastUpdate < 5000) { // Update every 5 seconds
        return;
    }
    
    // Calculate signal statistics
    float ecgMean = 0, ppgMean = 0;
    int samples = min(ecgBufferIndex, 50);
    
    for (int i = 0; i < samples; i++) {
        ecgMean += ecgBuffer[i];
        ppgMean += ppgBuffer[i];
    }
    
    if (samples > 0) {
        ecgMean /= samples;
        ppgMean /= samples;
        
        // Adjust thresholds to be 1.5x above mean
        ecgThreshold = ecgMean * 1.5;
        ppgThreshold = ppgMean * 1.5;
    }
    
    lastUpdate = millis();
}

void BloodPressureMonitor::updateECGBuffer(float value, unsigned long timestamp) {
    ecgBuffer[ecgBufferIndex] = value;
    ecgTimestamps[ecgBufferIndex] = timestamp;
    ecgBufferIndex = (ecgBufferIndex + 1) % BP_BUFFER_SIZE;
}

void BloodPressureMonitor::updatePPGBuffer(float value, unsigned long timestamp) {
    ppgBuffer[ppgBufferIndex] = value;
    ppgTimestamps[ppgBufferIndex] = timestamp;
    ppgBufferIndex = (ppgBufferIndex + 1) % BP_BUFFER_SIZE;
}

bool BloodPressureMonitor::isReadyForMeasurement() {
    return (ecgPeakCount >= 5 && ppgPeakCount >= 5 && 
            assessSignalQuality() > 60.0);
}

String BloodPressureMonitor::getSystemStatus() {
    String status = "BP Monitor: ";
    
    if (isReadyForMeasurement()) {
        status += "Ready";
    } else {
        status += "Not Ready";
    }
    
    status += " | ECG Peaks: " + String(ecgPeakCount);
    status += " | PPG Peaks: " + String(ppgPeakCount);
    status += " | Quality: " + String((int)assessSignalQuality()) + "%";
    status += " | Cal Points: " + String(calibrationCount) + "/5";
    
    return status;
}

bool BloodPressureMonitor::selfTest() {
    // Basic self-test
    return true; // Placeholder
}

void BloodPressureMonitor::printDiagnostics() {
    Serial.println("=== Blood Pressure Monitor Diagnostics ===");
    Serial.printf("ECG Peaks: %d, PPG Peaks: %d\n", ecgPeakCount, ppgPeakCount);
    Serial.printf("Signal Quality: %.1f%%\n", assessSignalQuality());
    Serial.printf("Calibration Points: %d/5\n", calibrationCount);
    Serial.printf("Current Thresholds: ECG=%.1f, PPG=%.1f\n", ecgThreshold, ppgThreshold);
    
    if (calibrationCount > 0) {
        Serial.printf("Calibration: Sys=%.3f*PTT+%.1f, Dia=%.3f*PTT+%.1f\n",
                      systolicSlope, systolicIntercept, diastolicSlope, diastolicIntercept);
    }
    
    Serial.println("==========================================");
}

void BloodPressureMonitor::setPersonalParameters(int age, float height, bool isMale) {
    // Store user profile for personalized BP calculations
    Serial.printf("📋 Personal parameters updated: Age=%d, Height=%.1fcm, Gender=%s\n",
                  age, height, isMale ? "Male" : "Female");
    
    // Adjust calibration based on personal parameters
    // These are simplified adjustments - real implementation would be more sophisticated
    if (age > 60) {
        systolicSlope *= 1.1f;  // Slightly adjust for older adults
        diastolicSlope *= 1.05f;
    }
    
    if (!isMale) {
        systolicIntercept -= 5;  // Slight adjustment for gender differences
        diastolicIntercept -= 3;
    }
    
    if (height > 180) {
        systolicIntercept += 3;  // Height adjustment
    } else if (height < 160) {
        systolicIntercept -= 3;
    }
}

// Utility functions
namespace BPAnalysis {
    float compensateForAge(float rawBP, int age) {
        // Age compensation: BP typically increases with age
        float ageFactor = 1.0 + (age - 30) * 0.005; // 0.5% per year after 30
        return rawBP * ageFactor;
    }
    
    float compensateForGender(float rawBP, bool isMale) {
        // Gender compensation: Males typically have slightly higher BP
        return rawBP * (isMale ? 1.02 : 1.0);
    }
    
    String interpretBPReading(float systolic, float diastolic) {
        if (systolic < 120 && diastolic < 80) {
            return "Normal";
        } else if (systolic < 130 && diastolic < 80) {
            return "Elevated";
        } else if (systolic < 140 || diastolic < 90) {
            return "Stage 1 Hypertension";
        } else if (systolic < 180 || diastolic < 120) {
            return "Stage 2 Hypertension";
        } else {
            return "Hypertensive Crisis";
        }
    }
    
    bool isHypertensive(float systolic, float diastolic) {
        return (systolic >= 130 || diastolic >= 80);
    }
    
    float calculatePulsePressure(float systolic, float diastolic) {
        return systolic - diastolic;
    }
}
