#ifndef BP_TEST_CONFIG_H
#define BP_TEST_CONFIG_H

// Blood Pressure Test Configuration
// This file contains specific settings for the BP monitoring test program

// Test Parameters
#define BP_TEST_DURATION_SECONDS 30
#define BP_MEASUREMENT_INTERVAL_MS 30000
#define SIGNAL_COLLECTION_TIME_MS 10000
#define MIN_SIGNAL_QUALITY 70.0

// Calibration Settings
#define MAX_CALIBRATION_POINTS 5
#define MIN_CALIBRATION_POINTS 2
#define CALIBRATION_TIMEOUT_MS 60000

// Signal Processing
#define ECG_SAMPLING_RATE 200  // Hz
#define PPG_SAMPLING_RATE 100  // Hz
#define PTT_MIN_VALID_MS 50
#define PTT_MAX_VALID_MS 400

// User Profile Defaults
#define DEFAULT_AGE 30
#define DEFAULT_HEIGHT_CM 170.0
#define DEFAULT_GENDER_MALE true

// Display Settings
#define SERIAL_UPDATE_INTERVAL_MS 5000
#define DIAGNOSTICS_INTERVAL_MS 10000
#define STATUS_LED_BLINK_MS 1000

// Validation Ranges
#define MIN_SYSTOLIC_BP 80
#define MAX_SYSTOLIC_BP 250
#define MIN_DIASTOLIC_BP 40
#define MAX_DIASTOLIC_BP 150

// BP Categories (mmHg)
#define NORMAL_SYS_THRESHOLD 120
#define NORMAL_DIA_THRESHOLD 80
#define ELEVATED_SYS_THRESHOLD 130
#define STAGE1_SYS_THRESHOLD 140
#define STAGE1_DIA_THRESHOLD 90
#define STAGE2_SYS_THRESHOLD 180
#define STAGE2_DIA_THRESHOLD 120

// PWV Assessment Thresholds (m/s)
#define PWV_GOOD_THRESHOLD 7.0
#define PWV_MODERATE_THRESHOLD 10.0

// HRV Assessment Thresholds (ms)
#define HRV_GOOD_THRESHOLD 50.0
#define HRV_MODERATE_THRESHOLD 30.0

// Test Messages
#define MSG_WELCOME "🩺 ADVANCED BLOOD PRESSURE MONITORING SYSTEM 🩺"
#define MSG_SUBTITLE "   Using MAX30102 + AD8232 with PTT Analysis"
#define MSG_READY "✅ System ready for blood pressure monitoring"
#define MSG_CALIBRATION_NEEDED "⚠️ Calibration recommended for accuracy"
#define MSG_POOR_SIGNAL "❌ Poor signal quality - check sensor placement"

// Advanced Features
#define ENABLE_ADAPTIVE_FILTERING true
#define ENABLE_MOTION_DETECTION true
#define ENABLE_ARTIFACT_REJECTION true
#define ENABLE_TREND_ANALYSIS true

// Experimental Features (for research)
#define ENABLE_ML_FEATURES false
#define ENABLE_VASCULAR_HEALTH_INDEX true
#define ENABLE_CARDIAC_OUTPUT_ESTIMATION true
#define ENABLE_ARTERIAL_STIFFNESS_CALC true

#endif // BP_TEST_CONFIG_H
