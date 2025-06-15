# BioTrack AWS Lambda Deployment Guide

## Overview

This guide covers the complete deployment of the BioTrack AWS Lambda function that bridges AWS IoT Core data to Firebase Firestore. The deployment package (`biotrack-lambda.zip`) is ready for deployment.

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Firebase Service Account** credentials
3. **AWS CLI** installed and configured (optional)
4. **Firebase Project** (`bio-track-de846`) set up

## Deployment Options

### Option 1: AWS Console Deployment (Recommended for First-Time Setup)

#### Step 1: Upload Lambda Function

1. **Open AWS Lambda Console**
   - Go to [AWS Lambda Console](https://console.aws.amazon.com/lambda/)
   - Click "Create function"

2. **Configure Function**
   - Choose "Author from scratch"
   - Function name: `biotrack-iot-bridge`
   - Runtime: `Node.js 18.x`
   - Architecture: `x86_64`
   - Click "Create function"

3. **Upload Deployment Package**
   - In the function overview, click "Upload from" → ".zip file"
   - Select `biotrack-lambda.zip` from your `aws-lambda` folder
   - Click "Save"

#### Step 2: Configure Environment Variables

In the Lambda function configuration, go to "Configuration" → "Environment variables" and add:

**Required for Production (Real Firebase):**
```
USE_MOCK_FIREBASE=false
FIREBASE_PROJECT_ID=bio-track-de846
FIREBASE_PRIVATE_KEY_ID=your_private_key_id
FIREBASE_PRIVATE_KEY=your_private_key_content
FIREBASE_CLIENT_EMAIL=your_service_account_email
FIREBASE_CLIENT_ID=your_client_id
FIREBASE_CLIENT_X509_CERT_URL=your_cert_url
AWS_IOT_ENDPOINT=your_iot_endpoint.iot.region.amazonaws.com
```

**For Testing with Firebase Emulator:**
```
USE_MOCK_FIREBASE=false
FIRESTORE_EMULATOR_HOST=localhost:8080
```

**For Testing with Mock Firebase:**
```
USE_MOCK_FIREBASE=true
```

#### Step 3: Configure Function Settings

1. **Timeout**: Set to 60 seconds (Configuration → General configuration)
2. **Memory**: Set to 256 MB (or higher if needed)
3. **Execution Role**: Create or use existing role with these permissions:
   - `AWSLambdaBasicExecutionRole` (managed policy)
   - Custom policy for IoT operations:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iot:Publish",
                "iot:Subscribe",
                "iot:Connect",
                "iot:Receive",
                "iot:GetThingShadow",
                "iot:UpdateThingShadow"
            ],
            "Resource": "*"
        }
    ]
}
```

#### Step 4: Set Up AWS IoT Rules

1. **Create IoT Rules** in [AWS IoT Console](https://console.aws.amazon.com/iot/):

**Telemetry Rule:**
- Rule name: `biotrack_telemetry_rule`
- SQL statement: `SELECT *, topic() as topic, timestamp() as timestamp FROM 'biotrack/device/+/telemetry'`
- Action: Lambda function → Select your `biotrack-iot-bridge` function

**Status Rule:**
- Rule name: `biotrack_status_rule`
- SQL statement: `SELECT *, topic() as topic, timestamp() as timestamp FROM 'biotrack/device/+/status'`
- Action: Lambda function → Select your `biotrack-iot-bridge` function

**Response Rule:**
- Rule name: `biotrack_response_rule`
- SQL statement: `SELECT *, topic() as topic, timestamp() as timestamp FROM 'biotrack/device/+/responses'`
- Action: Lambda function → Select your `biotrack-iot-bridge` function

#### Step 5: Create IoT Device Policy

Create an IoT policy named `biotrack-device-policy`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iot:Connect",
      "Resource": "arn:aws:iot:*:*:client/biotrack-device-*"
    },
    {
      "Effect": "Allow",
      "Action": "iot:Publish",
      "Resource": [
        "arn:aws:iot:*:*:topic/biotrack/device/*/telemetry",
        "arn:aws:iot:*:*:topic/biotrack/device/*/status",
        "arn:aws:iot:*:*:topic/biotrack/device/*/responses",
        "arn:aws:iot:*:*:topic/$aws/thing/*/shadow/update",
        "arn:aws:iot:*:*:topic/$aws/thing/*/shadow/get"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "iot:Subscribe",
      "Resource": [
        "arn:aws:iot:*:*:topicfilter/biotrack/device/*/commands",
        "arn:aws:iot:*:*:topicfilter/$aws/thing/*/shadow/update/delta",
        "arn:aws:iot:*:*:topicfilter/$aws/thing/*/shadow/get/accepted"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "iot:Receive",
      "Resource": [
        "arn:aws:iot:*:*:topic/biotrack/device/*/commands",
        "arn:aws:iot:*:*:topic/$aws/thing/*/shadow/update/delta",
        "arn:aws:iot:*:*:topic/$aws/thing/*/shadow/get/accepted"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "iot:GetThingShadow",
        "iot:UpdateThingShadow"
      ],
      "Resource": "arn:aws:iot:*:*:thing/biotrack-device-*"
    }
  ]
}
```

