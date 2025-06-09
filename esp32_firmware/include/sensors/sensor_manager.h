#ifndef SENSORS_SENSOR_MANAGER_H
#define SENSORS_SENSOR_MANAGER_H

#include <Wire.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <HX711.h>
#include "MAX30105.h"
#include "heartRate.h"
#include "spo2_algorithm.h"
#include "AD5940.h"
#include "BIA_Application.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "freertos/semphr.h"
#include "config.h"

// Sensor data structures
struct HeartRateData {
    float heartRate;
    float spO2;
    bool validReading;
    bool fingerDetected;
    uint32_t timestamp;
    uint32_t irValue;
    uint32_t redValue;
};

struct TemperatureData {
    float temperature;
    bool validReading;
    uint32_t timestamp;
    float previousReading;
    bool sensorConnected;
};

struct WeightData {
    float weight;
    bool validReading;
    bool stable;
    uint32_t timestamp;
    float rawValue;
    uint8_t stabilityCount;
};

struct BioimpedanceData {
    float resistance;
    float reactance;
    float impedance;
    float phase;
    float frequency;
    bool validReading;
    uint32_t timestamp;
    uint16_t measurementCount;
};

struct SensorReadings {
    HeartRateData heartRate;
    TemperatureData temperature;
    WeightData weight;
    BioimpedanceData bioimpedance;
    uint32_t systemTimestamp;
    String deviceID;
    float batteryVoltage;
    int wifiRSSI;
};

// Task-safe sensor manager with FreeRTOS integration
class TaskSafeSensorManager {
private:
    // Hardware interfaces
    MAX30105 heartRateSensor;
    OneWire oneWire;
    DallasTemperature temperatureSensor;
    HX711 loadCell;
    BIAApplication biaApp;
    
    // Task handles
    TaskHandle_t heartRateTaskHandle;
    TaskHandle_t temperatureTaskHandle;
    TaskHandle_t weightTaskHandle;
    TaskHandle_t bioimpedanceTaskHandle;
    TaskHandle_t aggregatorTaskHandle;
    
    // Queues for sensor data
    QueueHandle_t heartRateQueue;
    QueueHandle_t temperatureQueue;
    QueueHandle_t weightQueue;
    QueueHandle_t bioimpedanceQueue;
    QueueHandle_t aggregatedDataQueue;
    
    // Mutexes for thread safety
    SemaphoreHandle_t i2cMutex;
    SemaphoreHandle_t spiMutex;
    SemaphoreHandle_t dataAccessMutex;
    
    // Initialization flags
    bool heartRateInitialized;
    bool temperatureInitialized;
    bool weightInitialized;
    bool bioimpedanceInitialized;
    bool tasksStarted;
    
    // Calibration data
    float weightCalibrationFactor;
    float temperatureOffset;
    bool bioimpedanceCalibrated;
    
    // Sensor buffers for SpO2 calculation
    uint32_t irBuffer[100];
    uint32_t redBuffer[100];
    
    // Configuration
    static const size_t QUEUE_SIZE = 10;
    static const uint32_t HEART_RATE_SAMPLE_RATE = 100; // Hz
    static const uint32_t TEMPERATURE_INTERVAL = 5000;  // ms
    static const uint32_t WEIGHT_INTERVAL = 2000;       // ms
    static const uint32_t BIA_INTERVAL = 15000;         // ms
    
public:
    TaskSafeSensorManager();
    ~TaskSafeSensorManager();
    
    // Initialization
    bool begin();
    bool startSensorTasks();
    bool stopSensorTasks();
    
    // Individual sensor initialization
    bool initializeHeartRateSensor();
    bool initializeTemperatureSensor();
    bool initializeWeightSensor();
    bool initializeBioimpedanceSensor();
    
    // Data access (thread-safe)
    bool getLatestReadings(SensorReadings& readings, uint32_t timeoutMs = 100);
    bool getAggregatedData(SensorReadings& readings, uint32_t timeoutMs = 1000);
    
    // Calibration
    bool calibrateWeight(float knownWeight);
    bool calibrateTemperature(float knownTemperature);
    bool calibrateBioimpedance(float knownResistance);
    bool performBIASweep(BIAResult* results, uint32_t maxResults, uint32_t* actualCount);
    
    // Diagnostics and status
    String getSensorStatus();
    String getBIAStatus();
    bool allSensorsReady();
    void printSensorReadings(const SensorReadings& readings);
    
    // Error handling and recovery
    bool resetSensor(uint8_t sensorType);
    void handleSensorError(uint8_t sensorType, const String& error);
    
    // Power management
    bool enterLowPowerMode();
    bool exitLowPowerMode();
    
private:
    // Static task functions
    static void heartRateTask(void* parameter);
    static void temperatureTask(void* parameter);
    static void weightTask(void* parameter);
    static void bioimpedanceTask(void* parameter);
    static void dataAggregatorTask(void* parameter);
    
    // Sensor reading methods
    HeartRateData readHeartRateAndSpO2();
    TemperatureData readTemperature();
    WeightData readWeight();
    BioimpedanceData readBioimpedance();
    
    // Validation methods
    bool validateHeartRateReading(const HeartRateData& data);
    bool validateTemperatureReading(const TemperatureData& data);
    bool validateWeightReading(const WeightData& data);
    bool validateBioimpedanceReading(const BioimpedanceData& data);
    
    // Utility methods
    void calculateSpO2AndHeartRate(uint32_t* irBuffer, uint32_t* redBuffer, 
                                   int32_t bufferLength, int32_t* spo2, 
                                   int8_t* validSPO2, int32_t* heartRate, 
                                   int8_t* validHeartRate);
    float filterTemperature(float newReading, float previousReading);
    bool isWeightStable(float* readings, size_t count);
    
    // Mutex helpers
    bool takeMutex(SemaphoreHandle_t mutex, uint32_t timeoutMs = 100);
    void giveMutex(SemaphoreHandle_t mutex);
};

// Sensor type definitions for error handling
enum SensorType {
    SENSOR_HEART_RATE = 0,
    SENSOR_TEMPERATURE = 1,
    SENSOR_WEIGHT = 2,
    SENSOR_BIOIMPEDANCE = 3
};

#endif // SENSORS_SENSOR_MANAGER_H
