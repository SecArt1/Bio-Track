#ifndef CONFIG_H
#define CONFIG_H

// WiFi Configuration
#define WIFI_SSID "BioTrack"
#define WIFI_PASSWORD "1234567888"
#define WIFI_CONNECT_TIMEOUT 30000
#define WIFI_RECONNECT_INTERVAL 5000

// AWS IoT Core Configuration
#define AWS_IOT_ENDPOINT "azvqnnby4qrmz-ats.iot.eu-central-1.amazonaws.com"
#define AWS_IOT_PORT 8883
#define AWS_IOT_CLIENT_ID "biotrack-device-001"
#define AWS_IOT_THING_NAME "biotrack-device-001"

// Device Configuration
#define DEVICE_ID "biotrack-device-001"
#define FIRMWARE_VERSION "1.0.2"
#define USER_ID_PLACEHOLDER "user_placeholder"

// AWS IoT MQTT Topics
#define TOPIC_BASE "biotrack/device/" DEVICE_ID
#define TOPIC_TELEMETRY TOPIC_BASE "/telemetry"
#define TOPIC_COMMANDS TOPIC_BASE "/commands"
#define TOPIC_STATUS TOPIC_BASE "/status"
#define TOPIC_RESPONSES TOPIC_BASE "/responses"
#define TOPIC_SHADOW_UPDATE "$aws/thing/" AWS_IOT_THING_NAME "/shadow/update"
#define TOPIC_SHADOW_GET "$aws/thing/" AWS_IOT_THING_NAME "/shadow/get"

// AWS Lambda API Gateway Configuration
#define AWS_API_GATEWAY_URL "https://isjd26qkie.execute-api.eu-central-1.amazonaws.com/prod"
#define AWS_ACCOUNT_ID "447191070724"
#define AWS_REGION "eu-central-1"

// IoT Certificate Configuration
#define AWS_IOT_CERTIFICATE_ID "7f024911d9857e9882fbdb1a4b469259cb99247e795c99c2d4374b952f9e1737"
#define AWS_IOT_POLICY_NAME "biotrack-device-policy"

// Certificate File Paths
#define AWS_IOT_CERTIFICATE_FILE "/certs/device-certificate.pem.crt"
#define AWS_IOT_PRIVATE_KEY_FILE "/certs/device-private.pem.key"
#define AWS_ROOT_CA_FILE "/certs/amazon-root-ca1.pem"

// Sensor Configuration
#define TEMP_SENSOR_PIN 4
#define WEIGHT_SENSOR_DOUT 5
#define WEIGHT_SENSOR_SCK 18
#define BIA_FREQUENCY_PIN 15
#define SPO2_SDA_PIN 21
#define SPO2_SCL_PIN 22

// AWS IoT Configuration
#define HEARTBEAT_INTERVAL 60000  // 1 minute
#define RECONNECT_INTERVAL 5000   // 5 seconds
#define KEEP_ALIVE_INTERVAL 60    // 60 seconds for MQTT
#define MQTT_KEEPALIVE_INTERVAL 60000  // 60 seconds for MQTT keepalive

// Security Configuration
#define USE_TLS_ENCRYPTION true
#define VERIFY_AWS_CERT true
#define VERIFY_FIREBASE_CERT false  // Deprecated - Firebase is no longer used
#define NVS_ENCRYPTION_KEY "biotrack_nvs_key_2024"

// AWS IoT Endpoints
#define DEVICE_STATUS_ENDPOINT "/device/status"
#define SENSOR_DATA_ENDPOINT "/device/data"
#define COMMAND_ENDPOINT "/device/command"
#define OTA_UPDATE_ENDPOINT "/device/ota"
#define HEARTBEAT_ENDPOINT "/device/heartbeat"
#define ALERT_ENDPOINT "/device/alert"

// Legacy Firebase Configuration (Deprecated)
#define FIREBASE_FUNCTIONS_URL "https://deprecated-firebase-url.com"  // Not used anymore
#define FIREBASE_API_KEY "deprecated"  // Not used anymore
#define MQTT_SERVER AWS_IOT_ENDPOINT  // Legacy compatibility
#define MQTT_PORT AWS_IOT_PORT        // Legacy compatibility

#define LED_BUILTIN 2  // GPIO2 - ESP32 built-in LED pin (Board Pin D2)

// ===================================================
// Sensor Pin Definitions - ESP32 WROOM-32 Optimized
// ===================================================
// Board pin references for ESP32 WROOM-32 DevKit v1

