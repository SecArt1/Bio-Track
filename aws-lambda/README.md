# BioTrack AWS Lambda - IoT to Firebase Bridge

## 📁 Project Structure

```
aws-lambda/
├── 📦 Core Files
│   ├── index.js                           # Main Lambda function
│   ├── package.json                       # Node.js dependencies
│   ├── package-lock.json                  # Dependency lock file
│   └── biotrack-lambda.zip               # Deployment package (ready for AWS)
│
├── 🚀 Deployment
│   ├── DEPLOYMENT_GUIDE_COMPLETE.md       # Complete deployment instructions
│   ├── cloudformation-template.yaml       # AWS Infrastructure as Code
│   ├── package-lambda.ps1                # Script to create deployment package
│   └── check-deployment.ps1              # Verify deployment readiness
│
├── 🧪 Testing
│   ├── test-esp32-data.js                # Test with mock Firebase
│   └── test-real-firebase.js             # Test with Firebase emulator
│
├── 🔐 Configuration
│   ├── firebase-service-account-template.json  # Firebase credentials template
│   └── certificates/                     # AWS IoT device certificates
│       ├── AmazonRootCA1.pem
│       ├── biotrack-device-001-certificate.pem
│       └── biotrack-device-001-private.key
│
└── 📄 Documentation
    └── README.md                          # This file
```

## 🚀 Quick Start

### 1. Test the Lambda Function
```powershell
# Test with mock Firebase
node test-esp32-data.js

# Test with Firebase emulator (requires Firebase CLI)
firebase emulators:start --only firestore
node test-real-firebase.js
```

### 2. Deploy to AWS
```powershell
# Check deployment readiness
.\check-deployment.ps1

# Deploy manually or use CloudFormation (see DEPLOYMENT_GUIDE_COMPLETE.md)
```

## 📊 Lambda Function Features

- ✅ **Multi-sensor Support**: Temperature, heart rate, SpO2, weight, bioimpedance
- ✅ **Device Management**: Status updates, pairing, command responses
- ✅ **Health Monitoring**: Automatic alert generation based on sensor thresholds
- ✅ **Firebase Integration**: Real-time data sync with Firestore
- ✅ **AWS IoT Integration**: MQTT topic processing and device shadow management
- ✅ **Testing Modes**: Mock Firebase, emulator, and production support

## 🔧 Environment Variables

### Production (Real Firebase)
```
USE_MOCK_FIREBASE=false
FIREBASE_PROJECT_ID=bio-track-de846
FIREBASE_PRIVATE_KEY_ID=your_private_key_id
FIREBASE_PRIVATE_KEY=your_private_key
FIREBASE_CLIENT_EMAIL=your_service_account_email
FIREBASE_CLIENT_ID=your_client_id
FIREBASE_CLIENT_X509_CERT_URL=your_cert_url
AWS_IOT_ENDPOINT=your_iot_endpoint.iot.region.amazonaws.com
```

### Testing with Emulator
```
USE_MOCK_FIREBASE=false
FIRESTORE_EMULATOR_HOST=localhost:8080
```

### Testing with Mock
```
USE_MOCK_FIREBASE=true
```

## 📡 AWS IoT Topics

| Topic Pattern | Description | Example |
|---------------|-------------|---------|
| `biotrack/device/{deviceId}/telemetry` | Sensor data | Temperature, heart rate, SpO2 |
| `biotrack/device/{deviceId}/status` | Device status | Battery, signal strength, firmware |
| `biotrack/device/{deviceId}/responses` | Command responses | Pairing confirmations, calibration |
| `biotrack/device/{deviceId}/commands` | Device commands | Calibrate, pair, restart |

## 🏥 Health Data Processing

### Sensor Data Validation
- **Temperature**: 30-45°C range validation
- **Heart Rate**: 30-250 BPM range validation  
- **SpO2**: 0-100% range validation
- **Weight**: 0-500 kg range validation

### Health Alerts
- **Temperature**: < 36°C or > 38°C (High alert: < 35°C or > 39°C)
- **Heart Rate**: < 50 or > 120 BPM (High alert: < 40 or > 150 BPM)
- **SpO2**: < 95% (High alert: < 90%)

