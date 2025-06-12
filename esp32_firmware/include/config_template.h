#ifndef CONFIG_TEMPLATE_H
#define CONFIG_TEMPLATE_H

// =============================================================================
// BioTrack ESP32 Health Monitoring System - Configuration Template
// Copy this file to config.h and update with your actual values
// =============================================================================

// WiFi Configuration
#define WIFI_SSID "YOUR_WIFI_NETWORK_NAME"         // Replace with your WiFi SSID
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"         // Replace with your WiFi password
#define WIFI_CONNECT_TIMEOUT 30000                 // 30 seconds timeout
#define WIFI_RECONNECT_INTERVAL 5000               // 5 seconds between retries
#define WIFI_MAX_RECONNECT_ATTEMPTS 10             // Maximum reconnection attempts

// Firebase Configuration
#define FIREBASE_PROJECT_ID "bio-track-de846"
#define FIREBASE_API_KEY "AIzaSyB-hR5VlFqSJ4j9mxJphf9V1NXMRJfZCRE"  // Android API key
#define FIREBASE_HOST "bio-track-de846-default-rtdb.firebaseio.com"
#define FIREBASE_FUNCTIONS_URL "https://us-central1-bio-track-de846.cloudfunctions.net"
#define FIREBASE_FIRESTORE_URL "https://firestore.googleapis.com/v1/projects/bio-track-de846/databases/(default)/documents"

// Device Configuration
#define DEVICE_ID "biotrack_device_001"            // Unique device identifier
#define DEVICE_NAME "BioTrack Health Monitor"      // Human-readable device name
#define FIRMWARE_VERSION "1.0.0"                  // Current firmware version
#define HARDWARE_VERSION "1.0"                    // Hardware revision

// Security Configuration
#define USE_TLS_ENCRYPTION true
#define VERIFY_FIREBASE_CERT true
#define NVS_ENCRYPTION_KEY "biotrack_nvs_key_2024" // Encryption key for local storage
#define OTA_PASSWORD "biotrack_ota_secure_2024"    // OTA update password

// Network Endpoints
#define SENSOR_DATA_ENDPOINT "/receiveSensorData"
#define HEARTBEAT_ENDPOINT "/deviceHeartbeat"
#define ALERT_ENDPOINT "/processAlert"
#define OTA_UPDATE_ENDPOINT "/checkOTAUpdate"

// Pin Definitions (ESP32 DevKit V1 Compatible)
// =============================================================================
// Built-in LED
#define LED_BUILTIN 2

// MAX30102 Heart Rate & SpO2 Sensor (I2C)
#define MAX30102_SDA_PIN 21
#define MAX30102_SCL_PIN 22
#define MAX30102_INT_PIN 39  // Interrupt pin (optional)

// DS18B20 Temperature Sensor (OneWire)
#define DS18B20_PIN 4
#define ONE_WIRE_BUS DS18B20_PIN

// HX711 Load Cell Amplifier (Digital)
#define LOAD_CELL_DOUT_PIN 16
#define LOAD_CELL_SCK_PIN 17

// AD5941 Bioimpedance Analyzer (SPI)
#define AD5941_CS_PIN 5
#define AD5941_MOSI_PIN 23
#define AD5941_MISO_PIN 19
#define AD5941_SCK_PIN 18
#define AD5941_RESET_PIN 25
#define AD5941_INT_PIN 26

// AD8232 ECG Sensor (Analog + Digital)
#define ECG_ANALOG_PIN 36     // VP pin - ECG signal input
#define LO_PLUS_PIN 32        // Lead-off detection positive
#define LO_MINUS_PIN 33       // Lead-off detection negative

// Additional I2C Bus for Glucose Monitor (if needed)
#define GLUCOSE_SDA_PIN 13
#define GLUCOSE_SCL_PIN 14

// Status LEDs (optional)
#define STATUS_LED_WIFI 27    // WiFi connection status
#define STATUS_LED_CLOUD 12   // Cloud connection status

// Measurement Intervals (milliseconds)
// =============================================================================
#define HEART_RATE_INTERVAL 2000      // 2 seconds - for real-time monitoring
#define TEMPERATURE_INTERVAL 5000     // 5 seconds - temperature changes slowly
#define WEIGHT_INTERVAL 1000          // 1 second - for accurate weight readings
#define BIOIMPEDANCE_INTERVAL 10000   // 10 seconds - power-intensive measurement
#define ECG_INTERVAL 1000             // 1 second - for ECG signal
#define GLUCOSE_INTERVAL 30000        // 30 seconds - non-invasive estimation

// Data Transmission Settings
#define CLOUD_UPLOAD_INTERVAL 5000    // 5 seconds - batch upload interval
#define HEARTBEAT_INTERVAL 60000      // 1 minute - device heartbeat
#define OFFLINE_BUFFER_SIZE 50        // Number of readings to buffer offline

