# ESP32 Firmware Deployment Guide

## Build Status ✅
**Successfully Compiled:** ESP32 Multi-Sensor Health Monitoring Firmware  
**Date:** June 9, 2025  
**Memory Usage:** RAM: 18.3% | Flash: 36.0%  
**Status:** All critical compilation issues resolved ✅

### Latest Updates
- ✅ Fixed critical syntax errors and missing braces
- ✅ Resolved uninitialized struct member variables
- ✅ Added missing function implementations
- ✅ Fixed header file duplicate declarations
- ✅ Moved test files to avoid compilation conflicts
- ✅ Successfully compiles with no critical errors

## Hardware Requirements

### Required Sensors
1. **MAX30102** (Heart Rate/SpO2) - I2C Bus 0 (Pins 21, 22)
2. **MAX30102** (Glucose Monitor) - I2C Bus 1 (Pins 16, 17) 
3. **DS18B20** (Temperature) - OneWire (Pin 4)
4. **HX711 + Load Cell** (Weight) - Digital (Pins 5, 18)
5. **AD5941** (Bioimpedance) - SPI (Pins 15, 23, 19, 14, 2, 27)
6. **AD8232** (ECG) - Analog (Pin 34) + Digital (Pins 32, 33)

### Pin Assignment Summary
```
MAX30102 HR:    SDA=21, SCL=22 (I2C Bus 0)
MAX30102 GLU:   SDA=16, SCL=17 (I2C Bus 1)
DS18B20 TEMP:   DATA=4 (OneWire)
HX711 WEIGHT:   DOUT=5, SCK=18
AD5941 BIA:     CS=15, MOSI=23, MISO=19, SCK=14, RST=2, INT=27
AD8232 ECG:     OUT=34, LO+=32, LO-=33
```

## Deployment Steps

### 1. Hardware Setup
- Connect all sensors according to pin assignments above
- Ensure proper power supply (3.3V/5V as required per sensor)
- Verify no pin conflicts between sensors

### 2. Configuration
Edit `include/config.h`:
```cpp
// WiFi Credentials
#define WIFI_SSID "YOUR_NETWORK_NAME"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// Firebase Configuration  
#define FIREBASE_PROJECT_ID "bio-track-de846"
#define FIREBASE_API_KEY "YOUR_FIREBASE_API_KEY"
```

### 3. Flash Firmware
```bash
# Upload to ESP32
cd esp32_firmware
pio run --target upload

# Monitor serial output
pio device monitor
```

### 4. Verification Steps

#### 4.1 Serial Monitor Check
Look for initialization messages:
```
🔄 Initializing sensors...
✅ Heart rate sensor initialized
✅ Temperature sensor initialized  
✅ Weight sensor initialized
✅ Bioimpedance sensor initialized
✅ ECG sensor initialized
✅ Glucose sensor initialized
```

#### 4.2 Sensor Status
Monitor for sensor readings every 5 seconds:
```
=== Sensor Readings ===
Heart Rate: 72.1 BPM, SpO2: 98.2%
Temperature: 36.5°C
Weight: 70.2 kg (Stable)
Bioimpedance @ 10000.0 Hz: 485.2 Ω
ECG: Avg BPM: 73, Avg Filtered: 1425.8, Peaks: 6
Glucose: 95.4 mg/dL (IR: 65432.1, Red: 45123.6, Quality: 12.3%) (Stable)
=======================
```

## Testing Protocol

### 1. Individual Sensor Testing
- **Heart Rate**: Place finger on MAX30102 sensor
- **Temperature**: Sensor should read ambient (~22-25°C) or body temp
- **Weight**: Place known weight on load cell
- **ECG**: Attach electrodes to body (RA, LA, RL leads)
- **Glucose**: Place finger on second MAX30102 sensor
- **Bioimpedance**: Contact electrodes to skin

### 2. Calibration Procedures

#### Weight Calibration
```
Serial Command: calibrateWeight(1.0)  // Use 1kg known weight
Follow prompts in serial monitor
```

#### Bioimpedance Calibration  
```
Serial Command: calibrateBIA(1000.0)  // Use 1kΩ precision resistor
Follow prompts in serial monitor
```

### 3. Network Connectivity Test
- Verify WiFi connection in serial monitor
- Check MQTT connection to Firebase
- Confirm data upload to Firestore

## Troubleshooting

### Common Issues

1. **Sensor Initialization Failed**
   - Check wiring connections
   - Verify power supply voltage
   - Ensure no pin conflicts

2. **WiFi Connection Issues**
   - Verify SSID/password in config.h
   - Check 2.4GHz WiFi availability
   - Monitor signal strength (RSSI)

3. **Data Upload Failures**
   - Verify Firebase API key
   - Check internet connectivity
   - Monitor MQTT connection status

### Debug Commands
```cpp
// In main loop, add for debugging:
sensors.printSensorReadings(readings);
Serial.println(wifiManager.getConnectionStatus());
```

## OTA Updates

The firmware supports Over-The-Air updates:
```cpp
OTA_HOSTNAME = "biotrack-device"
OTA_PASSWORD = "biotrack_ota_2024"
```

## Performance Metrics

- **Sampling Rate**: 5-second intervals for all sensors
- **Data Throughput**: ~6 sensor readings per cycle
- **Memory Efficiency**: 83% RAM available, 64% Flash available
- **Power Consumption**: Optimized with sensor sleep modes

## Security Features

- ✅ Encrypted credential storage (NVS)
- ✅ TLS 1.2+ for MQTT/Firebase
- ✅ Secure OTA with authentication
- ✅ Input validation and error handling

## Support

For issues or questions:
1. Check serial monitor output for error messages
2. Verify hardware connections match pin assignments
3. Test individual sensors before full system integration
4. Monitor memory usage for potential issues

---
**Firmware Version**: 1.0.0  
**Build Date**: June 9, 2025  
**Platform**: ESP32 (Arduino Framework)
