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

// Sensor Pin Definitions - ESP32 WROOM-32 Optimized
// MAX30102 Heart Rate & SpO2 (I2C Bus 0)
#define MAX30102_SDA_PIN 21      // I2C0 SDA (default)
#define MAX30102_SCL_PIN 22      // I2C0 SCL (default)

// MAX30102 Glucose Monitor (I2C Bus 1) 
#define GLUCOSE_SDA_PIN 13       // GPIO13 (WROOM-32 safe)
#define GLUCOSE_SCL_PIN 14       // GPIO14 (WROOM-32 safe)

// DS18B20 Temperature (OneWire)
#define DS18B20_PIN 4            // GPIO4 (WROOM-32 safe)
#define ONE_WIRE_BUS DS18B20_PIN

// HX711 Load Cell (Digital)
#define LOAD_CELL_DOUT_PIN 16    // GPIO16 (WROOM-32 safe)
#define LOAD_CELL_SCK_PIN 17     // GPIO17 (WROOM-32 safe)

// AD5941 Bioimpedance (SPI)
#define AD5941_CS_PIN 5          // GPIO5 (WROOM-32 safe)
#define AD5941_MOSI_PIN 23       // GPIO23 (default SPI MOSI)
#define AD5941_MISO_PIN 19       // GPIO19 (default SPI MISO)
#define AD5941_SCK_PIN 18        // GPIO18 (default SPI SCK)
#define AD5941_RESET_PIN 25      // GPIO25 (WROOM-32 safe)
#define AD5941_INT_PIN 26        // GPIO26 (WROOM-32 safe)

// AD8232 ECG Sensor (Analog + Digital)
#define ECG_PIN 36               // GPIO36 (input-only, ADC1_CH0)
#define LO_PLUS_PIN 32           // GPIO32 (WROOM-32 safe, ADC1_CH4)
#define LO_MINUS_PIN 33          // GPIO33 (WROOM-32 safe, ADC1_CH5)

// Blood Pressure Monitor pins (virtual/software implementation)
#define BP_ENABLE_PIN 27         // GPIO27 (WROOM-32 safe)
#define BP_PUMP_PIN 12           // GPIO12 (avoid boot conflicts in production)

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

// WROOM-32 Memory Optimization
#define TASK_STACK_SIZE_SMALL 2048    // For light tasks
#define TASK_STACK_SIZE_MEDIUM 3072   // For sensor tasks
#define TASK_STACK_SIZE_LARGE 4096    // For heavy tasks

// Alert Thresholds
#define MAX_HEART_RATE 180
#define MIN_HEART_RATE 40
#define MAX_TEMPERATURE 39.0
#define MIN_TEMPERATURE 35.0

// Debug Configuration
#define DEBUG_ENABLED true
#define SERIAL_BAUD_RATE 115200

// WROOM-32 Board Validation Function
inline bool isValidWROOMPin(int pin) {
    // Unusable pins on WROOM-32
    if (pin >= 6 && pin <= 11) return false;  // Connected to flash
    
    // Input-only pins (can only be used for input)
    if (pin == 34 || pin == 35 || pin == 36 || pin == 39) {
        return true;  // Valid for input only
    }
    
    // Boot-sensitive pins (use with caution)
    if (pin == 0 || pin == 2 || pin == 12 || pin == 15) {
        return true;  // Valid but boot sensitive
    }
    
    // Standard GPIO pins
    if ((pin >= 1 && pin <= 5) || 
        (pin >= 12 && pin <= 19) || 
        (pin >= 21 && pin <= 23) || 
        (pin >= 25 && pin <= 27) || 
        (pin >= 32 && pin <= 33)) {
        return true;
    }
    
    return false;
}

#endif // CONFIG_H