// MAX30102 Sensor (Single sensor - software staged testing)
// Connected to GPIO 21 (SDA) and GPIO 22 (SCL) for all measurement modes
#define MAX30102_SDA_PIN 21      // GPIO21 - I2C0 SDA (Board Pin D21)
#define MAX30102_SCL_PIN 22      // GPIO22 - I2C0 SCL (Board Pin D22)

// Staged Testing Configuration - Single MAX30102 sensor modes:
// Mode 1: Heart Rate & SpO2 measurement (primary function)
// Mode 2: Glucose estimation (PPG morphology analysis) 
// Mode 3: Blood pressure estimation (PPG for PTT calculation)
// Note: Software switches between measurement modes, no hardware changes needed

// GPIO 13 and 18 are now available for other sensors
// Previous glucose-specific pins removed - using single MAX30102 for all modes

// DS18B20 Temperature (OneWire)
#define DS18B20_PIN 4            // GPIO4 - OneWire data (Board Pin D4)
#define ONE_WIRE_BUS DS18B20_PIN

// HX711 Load Cell (Digital)
#define LOAD_CELL_DOUT_PIN 23    // GPIO23 - HX711 data out 
#define LOAD_CELL_SCK_PIN 22     // GPIO22 - HX711 clock

// AD5941 Bioimpedance (SPI)
#define AD5941_CS_PIN 5          // GPIO5 - SPI chip select (Board Pin D5)
#define AD5941_MOSI_PIN 23       // GPIO23 - SPI MOSI (Board Pin D23/MOSI)
#define AD5941_MISO_PIN 19       // GPIO19 - SPI MISO (Board Pin D19/MISO)
#define AD5941_SCK_PIN 14        // GPIO14 - SPI clock (Board Pin D14)
#define AD5941_RESET_PIN 25      // GPIO25 - Reset pin (Board Pin D25)
#define AD5941_INT_PIN 26        // GPIO26 - Interrupt pin (Board Pin D26)

// AD8232 ECG Sensor (Analog + Digital)
#define ECG_PIN 36               // GPIO36 - ECG signal input (Board Pin VP/ADC1_CH0)
#define LO_PLUS_PIN 32           // GPIO32 - Leads-off detect + (Board Pin D32/ADC1_CH4)
#define LO_MINUS_PIN 33          // GPIO33 - Leads-off detect - (Board Pin D33/ADC1_CH5)

// Available GPIO pins (freed up from glucose I2C)
#define AVAILABLE_PIN_13 13      // GPIO13 - Available for expansion (Board Pin D13)
#define AVAILABLE_PIN_18 18      // GPIO18 - Available for expansion (Board Pin D18)

// Blood Pressure Estimation (Software-based, no hardware pump needed)
// Uses MAX30102 (PPG) + AD8232 (ECG) for pulse transit time calculation
// #define BP_ENABLE_PIN 27      // UNUSED - No physical BP hardware
// #define BP_PUMP_PIN 12        // UNUSED - No physical pump needed
// Note: BP estimation will be done via PPG+ECG signal processing algorithms

// Measurement Intervals (milliseconds)
#define HEART_RATE_INTERVAL 5000    // 5 seconds
#define TEMPERATURE_INTERVAL 5000   // 5 seconds (updated for faster DS18B20 readings)
#define WEIGHT_INTERVAL 2000        // 2 seconds
#define BIOIMPEDANCE_INTERVAL 15000 // 15 seconds
#define ECG_INTERVAL 5000           // 5 seconds
#define GLUCOSE_INTERVAL 10000      // 10 seconds
#define SENSOR_SAMPLE_RATE 5000     // 5 seconds for general sensor sampling

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
#define LOAD_CELL_CALIBRATION_FACTOR -456.0  // Adjusted for correct weight reading (negative because reading was negative)
#define WEIGHT_OFFSET 0.0
#define WEIGHT_EEPROM_ADDRESS 0  // EEPROM address for storing calibration value

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