### Option 2: CloudFormation Deployment (Infrastructure as Code)

#### Step 1: Prepare CloudFormation Template

The `cloudformation-template.yaml` file is ready for deployment. You'll need to update the Lambda function code after stack creation.

#### Step 2: Deploy CloudFormation Stack

```powershell
# Using AWS CLI
aws cloudformation create-stack \
  --stack-name biotrack-iot-stack \
  --template-body file://cloudformation-template.yaml \
  --parameters ParameterKey=FirebaseProjectId,ParameterValue=bio-track-de846 \
               ParameterKey=FirebasePrivateKey,ParameterValue="your_private_key" \
               ParameterKey=FirebaseClientEmail,ParameterValue="your_client_email" \
  --capabilities CAPABILITY_NAMED_IAM
```

#### Step 3: Update Lambda Function Code

After stack creation, update the Lambda function with your deployment package:

```powershell
aws lambda update-function-code \
  --function-name biotrack-iot-bridge \
  --zip-file fileb://biotrack-lambda.zip
```

## Testing the Deployment

### Test 1: Mock Firebase Mode

Set environment variable: `USE_MOCK_FIREBASE=true`

Test with sample payload:
```powershell
# From aws-lambda directory
node test-esp32-data.js
```

### Test 2: Firebase Emulator Mode

1. Start Firebase emulator:
```powershell
firebase emulators:start --only firestore
```

2. Set environment variables:
```
USE_MOCK_FIREBASE=false
FIRESTORE_EMULATOR_HOST=localhost:8080
```

3. Test with emulator:
```powershell
node test-real-firebase.js
```

### Test 3: Production Firebase Mode

1. Set all Firebase service account environment variables
2. Set `USE_MOCK_FIREBASE=false`
3. Remove `FIRESTORE_EMULATOR_HOST` variable
4. Test with production Firebase

### Test 4: AWS IoT Integration Test

Use AWS IoT Console → Test → MQTT test client:

1. **Publish test message to**: `biotrack/device/test-device-01/telemetry`

2. **Sample payload**:
```json
{
  "deviceId": "test-device-01",
  "temperature": 36.8,
  "heartRate": 72,
  "weight": 70.5,
  "spO2": 98,
  "bioimpedance": {
    "impedance": 500,
    "bodyFat": 15.2,
    "muscleMass": 35.8
  },
  "batteryLevel": 85,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

3. **Check CloudWatch Logs** for Lambda execution
4. **Verify Firestore** data (or emulator UI) for stored sensor data

## Monitoring and Troubleshooting

### CloudWatch Logs

Monitor Lambda execution:
- Go to CloudWatch → Log groups → `/aws/lambda/biotrack-iot-bridge`
- Check for errors, execution time, and data processing logs

### Common Issues

1. **Environment Variables**: Ensure all Firebase credentials are properly set
2. **IAM Permissions**: Verify Lambda execution role has necessary permissions
3. **IoT Rules**: Check rule SQL statements and Lambda permissions
4. **Firebase Connectivity**: Test with emulator first, then production

### Health Check Endpoints

The Lambda function supports health check via API Gateway (if configured):
- GET `/health` - Returns function status
- POST `/device/command` - Send commands to devices

## Security Considerations

1. **Environment Variables**: Use AWS Systems Manager Parameter Store for sensitive data
2. **IAM Roles**: Follow principle of least privilege
3. **Firebase Rules**: Ensure proper Firestore security rules
4. **Device Certificates**: Use individual certificates per device
5. **Network Security**: Consider VPC deployment for additional isolation

## Performance Optimization

1. **Memory Allocation**: Monitor and adjust based on usage
2. **Timeout Settings**: Set appropriate timeouts for Firebase operations
3. **Connection Pooling**: Lambda function reuses Firebase connections
4. **Batch Operations**: Process multiple sensor readings efficiently

## Scaling Considerations

1. **Lambda Concurrency**: Monitor and set reserved concurrency if needed
2. **Firebase Quotas**: Monitor Firestore read/write quotas
3. **IoT Device Limits**: Consider AWS IoT Core device limits
4. **Cost Optimization**: Monitor costs and optimize resource usage

## Next Steps

1. **Deploy to Production**: Follow Option 1 or 2 above
2. **Configure ESP32 Devices**: Update firmware with AWS IoT certificates
3. **Test End-to-End**: Send real sensor data from ESP32
4. **Monitor Performance**: Set up CloudWatch alarms
5. **Implement CI/CD**: Automate deployment process

## Support

For issues or questions:
1. Check CloudWatch logs for Lambda execution details
2. Verify Firebase connection and permissions
3. Test with mock data first, then real data
4. Ensure all environment variables are correctly set