## 📋 Firestore Collections

- `sensor_data` - Raw sensor readings with metadata
- `devices` - Device registration and status
- `users/{userId}/health_metrics` - User-specific health data
- `alerts` - Health-based alerts and notifications
- `device_responses` - Command execution responses
- `device_status_history` - Historical device status updates

## 🛠️ Development Commands

```powershell
# Install dependencies
npm install

# Create deployment package
.\package-lambda.ps1

# Test locally
node test-esp32-data.js

# Start Firebase emulator
firebase emulators:start --only firestore

# Test with emulator
node test-real-firebase.js

# Check deployment status
.\check-deployment.ps1
```

## 📚 Documentation

- **[Complete Deployment Guide](DEPLOYMENT_GUIDE_COMPLETE.md)** - Step-by-step AWS deployment
- **[CloudFormation Template](cloudformation-template.yaml)** - Infrastructure as Code
- **[Firebase Template](firebase-service-account-template.json)** - Service account setup

## 🔒 Security Notes

1. **Never commit real Firebase service account credentials**
2. **Use AWS Systems Manager Parameter Store for sensitive data in production**
3. **Individual device certificates for AWS IoT Core**
4. **Proper Firestore security rules**
5. **IAM roles with least privilege principles**

## 📈 Monitoring

- **CloudWatch Logs**: `/aws/lambda/biotrack-iot-bridge`
- **Metrics**: Invocation count, duration, errors
- **Alerts**: Set up CloudWatch alarms for failures
- **Firebase**: Monitor Firestore read/write quotas

## 🚨 Troubleshooting

1. **Check CloudWatch logs** for Lambda execution details
2. **Verify environment variables** are correctly set
3. **Test with mock data first**, then real data
4. **Ensure IoT Rules** are properly configured
5. **Check Firebase connectivity** and permissions

---

**Status**: ✅ Ready for AWS deployment  
**Package**: `biotrack-lambda.zip` (34.1 MB)  
**Last Updated**: June 15, 2025

## Architecture Overview

```
ESP32 Devices → AWS IoT Core → Lambda Functions → Firebase Firestore ← Flutter App
                     ↓
              AWS API Gateway ← Flutter App (Device Commands)
```

## MQTT Topics
- `biotrack/device/{deviceId}/telemetry` - Sensor data
- `biotrack/device/{deviceId}/status` - Device status updates
- `biotrack/device/{deviceId}/responses` - Command responses

### Cloud to Device (AWS IoT → ESP32)
- `biotrack/device/{deviceId}/commands` - Device commands
- `$aws/thing/{thingName}/shadow/update/delta` - Shadow updates

### Device Shadow Topics
- `$aws/thing/{thingName}/shadow/update` - Update device shadow
- `$aws/thing/{thingName}/shadow/get` - Get device shadow

## Data Flow

### 1. Sensor Data Flow
```
ESP32 Sensor Reading → MQTT Publish → AWS IoT Rule → Lambda Function → Firebase Firestore
                                                                    ↓
                                           User Health Metrics Update → Alert Processing
```

### 2. Command Flow
```
Flutter App → API Gateway → Lambda Function → AWS IoT Publish → ESP32 Device
                                                               ↓
ESP32 Response → AWS IoT → Lambda Function → Firebase Firestore
```

### 3. Device Pairing Flow
```
Flutter App → QR Code/Pairing Code → ESP32 → AWS IoT → Lambda → Firebase User Association
```

## Security

### 1. AWS IoT Security
- X.509 certificates for device authentication
- IAM policies for resource access control
- TLS 1.2 encryption for all MQTT communications
- Device shadows for secure state management

### 2. Firebase Security
- Service account authentication for Lambda
- Firestore security rules for user data protection
- User authentication tokens for mobile app access

## Deployment Guide

### Prerequisites
- AWS CLI configured with appropriate permissions
- Firebase project with Firestore enabled
- Firebase service account credentials
- Node.js 18+ installed