/*
 * ESP32 WROOM-32 Pin Assignment Summary - Staged Testing (Single MAX30102)
 * =======================================================================
 *  * GPIO  2: LED_BUILTIN                    (Board Pin D2)
 * GPIO  4: DS18B20_PIN                    (Board Pin D4) - Temperature sensor
 * GPIO  5: AD5941_CS_PIN                  (Board Pin D5) - BIA sensor chip select
 * GPIO 12: [UNUSED]                       (Board Pin D12) - Available for future use (boot sensitive) * GPIO 13: AVAILABLE_PIN_13               (Board Pin D13) - Available for expansion
 * GPIO 14: AD5941_SCK_PIN                (Board Pin D14) - BIA sensor SPI clock
 * GPIO 16: LOAD_CELL_DOUT_PIN            (Board Pin RX2) - Weight sensor data
 * GPIO 17: LOAD_CELL_SCK_PIN             (Board Pin TX2) - Weight sensor clock
 * GPIO 18: AVAILABLE_PIN_18               (Board Pin D18) - Available for expansion
 * GPIO 19: AD5941_MISO_PIN               (Board Pin D19/MISO) - BIA sensor SPI data in
 * GPIO 21: MAX30102_SDA_PIN              (Board Pin D21) - MAX30102 I2C SDA (ALL MODES)
 * GPIO 22: MAX30102_SCL_PIN              (Board Pin D22) - MAX30102 I2C SCL (ALL MODES)
 * GPIO 23: AD5941_MOSI_PIN               (Board Pin D23/MOSI) - BIA sensor SPI data out
 * GPIO 25: AD5941_RESET_PIN              (Board Pin D25) - BIA sensor reset
 * GPIO 26: AD5941_INT_PIN                (Board Pin D26) - BIA sensor interrupt
 * GPIO 27: [UNUSED]                       (Board Pin D27) - Available for future use
 * GPIO 32: LO_PLUS_PIN                   (Board Pin D32/ADC1_CH4) - ECG lead off +
 * GPIO 33: LO_MINUS_PIN                  (Board Pin D33/ADC1_CH5) - ECG lead off -
 * GPIO 36: ECG_PIN                       (Board Pin VP/ADC1_CH0) - ECG analog input (input only)
 *  * STAGED TESTING SETUP:
 * ====================
 * Single MAX30102 sensor connected only to GPIO 21 (SDA) and GPIO 22 (SCL)
 * All measurement modes use the same physical sensor and pins:
 * 
 * 1. Heart Rate/SpO2 Mode: MAX30102 on GPIO 21 (D21 SDA) and 22 (D22 SCL)
 * 2. Glucose Mode: Same sensor, different software configuration
 * 3. Blood Pressure Mode: Same sensor, PPG analysis for PTT calculation
 * 4. Auto-cycle Mode: Software automatically switches between measurement types
 * 
 * No hardware changes needed - all mode switching is done in software!
 * 
 * BLOOD PRESSURE ESTIMATION (Software-based):
 * ==========================================
 * With your available sensors (MAX30102 + AD8232), blood pressure can be estimated using:
 * 
 * 1. PULSE TRANSIT TIME (PTT) METHOD:
 *    - ECG R-peak detection (AD8232 on GPIO 36)
 *    - PPG pulse detection (MAX30102 on GPIO 21/22)
 *    - Calculate time difference between ECG R-peak and PPG pulse arrival
 *    - PTT correlates inversely with blood pressure
 * 
 * 2. PPG MORPHOLOGY ANALYSIS:
 *    - Analyze PPG waveform characteristics from MAX30102
 *    - Extract features like pulse width, rise time, notch patterns
 *    - Use machine learning models to estimate systolic/diastolic BP
 * 
 * 3. HEART RATE VARIABILITY (HRV):
 *    - Calculate R-R intervals from ECG (AD8232)
 *    - Analyze HRV parameters that correlate with BP
 *    - Combine with PPG features for improved accuracy
 * 
 * IMPLEMENTATION NOTES:
 * - No hardware pump needed - purely algorithmic approach
 * - Requires calibration with reference BP measurements
 * - Accuracy depends on signal quality and individual calibration
 * - GPIO 12 and 27 are now available for other sensors if needed
 *
 * Available for future use: GPIO 15 (WROOM-32 safe)
 * 
 * Avoided pins:
 * GPIO 0,2,12,15: Boot sensitive
 * GPIO 6-11: Connected to flash memory
 * GPIO 34,35,39: Input only (GPIO 36 used for ECG input)
 */

// ===================================================
// MAX30102 Staged Testing Configuration
// ===================================================
// Single sensor operation modes - software controlled

enum MAX30102_Mode {
    MODE_HEART_RATE_SPO2 = 0,    // Primary: Heart rate and SpO2 measurement
    MODE_GLUCOSE_ESTIMATION = 1,  // PPG morphology analysis for glucose
    MODE_BLOOD_PRESSURE = 2,     // PPG for pulse transit time calculation
    MODE_CALIBRATION = 3         // Sensor calibration and baseline measurement
};

// Current mode tracking
extern MAX30102_Mode currentMAX30102Mode;

// Mode switching functions
inline void setMAX30102Mode(MAX30102_Mode mode) {
    currentMAX30102Mode = mode;
}

inline MAX30102_Mode getMAX30102Mode() {
    return currentMAX30102Mode;
}

