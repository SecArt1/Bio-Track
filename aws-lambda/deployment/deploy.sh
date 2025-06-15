#!/bin/bash

# BioTrack AWS IoT Infrastructure Deployment Script
# This script deploys the AWS Lambda function and IoT infrastructure

set -e

PROJECT_NAME="biotrack"
STACK_NAME="${PROJECT_NAME}-iot-stack"
REGION="us-east-1"
FIREBASE_PROJECT_ID="bio-track-de846"

echo "🚀 Starting BioTrack AWS IoT deployment..."

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

# Get Firebase service account credentials
echo "📋 Please provide Firebase service account credentials:"
read -p "Firebase Client Email: " FIREBASE_CLIENT_EMAIL
read -s -p "Firebase Private Key (paste the entire key): " FIREBASE_PRIVATE_KEY
echo

# Create deployment package
echo "📦 Creating Lambda deployment package..."
npm install --production
zip -r biotrack-lambda.zip . -x '*.git*' 'node_modules/.cache/*' 'test/*' '*.md' 'deploy.sh' 'cloudformation-template.yaml'

# Upload Lambda code to S3 (create bucket if it doesn't exist)
S3_BUCKET="${PROJECT_NAME}-lambda-deployments-$(date +%s)"
echo "📤 Creating S3 bucket and uploading Lambda code..."
aws s3 mb s3://$S3_BUCKET --region $REGION
aws s3 cp biotrack-lambda.zip s3://$S3_BUCKET/biotrack-lambda.zip

# Deploy CloudFormation stack
echo "☁️ Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file cloudformation-template.yaml \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        ProjectName=$PROJECT_NAME \
        FirebaseProjectId=$FIREBASE_PROJECT_ID \
        FirebaseClientEmail="$FIREBASE_CLIENT_EMAIL" \
        FirebasePrivateKey="$FIREBASE_PRIVATE_KEY" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

# Update Lambda function code
echo "🔄 Updating Lambda function with actual code..."
LAMBDA_FUNCTION_NAME="${PROJECT_NAME}-iot-bridge"
aws lambda update-function-code \
    --function-name $LAMBDA_FUNCTION_NAME \
    --s3-bucket $S3_BUCKET \
    --s3-key biotrack-lambda.zip \
    --region $REGION

# Get stack outputs
echo "📋 Getting deployment information..."
IOT_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`IoTEndpoint`].OutputValue' \
    --output text)

API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`APIEndpoint`].OutputValue' \
    --output text)

DEVICE_POLICY=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`DevicePolicyName`].OutputValue' \
    --output text)

# Create device certificates (example for one device)
echo "🔐 Creating device certificates..."
DEVICE_NAME="${PROJECT_NAME}-device-001"
CERT_OUTPUT=$(aws iot create-keys-and-certificate \
    --set-as-active \
    --region $REGION)

CERT_ARN=$(echo $CERT_OUTPUT | jq -r '.certificateArn')
CERT_PEM=$(echo $CERT_OUTPUT | jq -r '.certificatePem')
PRIVATE_KEY=$(echo $CERT_OUTPUT | jq -r '.keyPair.PrivateKey')

# Create IoT Thing
aws iot create-thing \
    --thing-name $DEVICE_NAME \
    --region $REGION

# Attach policy to certificate
aws iot attach-policy \
    --policy-name $DEVICE_POLICY \
    --target $CERT_ARN \
    --region $REGION

# Attach certificate to thing
aws iot attach-thing-principal \
    --thing-name $DEVICE_NAME \
    --principal $CERT_ARN \
    --region $REGION

# Save certificates to files
mkdir -p certificates
echo "$CERT_PEM" > certificates/${DEVICE_NAME}-certificate.pem
echo "$PRIVATE_KEY" > certificates/${DEVICE_NAME}-private.key

# Download root CA
curl -o certificates/AmazonRootCA1.pem https://www.amazontrust.com/repository/AmazonRootCA1.pem

# Clean up
rm biotrack-lambda.zip
aws s3 rm s3://$S3_BUCKET/biotrack-lambda.zip
aws s3 rb s3://$S3_BUCKET

echo "✅ Deployment completed successfully!"
echo ""
echo "📋 Deployment Summary:"
echo "===================="
echo "IoT Endpoint: $IOT_ENDPOINT"
echo "API Endpoint: $API_ENDPOINT"
echo "Device Policy: $DEVICE_POLICY"
echo "Device Name: $DEVICE_NAME"
echo "Certificate ARN: $CERT_ARN"
echo ""
echo "📁 Certificate files saved in certificates/ directory:"
echo "  - ${DEVICE_NAME}-certificate.pem"
echo "  - ${DEVICE_NAME}-private.key"
echo "  - AmazonRootCA1.pem"
echo ""
echo "🔧 Next steps:"
echo "1. Update your ESP32 config.h with the IoT endpoint: $IOT_ENDPOINT"
echo "2. Update aws_certificates.h with the certificate content"
echo "3. Update your Flutter app to use the API endpoint: $API_ENDPOINT"
echo "4. Test the device connection and data flow"
