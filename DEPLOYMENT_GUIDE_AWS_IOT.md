# BioTrack AWS IoT + Firebase Integration Guide

## Complete Setup and Deployment Instructions

This guide will walk you through deploying the complete BioTrack AWS IoT + Firebase hybrid architecture.

---

## 🚀 Step 1: AWS Infrastructure Deployment

### Prerequisites
1. **AWS CLI** installed and configured
2. **Node.js 18+** installed
3. **Firebase project** with Firestore enabled
4. **Firebase service account** credentials

### 1.1 Configure AWS Credentials
```powershell
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and Region (us-east-1)
```

### 1.2 Get Firebase Service Account Credentials
1. Go to Firebase Console → Project Settings → Service accounts
2. Click "Generate new private key"
3. Save the JSON file and note the `client_email` and `private_key` values

### 1.3 Deploy AWS Infrastructure
```powershell
cd aws-lambda
npm install
.\deploy.ps1
```

**When prompted, enter:**
- Firebase Client Email: `your-service-account@bio-track-de846.iam.gserviceaccount.com`
- Firebase Private Key: `-----BEGIN PRIVATE KEY-----\n...` (the entire key)

### 1.4 Note the Deployment Outputs
The script will output:
- **IoT Endpoint**: `xxxxx.iot.us-east-1.amazonaws.com`
- **API Endpoint**: `https://xxxxx.execute-api.us-east-1.amazonaws.com/prod`
- **Device certificates** saved in `certificates/` folder

---

## 🔧 Step 2: ESP32 Firmware Configuration

### 2.1 Update Configuration Files

**Update `esp32_firmware/include/config.h`:**
```cpp
// Replace with your actual IoT endpoint from Step 1.4
#define AWS_IOT_ENDPOINT "xxxxx.iot.us-east-1.amazonaws.com"
```

**Update `esp32_firmware/include/aws_certificates.h`:**
```cpp
// Copy the content from certificates/biotrack-device-001-certificate.pem
const char AWS_CERT_PEM[] = R"EOF(
-----BEGIN CERTIFICATE-----
[paste certificate content here]
-----END CERTIFICATE-----
)EOF";

// Copy the content from certificates/biotrack-device-001-private.key
const char AWS_PRIVATE_KEY[] = R"EOF(
-----BEGIN RSA PRIVATE KEY-----
[paste private key content here]
-----END RSA PRIVATE KEY-----
)EOF";

// Copy the content from certificates/AmazonRootCA1.pem
const char AWS_ROOT_CA[] = R"EOF(
-----BEGIN CERTIFICATE-----
[paste root CA content here]
-----END CERTIFICATE-----
)EOF";
```

### 2.2 Flash ESP32 Firmware
```powershell
cd esp32_firmware
# Replace main.cpp with aws_iot_main.cpp
copy src\aws_iot_main.cpp src\main.cpp
platformio run --target upload
```

---

## 📱 Step 3: Flutter App Configuration

### 3.1 Update Dependencies
```powershell
cd ..  # Back to project root
flutter pub get
```

### 3.2 Update AWS IoT Service Configuration

**Edit `lib/services/aws_iot_service.dart`:**
```dart
// Replace with your API endpoint from Step 1.4
static const String _baseUrl = 'https://xxxxx.execute-api.us-east-1.amazonaws.com/prod';
```

### 3.3 Update App Routing (Optional)
Add the new device pairing and testing screens to your app navigation:

**In `lib/main.dart` or your routing file:**
```dart
import 'pages/device_pairing_clean.dart';
import 'pages/device_testing_aws.dart';

// Add routes
'/device_pairing': (context) => DevicePairingScreen(),
'/device_testing': (context) => DeviceTestingScreen(),
```

---

## ✅ Step 4: Testing the Integration

### 4.1 Test AWS IoT Connection
1. Power on your ESP32 device
2. Monitor serial output for connection status
3. Check AWS IoT Console → Test → MQTT test client
4. Subscribe to `biotrack/device/+/telemetry` to see data

### 4.2 Test Device Pairing
1. Open Flutter app
2. Navigate to Device Pairing screen
3. Enter:
   - Device ID: `biotrack-device-001`
   - Pairing Code: `[8-digit code from device]`
4. Wait for pairing confirmation

### 4.3 Test Sensor Data Flow
1. Use the Device Testing screen
2. Start individual sensor tests
3. Verify data appears in:
   - Firebase Firestore console
   - AWS IoT Console (MQTT messages)
   - Flutter app (real-time updates)

