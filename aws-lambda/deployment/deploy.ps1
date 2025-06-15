# BioTrack AWS IoT Infrastructure Deployment Script (PowerShell)
# This script deploys the AWS Lambda function and IoT infrastructure

param(
    [string]$ProjectName = "biotrack",
    [string]$Region = "us-east-1",
    [string]$FirebaseProjectId = "bio-track-de846"
)

$StackName = "$ProjectName-iot-stack"

Write-Host "🚀 Starting BioTrack AWS IoT deployment..." -ForegroundColor Green

# Check if AWS CLI is installed
try {
    aws --version | Out-Null
} catch {
    Write-Host "❌ AWS CLI is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

# Check if AWS credentials are configured
try {
    aws sts get-caller-identity | Out-Null
} catch {
    Write-Host "❌ AWS credentials not configured. Please run 'aws configure' first." -ForegroundColor Red
    exit 1
}

# Get Firebase service account credentials
Write-Host "📋 Please provide Firebase service account credentials:" -ForegroundColor Yellow
$FirebaseClientEmail = Read-Host "Firebase Client Email"
$FirebasePrivateKey = Read-Host "Firebase Private Key (paste the entire key)" -AsSecureString
$FirebasePrivateKeyPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($FirebasePrivateKey))

# Create deployment package
Write-Host "📦 Creating Lambda deployment package..." -ForegroundColor Blue

# Install dependencies
npm install

# Test with mock Firebase first
Write-Host "🧪 Running tests with mock Firebase..." -ForegroundColor Yellow
$env:USE_MOCK_FIREBASE = "true"
node test-esp32-data.js

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Tests failed" -ForegroundColor Red
    exit 1
}

if (Test-Path "biotrack-lambda.zip") {
    Remove-Item "biotrack-lambda.zip"
}

# Create zip file (Windows)
Compress-Archive -Path ".\*" -DestinationPath "biotrack-lambda.zip" -Exclude @("*.git*", "node_modules\.cache\*", "test\*", "*.md", "deploy.ps1", "deploy.sh", "cloudformation-template.yaml")

# Upload Lambda code to S3
$S3Bucket = "$ProjectName-lambda-deployments-$(Get-Date -Format 'yyyyMMddHHmmss')"
Write-Host "📤 Creating S3 bucket and uploading Lambda code..." -ForegroundColor Blue
aws s3 mb "s3://$S3Bucket" --region $Region
aws s3 cp "biotrack-lambda.zip" "s3://$S3Bucket/biotrack-lambda.zip"

# Deploy CloudFormation stack
Write-Host "☁️ Deploying CloudFormation stack..." -ForegroundColor Blue
aws cloudformation deploy `
    --template-file cloudformation-template.yaml `
    --stack-name $StackName `
    --parameter-overrides `
        "ProjectName=$ProjectName" `
        "FirebaseProjectId=$FirebaseProjectId" `
        "FirebaseClientEmail=$FirebaseClientEmail" `
        "FirebasePrivateKey=$FirebasePrivateKeyPlain" `
    --capabilities CAPABILITY_NAMED_IAM `
    --region $Region

# Update Lambda function code
Write-Host "🔄 Updating Lambda function with actual code..." -ForegroundColor Blue
$LambdaFunctionName = "$ProjectName-iot-bridge"
aws lambda update-function-code `
    --function-name $LambdaFunctionName `
    --s3-bucket $S3Bucket `
    --s3-key biotrack-lambda.zip `
    --region $Region

# Get stack outputs
Write-Host "📋 Getting deployment information..." -ForegroundColor Blue
$IoTEndpoint = aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --query 'Stacks[0].Outputs[?OutputKey==`IoTEndpoint`].OutputValue' `
    --output text

$APIEndpoint = aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --query 'Stacks[0].Outputs[?OutputKey==`APIEndpoint`].OutputValue' `
    --output text

$DevicePolicy = aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --query 'Stacks[0].Outputs[?OutputKey==`DevicePolicyName`].OutputValue' `
    --output text

# Create device certificates
Write-Host "🔐 Creating device certificates..." -ForegroundColor Blue
$DeviceName = "$ProjectName-device-001"
$CertOutput = aws iot create-keys-and-certificate `
    --set-as-active `
    --region $Region | ConvertFrom-Json

$CertArn = $CertOutput.certificateArn
$CertPem = $CertOutput.certificatePem
$PrivateKey = $CertOutput.keyPair.PrivateKey

# Create IoT Thing
aws iot create-thing `
    --thing-name $DeviceName `
    --region $Region

# Attach policy to certificate
aws iot attach-policy `
    --policy-name $DevicePolicy `
    --target $CertArn `
    --region $Region

# Attach certificate to thing
aws iot attach-thing-principal `
    --thing-name $DeviceName `
    --principal $CertArn `
    --region $Region

# Save certificates to files
if (!(Test-Path "certificates")) {
    New-Item -ItemType Directory -Name "certificates"
}

$CertPem | Out-File -FilePath "certificates\$DeviceName-certificate.pem" -Encoding UTF8
$PrivateKey | Out-File -FilePath "certificates\$DeviceName-private.key" -Encoding UTF8

# Download root CA
Invoke-WebRequest -Uri "https://www.amazontrust.com/repository/AmazonRootCA1.pem" -OutFile "certificates\AmazonRootCA1.pem"

# Clean up
Remove-Item "biotrack-lambda.zip"
aws s3 rm "s3://$S3Bucket/biotrack-lambda.zip"
aws s3 rb "s3://$S3Bucket"

Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Deployment Summary:" -ForegroundColor Cyan
Write-Host "===================="
Write-Host "IoT Endpoint: $IoTEndpoint"
Write-Host "API Endpoint: $APIEndpoint"
Write-Host "Device Policy: $DevicePolicy"
Write-Host "Device Name: $DeviceName"
Write-Host "Certificate ARN: $CertArn"
Write-Host ""
Write-Host "📁 Certificate files saved in certificates/ directory:" -ForegroundColor Yellow
Write-Host "  - $DeviceName-certificate.pem"
Write-Host "  - $DeviceName-private.key"
Write-Host "  - AmazonRootCA1.pem"
Write-Host ""
Write-Host "🔧 Next steps:" -ForegroundColor Magenta
Write-Host "1. Update your ESP32 config.h with the IoT endpoint: $IoTEndpoint"
Write-Host "2. Update aws_certificates.h with the certificate content"
Write-Host "3. Update your Flutter app to use the API endpoint: $APIEndpoint"
Write-Host "4. Test the device connection and data flow"
