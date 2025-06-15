# BioTrack Lambda Deployment Verification Script
Write-Host "=== BioTrack AWS Lambda Deployment Verification ===" -ForegroundColor Cyan
Write-Host ""

# Check if deployment package exists
$packagePath = ".\biotrack-lambda.zip"
if (Test-Path $packagePath) {
    $packageSize = (Get-Item $packagePath).Length
    Write-Host "✓ Deployment package found: $packagePath" -ForegroundColor Green
    Write-Host "  Package size: $([math]::Round($packageSize/1MB, 2)) MB" -ForegroundColor Gray
} else {
    Write-Host "✗ Deployment package not found: $packagePath" -ForegroundColor Red
    Write-Host "  Run package-lambda.ps1 first to create the deployment package" -ForegroundColor Yellow
    exit 1
}

# Check if required files exist
$requiredFiles = @("index.js", "package.json", "DEPLOYMENT_GUIDE_COMPLETE.md")
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✓ $file exists" -ForegroundColor Green
    } else {
        Write-Host "✗ $file missing" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Firebase Service Account Setup ===" -ForegroundColor Cyan

# Check for Firebase service account template
if (Test-Path "firebase-service-account-template.json") {
    Write-Host "✓ Firebase service account template found" -ForegroundColor Green
    Write-Host "  Please fill in your actual Firebase service account credentials" -ForegroundColor Yellow
} else {
    Write-Host "✗ Firebase service account template not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Next Steps for AWS Deployment ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Manual Deployment (AWS Console):" -ForegroundColor Yellow
Write-Host "   a) Go to AWS Lambda Console" -ForegroundColor White
Write-Host "   b) Create new function: biotrack-iot-bridge" -ForegroundColor White
Write-Host "   c) Upload biotrack-lambda.zip" -ForegroundColor White
Write-Host "   d) Set environment variables" -ForegroundColor White
Write-Host "   e) Create IoT Rules to trigger the Lambda function" -ForegroundColor White
Write-Host ""

Write-Host "2. CloudFormation Deployment:" -ForegroundColor Yellow
Write-Host "   a) Review cloudformation-template.yaml" -ForegroundColor White
Write-Host "   b) Deploy stack with Firebase credentials as parameters" -ForegroundColor White
Write-Host "   c) Update Lambda function code with biotrack-lambda.zip" -ForegroundColor White
Write-Host ""

Write-Host "3. Environment Variables Required:" -ForegroundColor Yellow
Write-Host "   USE_MOCK_FIREBASE=false" -ForegroundColor White
Write-Host "   FIREBASE_PROJECT_ID=bio-track-de846" -ForegroundColor White
Write-Host "   FIREBASE_PRIVATE_KEY_ID=your_key_id" -ForegroundColor White
Write-Host "   FIREBASE_PRIVATE_KEY=your_private_key" -ForegroundColor White
Write-Host "   FIREBASE_CLIENT_EMAIL=your_service_account_email" -ForegroundColor White
Write-Host "   FIREBASE_CLIENT_ID=your_client_id" -ForegroundColor White
Write-Host "   FIREBASE_CLIENT_X509_CERT_URL=your_cert_url" -ForegroundColor White
Write-Host "   AWS_IOT_ENDPOINT=your_iot_endpoint" -ForegroundColor White
Write-Host ""

Write-Host "=== AWS IoT Topics for Testing ===" -ForegroundColor Cyan
Write-Host "Telemetry: biotrack/device/test-device-01/telemetry" -ForegroundColor Gray
Write-Host "Status:    biotrack/device/test-device-01/status" -ForegroundColor Gray
Write-Host "Response:  biotrack/device/test-device-01/responses" -ForegroundColor Gray
Write-Host "Commands:  biotrack/device/test-device-01/commands" -ForegroundColor Gray
Write-Host ""

Write-Host "📖 Complete deployment guide: DEPLOYMENT_GUIDE_COMPLETE.md" -ForegroundColor Green
Write-Host "🚀 Ready for AWS Lambda deployment!" -ForegroundColor Green