### 4.4 Test Health Data Sync
1. Start a full health screening
2. Check Firebase Firestore collections:
   - `sensor_data` - Raw sensor readings
   - `users/{userId}/health_metrics` - Processed health data
   - `alerts` - Health alerts (if any thresholds exceeded)

---

## 🔍 Step 5: Monitoring and Debugging

### 5.1 AWS CloudWatch Logs
- Monitor Lambda function: `/aws/lambda/biotrack-iot-bridge`
- Check for errors in data processing

### 5.2 Firebase Console
- Monitor Firestore reads/writes
- Check real-time data updates
- Review user health metrics

### 5.3 ESP32 Serial Monitor
- Connection status messages
- MQTT publish/subscribe logs
- Sensor reading debug info

---

## 📊 Step 6: Data Flow Verification

### Expected Data Flow:
1. **ESP32** → Reads sensors → Publishes to AWS IoT Core
2. **AWS IoT Rules** → Trigger Lambda function
3. **Lambda Function** → Processes data → Stores in Firebase Firestore
4. **Flutter App** → Reads from Firestore → Displays to user

### Firestore Collections Structure:
```
sensor_data/
├── [documentId]
    ├── deviceId: "biotrack-device-001"
    ├── temperature: 36.5
    ├── heartRate: 72
    ├── timestamp: [timestamp]
    └── source: "aws_iot"

users/
├── [userId]
    └── health_metrics/
        ├── [metricId]
            ├── type: "temperature"
            ├── value: 36.5
            ├── unit: "°C"
            └── timestamp: [timestamp]

devices/
├── biotrack-device-001
    ├── status: "online"
    ├── userId: "[userId]"
    ├── lastSeen: [timestamp]
    └── lastReading: {...}
```

---

## 🚨 Troubleshooting

### Common Issues:

**1. ESP32 Not Connecting to AWS IoT**
- Verify certificates are correctly formatted
- Check WiFi credentials
- Ensure IoT endpoint is correct

**2. Lambda Function Errors**
- Check CloudWatch logs for detailed errors
- Verify Firebase service account credentials
- Ensure Firestore security rules allow writes

**3. Data Not Appearing in Firebase**
- Verify IoT Rules are active
- Check Lambda function execution
- Ensure device is publishing to correct topics

**4. Flutter App Not Receiving Data**
- Check Firebase initialization
- Verify Firestore listeners are set up correctly
- Ensure user authentication is working

### Debug Commands:
```powershell
# Test AWS IoT connectivity
aws iot-data publish --topic "biotrack/device/test-001/telemetry" --payload '{"temperature": 36.5}'

# Check Lambda logs
aws logs tail /aws/lambda/biotrack-iot-bridge --follow

# Test API Gateway
curl -X POST https://xxxxx.execute-api.us-east-1.amazonaws.com/prod/device/command -H "Content-Type: application/json" -d '{"deviceId":"biotrack-device-001","command":"ping"}'
```

---

## 🎯 Success Criteria

✅ **ESP32 Device**
- Connects to WiFi successfully
- Establishes secure connection to AWS IoT Core
- Publishes sensor data every 30 seconds
- Responds to commands from cloud

✅ **AWS Lambda**
- Processes IoT messages without errors
- Successfully stores data in Firebase Firestore
- Generates health alerts when thresholds exceeded

✅ **Flutter App**
- Can pair with devices
- Receives real-time health data
- Can send commands to devices
- Displays health metrics and alerts

✅ **Data Integration**
- End-to-end data flow working
- Real-time synchronization
- Proper error handling and retries

---

## 📈 Next Steps

1. **Scale Testing**: Test with multiple devices
2. **Performance Optimization**: Monitor and optimize data throughput
3. **Enhanced Security**: Implement certificate rotation
4. **Advanced Analytics**: Add ML models for health predictions
5. **Mobile Notifications**: Implement push notifications for alerts

---

## 📞 Support

For issues or questions:
1. Check AWS CloudWatch logs
2. Review Firebase Console for errors
3. Monitor ESP32 serial output
4. Test individual components separately

**Architecture Diagram:**
```
ESP32 → AWS IoT Core → Lambda → Firebase Firestore → Flutter App
  ↑                                     ↓
  └── Commands ← API Gateway ← Flutter App
```

This hybrid architecture provides the best of both worlds: AWS IoT's scalability and reliability for device communication, combined with Firebase's ease of use for app development and real-time data synchronization.
