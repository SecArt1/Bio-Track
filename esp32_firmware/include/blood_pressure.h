#ifndef BLOOD_PRESSURE_H
#define BLOOD_PRESSURE_H

#include <Arduino.h>

// Forward declaration to avoid circular dependency
struct SensorReadings;

// Blood pressure estimation using Pulse Transit Time (PTT)
// PTT = Time difference between ECG R-peak and PPG pulse arrival

struct BloodPressureData {
    float systolic;          // Systolic pressure (mmHg)
    float diastolic;         // Diastolic pressure (mmHg)
    float meanArterialPressure; // MAP (mmHg)
    float pulseTransitTime;  // PTT in milliseconds
    float pulseWaveVelocity; // PWV in m/s
    float heartRateVariability; // HRV (RMSSD)
    bool validReading;
    bool needsCalibration;
    unsigned long timestamp;
    
    // Quality metrics
    float signalQuality;     // Overall signal quality (0-100%)
    int correlationCoeff;    // ECG-PPG correlation (-100 to +100)
    bool rhythmRegular;      // Heart rhythm regularity
};

struct CalibrationPoint {
    float ptt;              // Measured PTT
    float systolic;         // Reference systolic BP
    float diastolic;        // Reference diastolic BP
    unsigned long timestamp;
};

class BloodPressureMonitor {
private:
    // Calibration data
    CalibrationPoint calibrationPoints[5]; // Store up to 5 calibration points
    int calibrationCount = 0;
    float systolicSlope = -1.2;    // Default PTT-BP relationship
    float systolicIntercept = 180.0;
    float diastolicSlope = -0.8;
    float diastolicIntercept = 120.0;
      // Signal processing buffers
    static const int BP_BUFFER_SIZE = 200;
    static const int ECG_SAMPLE_RATE = 200; // 200 Hz
    static const int PPG_SAMPLE_RATE = 100; // 100 Hz
    
    // ECG processing
    float ecgBuffer[BP_BUFFER_SIZE];
    int ecgBufferIndex = 0;
    unsigned long ecgTimestamps[BP_BUFFER_SIZE];
    
    // PPG processing  
    float ppgBuffer[BP_BUFFER_SIZE];
    int ppgBufferIndex = 0;
    unsigned long ppgTimestamps[BP_BUFFER_SIZE];
    
    // Peak detection
    struct Peak {
        int index;
        float value;
        unsigned long timestamp;
    };
    
    Peak ecgPeaks[20];      // Store last 20 ECG R-peaks
    Peak ppgPeaks[20];      // Store last 20 PPG peaks
    int ecgPeakCount = 0;
    int ppgPeakCount = 0;
    
    // Heart rate variability
    float rrIntervals[50];   // R-R intervals for HRV
    int rrCount = 0;
    
    // Adaptive thresholds
    float ecgThreshold = 1500;
    float ppgThreshold = 50000;
    bool adaptiveThresholding = true;
    
    // Quality assessment
    float lastSignalQuality = 0;
    unsigned long lastValidReading = 0;
    
    // Advanced filtering
    float ecgFilterBuffer[10];
    float ppgFilterBuffer[10];
    int filterIndex = 0;
    
    // Methods
    void updateECGBuffer(float value, unsigned long timestamp);
    void updatePPGBuffer(float value, unsigned long timestamp);
    
    bool detectECGPeak(float value, int index);
    bool detectPPGPeak(float value, int index);
    
    float calculatePTT();
    float calculatePWV(float ptt);
    float calculateHRV();
    float assessSignalQuality();
    int calculateCorrelation();
    bool checkRhythmRegularity();
    
    float applyBandpassFilter(float* buffer, float newValue);
    void adaptThresholds();
    void updateCalibration();
    
    // Machine learning-inspired features
    float extractPPGFeatures();
    float extractECGFeatures();
    float calculateVascularCompliance();
    
public:
    BloodPressureMonitor();
    
    // Initialization
    bool begin();
    void reset();
    
    // Data input (called from sensor readings)
    void addECGSample(float ecgValue, unsigned long timestamp);
    void addPPGSample(float irValue, float redValue, unsigned long timestamp);
    
    // Main processing
    BloodPressureData calculateBloodPressure();
    bool isReadyForMeasurement();
    
    // Calibration
    bool addCalibrationPoint(float systolic, float diastolic);
    bool performAutoCalibration();  // Using statistical methods
    void clearCalibration();
    int getCalibrationCount() { return calibrationCount; }
    
    // Advanced features
    float estimateArterialStiffness();
    float calculateCardiacOutput();
    String getVascularHealthIndex();
    
    // Configuration
    void setAdaptiveMode(bool enable) { adaptiveThresholding = enable; }
    void setSampleRates(int ecgRate, int ppgRate);
    void setPersonalParameters(int age, float height, bool isMale);
    
    // Diagnostics
    String getSystemStatus();
    void printDiagnostics();
    bool selfTest();
    
    // Age and gender compensation
    int userAge = 30;
    float userHeight = 170.0; // cm
    bool userIsMale = true;
};

// Utility functions for BP analysis
namespace BPAnalysis {
    float compensateForAge(float rawBP, int age);
    float compensateForGender(float rawBP, bool isMale);
    String interpretBPReading(float systolic, float diastolic);
    bool isHypertensive(float systolic, float diastolic);
    float calculatePulsePressure(float systolic, float diastolic);
}

#endif // BLOOD_PRESSURE_H