### Step 1: Deploy AWS Infrastructure
```bash
cd aws-lambda
npm install
./deploy.sh  # Linux/Mac
# or
.\deploy.ps1  # Windows PowerShell
```

### Step 2: Configure ESP32
1. Update `esp32_firmware/include/config.h` with your IoT endpoint
2. Update `esp32_firmware/include/aws_certificates.h` with device certificates
3. Flash the firmware to your ESP32 device

### Step 3: Configure Flutter App
1. Update API endpoints in the app configuration
2. Ensure Firebase is properly initialized
3. Update device command functionality to use AWS API Gateway

## API Endpoints

### Device Command API
**Endpoint**: `https://{api-id}.execute-api.{region}.amazonaws.com/prod/device/command`

**Method**: POST

**Request Body**:
```json
{
  "deviceId": "biotrack-device-001",
  "command": "sensor_test",
  "parameters": {
    "sensorType": "temperature",
    "duration": 30
  }
}
```

**Response**:
```json
{
  "message": "Command sent successfully",
  "requestId": "550e8400-e29b-41d4-a716-446655440000"
}
```

## Monitoring and Debugging

### 1. AWS CloudWatch Logs
- Lambda function logs: `/aws/lambda/biotrack-iot-bridge`
- IoT Core logs: Enable IoT logging in AWS Console

### 2. Firebase Console
- Firestore data verification
- User activity monitoring
- Function execution logs

### 3. ESP32 Serial Monitor
- Connection status messages
- MQTT message logs
- Sensor reading debug info

## Troubleshooting

### Common Issues

1. **Device Not Connecting to AWS IoT**
   - Verify certificate and private key
   - Check IoT endpoint URL
   - Ensure device policy allows required actions

2. **Lambda Function Errors**
   - Check CloudWatch logs for detailed error messages
   - Verify Firebase service account credentials
   - Ensure IAM role has required permissions

3. **Data Not Appearing in Firebase**
   - Verify IoT Rules are active and properly configured
   - Check Lambda function execution in CloudWatch
   - Validate Firestore security rules

## Performance Considerations

### 1. MQTT Message Frequency
- Sensor data: Every 30 seconds
- Device heartbeat: Every 60 seconds
- Status updates: On state change

### 2. Lambda Function Optimization
- Use connection pooling for Firebase Admin SDK
- Implement proper error handling and retries
- Monitor function duration and memory usage

### 3. Firestore Optimization
- Use batch writes for multiple metrics
- Implement proper indexing for queries
- Consider read/write cost optimization

## Future Enhancements

1. **Multi-region Deployment**
   - AWS IoT device registry replication
   - Lambda function deployment in multiple regions

2. **Advanced Analytics**
   - AWS Kinesis for real-time data streaming
   - Machine learning models for health predictions

3. **Enhanced Security**
   - Certificate rotation automation
   - Enhanced device identity validation

4. **Scalability Improvements**
   - DynamoDB for high-frequency data
   - AWS IoT Device Management for fleet operations

## Cost Estimation

### AWS Services (Monthly)
- AWS IoT Core: $0.08 per 100K messages
- Lambda Functions: $0.20 per 1M requests
- API Gateway: $3.50 per 1M requests
- CloudWatch Logs: $0.50 per GB stored

### Firebase Services (Monthly)
- Firestore: $0.18 per 100K reads, $0.18 per 100K writes
- Firebase Functions: Included in Firebase plan

## Support and Maintenance

For support and maintenance:
1. Monitor AWS CloudWatch dashboards
2. Set up Firebase monitoring and alerting
3. Regular certificate rotation (annually)
4. Performance optimization reviews (quarterly)

---

## Quick Start Commands

```bash
# Deploy AWS infrastructure
cd aws-lambda && ./deploy.sh

# Update Lambda function code
aws lambda update-function-code --function-name biotrack-iot-bridge --zip-file fileb://biotrack-lambda.zip

# Create new device certificate
aws iot create-keys-and-certificate --set-as-active

# Test device connection
aws iot-data publish --topic "biotrack/device/test-001/telemetry" --payload '{"temperature": 36.5}'
```
