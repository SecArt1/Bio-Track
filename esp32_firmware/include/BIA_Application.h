#ifndef _BIA_APPLICATION_H_
#define _BIA_APPLICATION_H_

#include "AD5940.h"

// BIA measurement configuration
typedef struct {
    float StartFreq;        // Start frequency in Hz
    float EndFreq;          // End frequency in Hz
    uint32_t NumOfPoints;   // Number of frequency points
    float ExcitVolt;        // Excitation voltage in mV
    bool SweepEnable;       // Enable frequency sweep
} BIAConfig;

// BIA measurement result
typedef struct {
    float Frequency;
    float Magnitude;
    float Phase;
    float Resistance;
    float Reactance;
    uint32_t Timestamp;
    bool Valid;
} BIAResult;

class BIAApplication {
public:
    BIAApplication();
    
    // Configuration
    bool initialize(int csPin, int resetPin = -1, int intPin = -1);
    bool configure(const BIAConfig& config);
    
    // Measurement control
    bool startMeasurement();
    bool stopMeasurement();
    bool isMeasuring();
    
    // Data acquisition
    bool getResult(BIAResult& result);
    bool performSingleMeasurement(float frequency, BIAResult& result);
    bool performFrequencySweep(BIAResult* results, uint32_t maxResults, uint32_t* actualCount);
    
    // Calibration
    bool calibrate(float knownResistance = 1000.0f);
    bool setCalibrationFactors(float gainFactor, float phaseOffset);
    
    // Status and diagnostics
    String getStatus();
    bool selfTest();
    
private:
    BIAConfig _config;
    bool _initialized;
    bool _measuring;
    float _calibrationGain;
    float _calibrationPhase;
    uint32_t _currentFreqIndex;
    
    bool setFrequency(float frequency);
    bool waitForResult(uint32_t timeoutMs = 1000);
    void processRawData(uint32_t realData, uint32_t imagData, BIAResult& result);
};

#endif // _BIA_APPLICATION_H_