// Sensor Calibration Values
// =============================================================================
// Load Cell Calibration (adjust based on your specific load cell)
#define LOAD_CELL_CALIBRATION_FACTOR 2280.0  // Calibration factor
#define WEIGHT_OFFSET 0.0                     // Zero offset
#define WEIGHT_SMOOTHING_FACTOR 0.1           // Low-pass filter coefficient

// Temperature Calibration
#define TEMPERATURE_OFFSET 0.0                // Temperature offset correction
#define TEMPERATURE_RESOLUTION 12             // DS18B20 resolution (9-12 bits)

// Heart Rate Calibration
#define HR_SAMPLE_RATE 100                    // MAX30102 sample rate (Hz)
#define HR_LED_CURRENT 50                     // LED current (mA)
#define HR_PULSE_WIDTH 400                    // Pulse width (μs)

// Health Alert Thresholds
// =============================================================================
#define HEART_RATE_MIN 50                     // Minimum safe heart rate (BPM)
#define HEART_RATE_MAX 150                    // Maximum safe heart rate (BPM)
#define TEMPERATURE_MIN 35.0                  // Minimum safe temperature (°C)
#define TEMPERATURE_MAX 38.5                  // Maximum safe temperature (°C)
#define WEIGHT_CHANGE_THRESHOLD 2.0           // Significant weight change (kg)

// SpO2 Thresholds
#define SPO2_MIN 90                           // Minimum safe SpO2 (%)
#define SPO2_CRITICAL 85                      // Critical SpO2 level (%)

// Buffer and Memory Settings
// =============================================================================
#define MAX_SENSOR_BUFFER_SIZE 20             // Maximum sensor readings to buffer
#define JSON_BUFFER_SIZE 2048                 // JSON payload buffer size
#define MQTT_BUFFER_SIZE 1024                 // MQTT message buffer size
#define NVS_NAMESPACE "biotrack"              // NVS storage namespace

// FreeRTOS Task Configuration
// =============================================================================
#define SENSOR_TASK_STACK_SIZE 4096           // Stack size for sensor tasks
#define NETWORK_TASK_STACK_SIZE 8192          // Stack size for network tasks
#define SENSOR_TASK_PRIORITY 2                // Sensor task priority
#define NETWORK_TASK_PRIORITY 3               // Network task priority
#define WATCHDOG_TIMEOUT 30000                // Watchdog timeout (ms)

// Debug and Logging Configuration
// =============================================================================
#define DEBUG_ENABLED true                    // Enable debug output
#define SERIAL_BAUD_RATE 115200               // Serial communication speed
#define LOG_LEVEL_INFO 1                      // Log level: 0=Error, 1=Info, 2=Debug
#define ENABLE_SERIAL_PLOTTER false           // Enable Arduino Serial Plotter output

// Cloud Function Endpoints (when Firebase Functions are deployed)
// =============================================================================
#define FUNCTIONS_REGION "us-central1"
#define PROCESS_SENSOR_DATA_FUNCTION "receiveSensorData"
#define DEVICE_HEARTBEAT_FUNCTION "deviceHeartbeat"
#define PROCESS_ALERT_FUNCTION "processAlert"
#define GET_DEVICE_CONFIG_FUNCTION "getDeviceConfig"

// OTA Update Configuration
// =============================================================================
#define OTA_HOSTNAME "biotrack-device"
#define OTA_PORT 3232
#define CHECK_UPDATE_INTERVAL 3600000         // Check for updates every hour
#define ENABLE_AUTO_UPDATE false              // Auto-update disabled for safety

// Power Management (for battery-powered devices)
// =============================================================================
#define ENABLE_DEEP_SLEEP false               // Enable deep sleep mode
#define SLEEP_DURATION_MINUTES 5              // Sleep duration between measurements
#define LOW_BATTERY_THRESHOLD 20              // Low battery warning threshold (%)
#define CRITICAL_BATTERY_THRESHOLD 10         // Critical battery threshold (%)

// Advanced Configuration
// =============================================================================
#define MAX_WIFI_RECONNECTS 5                 // Max WiFi reconnection attempts
#define CLOUD_RETRY_DELAY 2000                // Delay between cloud retry attempts
#define SENSOR_ERROR_THRESHOLD 3              // Max consecutive sensor errors
#define ENABLE_SENSOR_FUSION true             // Enable multi-sensor data fusion
#define USE_HARDWARE_WATCHDOG true            // Enable hardware watchdog

// Data Quality and Filtering
// =============================================================================
#define ENABLE_SIGNAL_FILTERING true          // Enable signal processing filters
#define MOVING_AVERAGE_WINDOW 5               // Moving average window size
#define OUTLIER_DETECTION_THRESHOLD 2.0       // Standard deviations for outlier detection
#define MIN_SIGNAL_QUALITY_THRESHOLD 70       // Minimum signal quality percentage

#endif // CONFIG_TEMPLATE_H
