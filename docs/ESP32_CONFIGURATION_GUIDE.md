# ESP32 Firmware Configuration Guide

## 🔧 Required Configuration Changes

Before deploying the ESP32 firmware to your device, you need to update the configuration file with your specific credentials and settings.

### 1. Update WiFi Credentials

Edit `esp32_firmware/include/config.h`:

```cpp
// WiFi Configuration
#define WIFI_SSID "YOUR_ACTUAL_WIFI_SSID"        // Replace with your WiFi network name
#define WIFI_PASSWORD "YOUR_ACTUAL_WIFI_PASSWORD" // Replace with your WiFi password
```

### 2. Configure Firebase API Key

You'll need to get your Firebase Web API Key from the Firebase Console:

1. Go to [Firebase Console](https://console.firebase.google.com/project/bio-track-de846/settings/general)
2. Navigate to Project Settings → General
3. Scroll down to "Your apps" → Web apps
4. Copy the "Web API Key"

Update the config:
```cpp
// Firebase Configuration
#define FIREBASE_API_KEY "your_actual_firebase_api_key_here"
```

### 3. Device ID Configuration (Optional)

For multiple devices, update the device ID:
```cpp
// Device Configuration
#define DEVICE_ID "biotrack_device_001"  // Change to unique ID per device
```

## 🚀 Deployment Commands

Once configured, deploy the firmware:

```bash
# Navigate to firmware directory
cd esp32_firmware

# Build and upload to connected ESP32
pio run --target upload

# Monitor serial output
pio device monitor
```

## 📋 Hardware Setup

### Required Components
- ESP32 Development Board
- MAX30102 Heart Rate/SpO2 Sensor (I2C: SDA=21, SCL=22)
- DS18B20 Temperature Sensor (OneWire: Pin 4)
- HX711 Load Cell Amplifier + Load Cell (DT=5, SCK=18)
- AD5941 BIA Sensor (SPI: MOSI=23, MISO=19, SCK=18, CS=5)

### Wiring Diagram
```
ESP32 Pin Layout:
┌─────────────────┐
│     ESP32       │
│                 │
│ GPIO21 ──────── │ SDA (MAX30102, AD5941 secondary I2C)
│ GPIO22 ──────── │ SCL (MAX30102, AD5941 secondary I2C)
│ GPIO4  ──────── │ OneWire (DS18B20)
│ GPIO5  ──────── │ HX711 DT + AD5941 CS
│ GPIO18 ──────── │ HX711 SCK + AD5941 SCK
│ GPIO23 ──────── │ AD5941 MOSI
│ GPIO19 ──────── │ AD5941 MISO
│ GPIO2  ──────── │ Status LED
└─────────────────┘
```

## 🔍 Testing & Verification

### 1. Serial Monitor Output
Expected startup sequence:
```
[INFO] BioTrack ESP32 Initializing...
[INFO] WiFi connecting to: YOUR_SSID
[INFO] WiFi connected! IP: 192.168.x.x
[INFO] NTP time synchronized
[INFO] MAX30102 initialized successfully
[INFO] DS18B20 found: 1 devices
[INFO] HX711 calibration loaded
[INFO] AD5941 BIA sensor ready
[INFO] Secure connection to Firebase established
[INFO] Device registered: biotrack_device_001
[INFO] All systems ready - starting main loop
```

### 2. Firebase Console Verification
Check these collections in Firestore:
- `devices/{deviceId}` - Device status and last seen
- `sensor_data` - Real-time sensor readings
- `alerts` - Any health alerts generated

### 3. Health Data Readings
Expected sensor data format:
```json
{
  "deviceId": "biotrack_device_001",
  "timestamp": "2025-06-12T10:30:00Z",
  "heartRate": { "value": 72, "quality": "good" },
  "temperature": { "value": 36.8, "unit": "celsius" },
  "weight": { "value": 70.5, "unit": "kg" },
  "bioimpedance": { "resistance": 450, "frequency": 50000 },
  "batteryLevel": 85,
  "signalQuality": "excellent"
}
```

## 🛠 Troubleshooting

### Common Issues

**WiFi Connection Failed**
- Verify SSID and password are correct
- Check WiFi network is 2.4GHz (ESP32 doesn't support 5GHz)
- Ensure network allows IoT devices

**Firebase Connection Error**
- Verify API key is correct
- Check internet connectivity
- Ensure Firebase project is active

**Sensor Not Detected**
- Check wiring connections
- Verify sensor power supply (3.3V)
- Check I2C/SPI communication pins

**Memory Issues**
- Current memory usage: RAM 20.3%, Flash 36.7%
- If adding features, monitor memory usage
- Consider optimizing data structures if needed

### Debug Commands
```bash
# Verbose build output
pio run -v

# Monitor with timestamp
pio device monitor --filter=time

# Check device info
pio device list

# Clean build
pio run --target clean
```

## 🔐 Security Considerations

### Implemented Security Features
- TLS/SSL encryption for all communications
- Certificate verification for Firebase connections
- Secure credential storage in NVS (Non-Volatile Storage)
- OTA update verification
- Watchdog timer protection

### Additional Recommendations
- Change default device ID for production
- Implement device-specific certificates for enhanced security
- Regular firmware updates through OTA
- Monitor device logs for suspicious activity

## 📊 Performance Monitoring

### Key Metrics to Monitor
- WiFi signal strength (RSSI)
- Memory usage (heap free)
- Sensor reading frequency
- Network latency to Firebase
- Battery level (if battery powered)

### Optimization Tips
- Adjust sampling rates based on requirements
- Use deep sleep for battery-powered deployments
- Implement local data buffering for network outages
- Monitor and optimize Firebase function execution times

---
*Configuration complete! Your ESP32 device should now be ready for deployment.*
