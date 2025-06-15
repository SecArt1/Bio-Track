#ifndef AWS_IOT_MAIN_H
#define AWS_IOT_MAIN_H

// AWS IoT Core integration functions
void setupAWSIoT();
void loopAWSIoT();

// AWS IoT utility functions
void connectToAWSIoT();
void configureAWSIoT();
void syncToAWS();

// AWS IoT device management
void publishSensorData(String sensorType, float value, String unit, JsonObject metadata);
void publishDeviceStatus(String status);
void updateDeviceShadow();

// Sensor reading functions (implement based on your hardware)
float readTemperatureSensor();
float readWeightSensor();
float readBioimpedanceSensor();
float readSpO2Sensor();
int readHeartRateSensor();

#endif // AWS_IOT_MAIN_H
