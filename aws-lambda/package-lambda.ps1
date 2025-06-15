# Advanced Lambda Packaging Script for BioTrack IoT Bridge
# Updated for user-specific data storage and improved deployment

param(
    [switch]$SkipTests,
    [switch]$DeployToAWS,
    [string]$FunctionName = "biotrack-iot-bridge",
    [string]$S3Bucket = ""
)

Write-Host "🚀 BioTrack Lambda Packaging & Deployment Script" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Check prerequisites
Write-Host "🔍 Checking prerequisites..." -ForegroundColor Yellow

# Check if Node.js is available
try {
    $nodeVersion = node --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Node.js version: $nodeVersion" -ForegroundColor Green
    } else {
        Write-Host "❌ Node.js not found. Please install Node.js first." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Node.js not found. Please install Node.js first." -ForegroundColor Red
    exit 1
}

# Check if dependencies are installed
if (!(Test-Path "node_modules")) {
    Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Dependencies installed" -ForegroundColor Green
}

# Run tests unless skipped
if (!$SkipTests) {
    Write-Host "🧪 Running comprehensive tests..." -ForegroundColor Yellow
    $env:USE_MOCK_FIREBASE = "true"
    
    # Test 1: Basic functionality
    Write-Host "  📊 Testing basic ESP32 data processing..." -ForegroundColor Gray
    node test-esp32-data.js
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Basic tests failed!" -ForegroundColor Red
        exit 1
    }
    
    # Test 2: User-specific functionality
    Write-Host "  👤 Testing user-specific data storage..." -ForegroundColor Gray
    if (Test-Path "test-user-functionality.js") {
        node test-user-functionality.js
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ User-specific tests failed!" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  ⚠️  User-specific test file not found, skipping..." -ForegroundColor Yellow
    }
    
    Write-Host "✅ All tests passed!" -ForegroundColor Green
} else {
    Write-Host "⏭️  Skipping tests..." -ForegroundColor Yellow
}

# Clean up old package
Write-Host "🧹 Cleaning up old packages..." -ForegroundColor Yellow
if (Test-Path "biotrack-lambda.zip") {
    Remove-Item "biotrack-lambda.zip" -Force
    Write-Host "  ✅ Removed old package" -ForegroundColor Gray
}

# Validate required files
$requiredFiles = @("index.js", "package.json")
foreach ($file in $requiredFiles) {
    if (!(Test-Path $file)) {
        Write-Host "❌ Required file missing: $file" -ForegroundColor Red
        exit 1
    }
}

# Create package
Write-Host "📦 Creating deployment package..." -ForegroundColor Yellow
$files = @("index.js", "package.json", "node_modules")

# Check if all files exist before packaging
$missingFiles = @()
foreach ($file in $files) {
    if (!(Test-Path $file)) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "❌ Missing files for packaging: $($missingFiles -join ', ')" -ForegroundColor Red
    exit 1
}

# Create the zip package
try {
    Compress-Archive -Path $files -DestinationPath "biotrack-lambda.zip" -Force
    Write-Host "✅ Package created successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create package: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Validate package
if (Test-Path "biotrack-lambda.zip") {
    $size = (Get-Item "biotrack-lambda.zip").Length / 1MB
    $sizeFormatted = $size.ToString("F2")
    Write-Host "📋 Package Details:" -ForegroundColor Cyan
    Write-Host "  📁 File: biotrack-lambda.zip" -ForegroundColor White
    Write-Host "  📏 Size: $sizeFormatted MB" -ForegroundColor White
    
    # Check if package is within AWS Lambda limits (50MB zipped, 250MB unzipped)
    if ($size -gt 50) {
        Write-Host "⚠️  Warning: Package size exceeds AWS Lambda limit (50MB)" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Failed to create package" -ForegroundColor Red
    exit 1
}

# Deploy to AWS if requested
if ($DeployToAWS) {
    Write-Host "🚀 Deploying to AWS Lambda..." -ForegroundColor Cyan
    
    # Check if AWS CLI is available
    try {
        $awsVersion = aws --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ AWS CLI available" -ForegroundColor Green
        } else {
            Write-Host "❌ AWS CLI not found. Please install AWS CLI first." -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "❌ AWS CLI not found. Please install AWS CLI first." -ForegroundColor Red
        exit 1
    }
    
    # Upload to S3 if bucket specified
    if ($S3Bucket) {
        Write-Host "📤 Uploading to S3 bucket: $S3Bucket..." -ForegroundColor Yellow
        aws s3 cp biotrack-lambda.zip "s3://$S3Bucket/biotrack-lambda.zip"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Uploaded to S3" -ForegroundColor Green
            
            # Update Lambda function from S3
            Write-Host "🔄 Updating Lambda function from S3..." -ForegroundColor Yellow
            aws lambda update-function-code --function-name $FunctionName --s3-bucket $S3Bucket --s3-key biotrack-lambda.zip
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Lambda function updated successfully!" -ForegroundColor Green
            } else {
                Write-Host "❌ Failed to update Lambda function" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "❌ Failed to upload to S3" -ForegroundColor Red
            exit 1
        }
    } else {
        # Direct upload to Lambda (for smaller packages)
        Write-Host "📤 Uploading directly to Lambda..." -ForegroundColor Yellow
        aws lambda update-function-code --function-name $FunctionName --zip-file "fileb://biotrack-lambda.zip"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Lambda function updated successfully!" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to update Lambda function" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""
Write-Host "🎉 Packaging Complete!" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green

if (!$DeployToAWS) {
    Write-Host "📋 Manual Deployment Steps:" -ForegroundColor Cyan
    Write-Host "1. Upload biotrack-lambda.zip to AWS Lambda Console" -ForegroundColor White
    Write-Host "2. Or use: .\package-lambda.ps1 -DeployToAWS -S3Bucket your-bucket-name" -ForegroundColor White
    Write-Host ""
}

Write-Host "⚙️  Required Environment Variables:" -ForegroundColor Cyan
Write-Host "• USE_MOCK_FIREBASE=false (for production)" -ForegroundColor White
Write-Host "• AWS_IOT_ENDPOINT=your-iot-endpoint" -ForegroundColor White
Write-Host "• FIREBASE_PROJECT_ID=bio-track-de846" -ForegroundColor White
Write-Host "• FIREBASE_PRIVATE_KEY=your-private-key" -ForegroundColor White
Write-Host "• FIREBASE_CLIENT_EMAIL=your-client-email" -ForegroundColor White
Write-Host ""

Write-Host "🔗 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Test device pairing with Flutter app" -ForegroundColor White
Write-Host "2. Verify user-specific data storage" -ForegroundColor White
Write-Host "3. Test ESP32 device connectivity" -ForegroundColor White
Write-Host "4. Monitor CloudWatch logs for any issues" -ForegroundColor White
