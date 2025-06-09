#ifndef SENSORS_H
#define SENSORS_H

#include <Arduino.h>
#include <Wire.h>
#include <SPI.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <HX711.h>
#include "MAX30105.h"
#include "heartRate.h"
#include "spo2_algorithm.h"
#include "BIA_Application.h"
#include "blood_pressure.h"  // Add blood pressure monitor
#include "config.h"

// Sensor data structures
struct HeartRateData {
    float heartRate;
    float spO2;
    bool validReading;
    unsigned long timestamp;
};

struct TemperatureData {
    float temperature;
    bool validReading;
    unsigned long timestamp;
};

struct WeightData {
    float weight;
    bool validReading;
    bool stable;
    unsigned long timestamp;
};

struct BioimpedanceData {
    float resistance;
    float reactance;
    float impedance;
    float phase;
    float frequency;        // Add frequency
    bool validReading;
    unsigned long timestamp;
};

struct ECGData {
    float avgFilteredValue;
    int avgBPM;
    int peakCount;
    bool validReading;
    bool leadOff;           // Lead-off detection
    unsigned long timestamp;
};

struct GlucoseData {
    float glucoseLevel;     // mg/dL
    float irValue;
    float redValue;    float ratio;            // Red/IR ratio
    float signalQuality;    // Signal variation percentage
    bool validReading;
    bool stable;           // Signal stability
    unsigned long timestamp;
};

struct SensorReadings {
    HeartRateData heartRate;
    TemperatureData temperature;
    WeightData weight;
    BioimpedanceData bioimpedance;
    ECGData ecg;
    GlucoseData glucose;
    BloodPressureData bloodPressure;  // Add blood pressure data
    unsigned long systemTimestamp;
};

class SensorManager {
private:    // Sensor objects
    MAX30105 heartRateSensor;
    MAX30105 glucoseSensor;     // Second MAX30105 for glucose monitoring
    OneWire oneWire;
    DallasTemperature temperatureSensor;
    HX711 loadCell;
    BIAApplication biaApp;  // Add BIA Application
    BloodPressureMonitor bpMonitor;  // Add blood pressure monitor
    
    // Data buffers
    uint32_t irBuffer[100];
    uint32_t redBuffer[100];
    
    // Glucose monitoring buffers
    float glucoseIrReadings[GLUCOSE_WINDOW_SIZE];
    float glucoseRedReadings[GLUCOSE_WINDOW_SIZE];
    int glucoseReadIndex = 0;
    uint32_t glucoseMaxIR = 0;
    uint32_t glucoseMinIR = UINT32_MAX;
    uint32_t glucoseMaxRed = 0;
    uint32_t glucoseMinRed = UINT32_MAX;
    uint32_t glucoseLastReading = 0;
      // Calibration values
    float weightOffset = WEIGHT_OFFSET;
    float weightCalibrationFactor = LOAD_CELL_CALIBRATION_FACTOR;
    float temperatureOffset = 5.0;  // DS18B20 calibration offset in °C
    
    // State variables
    bool heartRateInitialized = false;
    bool temperatureInitialized = false;
    bool weightInitialized = false;
    bool bioimpedanceInitialized = false;
    bool ecgInitialized = false;
    bool glucoseInitialized = false;
    bool bpMonitorInitialized = false;  // Add BP monitor state
    
    // ECG specific variables
    static const int ECG_FILTER_SIZE = 10;
    int ecgBuffer[ECG_FILTER_SIZE];
    int ecgBufferIndex = 0;
    unsigned long lastPeakTime = 0;
    int ecgThreshold = 1500;
    int currentBPM = 0;
    
    // Helper methods
    bool initializeHeartRateSensor();
    bool initializeTemperatureSensor();
    bool initializeWeightSensor();
    bool initializeBioimpedanceSensor();
    bool initializeECGSensor();
    bool initializeGlucoseSensor();
    bool initializeBloodPressureMonitor();  // Add BP monitor initialization
    
    HeartRateData readHeartRateAndSpO2();
    TemperatureData readTemperature();
    WeightData readWeight();
    BioimpedanceData readBioimpedance();
    ECGData readECG();
    GlucoseData readGlucose();
    BloodPressureData readBloodPressure();  // Add BP reading method
      bool validateHeartRateReading(float heartRate, float spO2);
    bool validateTemperatureReading(float temperature);
    bool validateWeightReading(float weight);
    bool validateBioimpedanceReading(float impedance);
    bool validateECGReading(float avgBPM, float avgFiltered);
    bool validateGlucoseReading(float glucose, float signalQuality);
    bool validateBloodPressureReading(float systolic, float diastolic);  // Add blood pressure validation
      // Glucose helper methods
    float calculateGlucoseMovingAverage(float* readings, float newValue);
    float calculateGlucoseLevel(float ir, float red);

public:
    SensorManager();
    
    // Initialization
    bool begin();
    void reset();
    
    // Calibration
    void calibrateWeight(float knownWeight);
    void tareWeight();
    bool calibrateBioimpedance(float knownResistance = 1000.0f);  // Add BIA calibration
    bool calibrateBloodPressure(float systolic, float diastolic);  // Add BP calibration
    void setUserProfile(int age, float height, bool isMale);  // Add user profile for BP
    void setTemperatureOffset(float offset);  // Add temperature calibration method
    float getTemperatureOffset();  // Get current temperature offset
    
    // Reading methods
    SensorReadings readAllSensors();
    HeartRateData readHeartRate();
    TemperatureData getTemperature();
    WeightData getWeight();
    BioimpedanceData getBioimpedance();
    ECGData getECG();
    GlucoseData getGlucose();
    BloodPressureData getBloodPressure();  // Add BP getter method
    
    // Status methods
    bool isHeartRateReady();
    bool isTemperatureReady();
    bool isWeightReady();
    bool isBioimpedanceReady();
    bool isECGReady();
    bool isGlucoseReady();
    bool isBloodPressureReady();  // Add BP status method
    bool allSensorsReady();
      // BIA specific functions
    bool performBIASweep(BIAResult* results, unsigned int maxResults, unsigned int* actualCount);
    String getBIAStatus();
    
    // Utility methods
    String getSensorStatus();
    void printSensorReadings(const SensorReadings& readings);
    
    // DS18B20 specific test and debug methods
    void testDS18B20();  // Standalone DS18B20 test function
};

// Global utility function
void displaySensorReadings(const SensorReadings& readings);

#endif // SENSORS_H
