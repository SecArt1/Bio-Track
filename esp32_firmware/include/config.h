#ifndef CONFIG_H
#define CONFIG_H

// WiFi Configuration
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"
#define WIFI_CONNECT_TIMEOUT 30000
#define WIFI_RECONNECT_INTERVAL 5000

// Firebase Configuration
#define FIREBASE_PROJECT_ID "bio-track-de846"
#define FIREBASE_API_KEY "YOUR_FIREBASE_API_KEY"
#define FIREBASE_HOST "bio-track-de846-default-rtdb.firebaseio.com"
#define FIREBASE_FUNCTIONS_URL "https://us-central1-bio-track-de846.cloudfunctions.net"

// MQTT Configuration
#define MQTT_SERVER "bio-track-de846-default-rtdb.firebaseio.com"
#define MQTT_PORT 443
#define MQTT_USERNAME ""
#define MQTT_PASSWORD ""

// Security Configuration
#define USE_TLS_ENCRYPTION true
#define VERIFY_FIREBASE_CERT true
#define NVS_ENCRYPTION_KEY "biotrack_nvs_key_2024"

// Cloud Endpoints
#define SENSOR_DATA_ENDPOINT "/receiveSensorData"
#define HEARTBEAT_ENDPOINT "/deviceHeartbeat"
#define ALERT_ENDPOINT "/processAlert"
#define OTA_UPDATE_ENDPOINT "/checkOTAUpdate"

// MQTT-over-HTTP Configuration
#define MQTT_SIMULATION_PORT 443
#define DEVICE_TOPIC_PREFIX "devices"
#define MQTT_KEEPALIVE_INTERVAL 60000

// Device Configuration
#define DEVICE_ID "biotrack_device_001"
#define FIRMWARE_VERSION "1.0.0"
#define LED_BUILTIN 2  // ESP32 built-in LED pin

// Sensor Pin Definitions
// MAX30102 Heart Rate & SpO2 (I2C Bus 0)
#define MAX30102_SDA_PIN 21
#define MAX30102_SCL_PIN 22

// MAX30102 Glucose Monitor (I2C Bus 1) 
#define GLUCOSE_SDA_PIN 16
#define GLUCOSE_SCL_PIN 17

// DS18B20 Temperature (OneWire)
#define DS18B20_PIN 15  // Updated to match user's configuration
#define ONE_WIRE_BUS DS18B20_PIN  // Alias for compatibility

// HX711 Load Cell (Digital)
#define LOAD_CELL_DOUT_PIN 5
#define LOAD_CELL_SCK_PIN 18

// AD5941 Bioimpedance (SPI) - Updated to avoid pin conflict with DS18B20
#define AD5941_CS_PIN 26    // Changed from 15 to avoid conflict with DS18B20
#define AD5941_MOSI_PIN 23
#define AD5941_MISO_PIN 19
#define AD5941_SCK_PIN 14  // Changed from 18 to avoid conflict
#define AD5941_RESET_PIN 2
#define AD5941_INT_PIN 27

// AD8232 ECG Sensor (Analog + Digital)
#define ECG_PIN 34
#define LO_PLUS_PIN 32
#define LO_MINUS_PIN 33

// Measurement Intervals (milliseconds)
#define HEART_RATE_INTERVAL 5000    // 5 seconds
#define TEMPERATURE_INTERVAL 5000   // 5 seconds (updated for faster DS18B20 readings)
#define WEIGHT_INTERVAL 2000        // 2 seconds
#define BIOIMPEDANCE_INTERVAL 15000 // 15 seconds
#define ECG_INTERVAL 5000           // 5 seconds
#define GLUCOSE_INTERVAL 10000      // 10 seconds

// Glucose Monitor Configuration
#define GLUCOSE_WINDOW_SIZE 10
#define GLUCOSE_INTERCEPT 245.2846
#define GLUCOSE_IR_COEF -0.00534
#define GLUCOSE_RED_COEF 0.00312
#define GLUCOSE_RATIO_COEF -82.85
#define GLUCOSE_MIN_SIGNAL 10000
#define GLUCOSE_MAX_SIGNAL 150000
#define GLUCOSE_STABILITY_THRESHOLD 10.0  // % variation

// Data Buffer Sizes
#define MAX_BUFFER_SIZE 10
#define JSON_BUFFER_SIZE 2048

// OTA Configuration
#define OTA_HOSTNAME "biotrack-device"
#define OTA_PASSWORD "biotrack_ota_2024"

// Calibration Values
#define LOAD_CELL_CALIBRATION_FACTOR 2280.0
#define WEIGHT_OFFSET 0.0

// Alert Thresholds
#define MAX_HEART_RATE 180
#define MIN_HEART_RATE 40
#define MAX_TEMPERATURE 39.0
#define MIN_TEMPERATURE 35.0

// Debug Configuration
#define DEBUG_ENABLED true
#define SERIAL_BAUD_RATE 115200

#endif // CONFIG_H