// Mode-specific measurement intervals (milliseconds)
#define HR_SPO2_SAMPLE_RATE 1000      // 1 second for heart rate/SpO2
#define GLUCOSE_SAMPLE_RATE 5000      // 5 seconds for glucose estimation  
#define BP_PPG_SAMPLE_RATE 500        // 500ms for blood pressure PTT
#define CALIBRATION_SAMPLE_RATE 2000  // 2 seconds for calibration

// Mode switching intervals (how long to stay in each mode)
#define MODE_DURATION_HR_SPO2 30000   // 30 seconds
#define MODE_DURATION_GLUCOSE 20000   // 20 seconds
#define MODE_DURATION_BP 15000        // 15 seconds
#define MODE_DURATION_CALIBRATION 10000 // 10 seconds

// Auto-cycling configuration
#define ENABLE_AUTO_MODE_CYCLING true
#define TOTAL_CYCLE_TIME 75000        // 75 seconds for complete cycle

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

// Pin Conflict Validation
inline bool validatePinConfiguration() {    // Array of all pin assignments for conflict checking
    int pinAssignments[] = {
        2,   // LED_BUILTIN
        4,   // DS18B20_PIN
        5,   // AD5941_CS_PIN
        14,  // AD5941_SCK_PIN (BIA sensor)
        16,  // LOAD_CELL_DOUT_PIN
        17,  // LOAD_CELL_SCK_PIN
        19,  // AD5941_MISO_PIN
        21,  // MAX30102_SDA_PIN (single sensor, all modes)
        22,  // MAX30102_SCL_PIN (single sensor, all modes)
        23,  // AD5941_MOSI_PIN
        25,  // AD5941_RESET_PIN
        26,  // AD5941_INT_PIN
        32,  // LO_PLUS_PIN
        33,  // LO_MINUS_PIN
        36   // ECG_PIN (input-only)
    };
    
    int numPins = sizeof(pinAssignments) / sizeof(pinAssignments[0]);
    
    // Check for duplicates
    for (int i = 0; i < numPins - 1; i++) {
        for (int j = i + 1; j < numPins; j++) {
            if (pinAssignments[i] == pinAssignments[j]) {
                return false; // Conflict found
            }
        }
    }
    
    // Validate all pins are WROOM-32 compatible
    for (int i = 0; i < numPins; i++) {
        if (!isValidWROOMPin(pinAssignments[i])) {
            return false; // Invalid pin found
        }
    }
    
    return true; // No conflicts
}

// Staged Testing Configuration for Single MAX30102 Sensor
// ========================================================
// Since only one MAX30102 is available, use staged testing modes
// Connect sensor to different pin pairs for different measurement types

typedef enum {
    SENSOR_MODE_HEART_RATE_SPO2,    // Heart rate and SpO2 measurements
    SENSOR_MODE_GLUCOSE,            // Glucose measurements (experimental)
    SENSOR_MODE_AUTO_CYCLE          // Automatically cycle between modes
} MAX30102_SensorMode;

// Default sensor mode (can be changed via software or hardware jumpers)
#define DEFAULT_SENSOR_MODE SENSOR_MODE_HEART_RATE_SPO2

// Staging intervals for auto-cycle mode
#define HEART_RATE_STAGE_DURATION 30000    // 30 seconds for heart rate/SpO2
#define GLUCOSE_STAGE_DURATION 60000       // 60 seconds for glucose measurement
#define STAGE_TRANSITION_DELAY 5000        // 5 seconds between mode switches

// Hardware connection modes for staged testing
#define USE_HARDWARE_SWITCHING false       // Set to true if using hardware multiplexer
#define USE_SOFTWARE_SWITCHING true        // Set to true for software-based staging

// Staged Testing Helper Functions
inline int getCurrentSensorSDA(MAX30102_SensorMode mode) {
    // Single MAX30102 sensor always uses GPIO 21 regardless of mode
    return MAX30102_SDA_PIN;  // GPIO 21 for all modes
}

inline int getCurrentSensorSCL(MAX30102_SensorMode mode) {
    // Single MAX30102 sensor always uses GPIO 22 regardless of mode  
    return MAX30102_SCL_PIN;  // GPIO 22 for all modes
}

inline const char* getSensorModeString(MAX30102_SensorMode mode) {
    switch(mode) {
        case SENSOR_MODE_HEART_RATE_SPO2: return "Heart Rate & SpO2";
        case SENSOR_MODE_GLUCOSE: return "Glucose Monitor";
        case SENSOR_MODE_AUTO_CYCLE: return "Auto Cycle";
        default: return "Unknown";
    }
}

#endif // CONFIG_H