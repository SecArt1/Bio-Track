# AWS Infrastructure Discovery Report
# Generated: $(Get-Date)
# Account: 447191070724
# Primary Region: eu-central-1

Write-Host "=== AWS BIOTRACK INFRASTRUCTURE DISCOVERY ===" -ForegroundColor Green
Write-Host ""

$account = "447191070724"
$primaryRegion = "eu-central-1"

Write-Host "Account ID: $account" -ForegroundColor Yellow
Write-Host "Primary Region: $primaryRegion" -ForegroundColor Yellow
Write-Host ""

# API Gateway Details
Write-Host "API GATEWAY CONFIGURATION:" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
$apiId = "isjd26qkie"
$apiName = "biotrack-api"
$stage = "prod"
$apiUrl = "https://$apiId.execute-api.$primaryRegion.amazonaws.com/$stage"

Write-Host "API ID: $apiId"
Write-Host "API Name: $apiName"
Write-Host "Stage: $stage"
Write-Host "Full URL: $apiUrl"
Write-Host "Endpoints:"
Write-Host "  - GET  $apiUrl/health"
Write-Host "  - POST $apiUrl/device/command"
Write-Host ""

# IoT Core Details
Write-Host "AWS IOT CORE CONFIGURATION:" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan
$iotEndpoint = "azvqnnby4qrmz-ats.iot.eu-central-1.amazonaws.com"
$thingName = "biotrack-device-001"
$certificateId = "7f024911d9857e9882fbdb1a4b469259cb99247e795c99c2d4374b952f9e1737"

Write-Host "IoT Endpoint: $iotEndpoint"
Write-Host "Thing Name: $thingName"
Write-Host "Certificate ID: $certificateId"
Write-Host "Policy: biotrack-device-policy"
Write-Host ""
Write-Host "MQTT Topics:"
Write-Host "  - biotrack/device/+/telemetry (telemetry data)"
Write-Host "  - biotrack/device/+/status (device status)"
Write-Host "  - biotrack/device/+/commands (device commands)"
Write-Host "  - biotrack/device/+/responses (command responses)"
Write-Host ""

# Lambda Function Details
Write-Host "LAMBDA FUNCTION CONFIGURATION:" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
$functionName = "biotrack-iot-bridge"
$functionArn = "arn:aws:lambda:eu-central-1:447191070724:function:biotrack-iot-bridge"
$runtime = "nodejs18.x"

Write-Host "Function Name: $functionName"
Write-Host "Function ARN: $functionArn"
Write-Host "Runtime: $runtime"
Write-Host "Timeout: 60 seconds"
Write-Host "Memory: 256 MB"
Write-Host ""

# IAM Role Details
Write-Host "IAM CONFIGURATION:" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan
$lambdaRole = "arn:aws:iam::447191070724:role/biotrack-lambda-role"

Write-Host "Lambda Role: $lambdaRole"
Write-Host ""

# IoT Rules
Write-Host "IOT RULES:" -ForegroundColor Cyan
Write-Host "==========" -ForegroundColor Cyan
Write-Host "1. biotrack_telemetry_rule"
Write-Host "   - Topic: biotrack/device/+/telemetry"
Write-Host "   - Action: Trigger Lambda function"
Write-Host ""
Write-Host "2. biotrack_status_rule"
Write-Host "   - Topic: biotrack/device/+/status"
Write-Host "   - Action: Trigger Lambda function"
Write-Host ""

# Firebase Integration
Write-Host "FIREBASE INTEGRATION:" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host "Project ID: bio-track-de846"
Write-Host "Service Account: firebase-adminsdk-fbsvc@bio-track-de846.iam.gserviceaccount.com"
Write-Host "Realtime Database: bio-track-de846-default-rtdb.firebaseio.com"
Write-Host ""

Write-Host "=== CONFIGURATION FILES TO UPDATE ===" -ForegroundColor Green
Write-Host ""

@"
ESP32 CONFIG.H UPDATES NEEDED:
==============================
#define AWS_IOT_ENDPOINT "$iotEndpoint"
#define AWS_API_GATEWAY_URL "$apiUrl"
#define AWS_REGION "$primaryRegion"
#define DEVICE_ID "$thingName"
#define AWS_IOT_THING_NAME "$thingName"

CERTIFICATE FILES NEEDED:
========================
- AWS Root CA Certificate
- Device Certificate (from cert ID: $certificateId)
- Device Private Key

API ENDPOINTS:
==============
Health Check: $apiUrl/health
Device Command: $apiUrl/device/command

MQTT TOPICS:
============
Telemetry: biotrack/device/$thingName/telemetry
Status: biotrack/device/$thingName/status
Commands: biotrack/device/$thingName/commands
Responses: biotrack/device/$thingName/responses
"@ | Write-Host -ForegroundColor Gray
