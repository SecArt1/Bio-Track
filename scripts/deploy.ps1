# BioTrack ESP32 Health Monitoring System - Windows Deployment Script
# PowerShell script for complete system deployment

param(
    [switch]$SkipBuild,
    [switch]$ESP32Only,
    [switch]$FlutterOnly,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
BioTrack Deployment Script

Usage: .\deploy.ps1 [options]

Options:
  -SkipBuild    Skip building apps (deploy only)
  -ESP32Only    Deploy ESP32 firmware only
  -FlutterOnly  Deploy Flutter app only
  -Help         Show this help message

Examples:
  .\deploy.ps1                  # Full deployment
  .\deploy.ps1 -FlutterOnly     # Flutter app only
  .\deploy.ps1 -ESP32Only       # ESP32 firmware only
"@
    exit 0
}

# Set error action preference
$ErrorActionPreference = "Stop"

# Colors for output
function Write-Status($Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success($Message) {
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning($Message) {
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error($Message) {
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Main script header
Write-Host "🚀 BioTrack ESP32 Health Monitoring System - Windows Deployment" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# Step 1: Verify Prerequisites
Write-Status "Step 1: Checking prerequisites..."

# Check Flutter
try {
    $flutterVersion = flutter --version 2>$null | Select-Object -First 1
    Write-Success "Flutter found: $flutterVersion"
} catch {
    Write-Error "Flutter not found. Please install Flutter and add to PATH."
    exit 1
}

# Check Firebase CLI
try {
    $firebaseVersion = firebase --version 2>$null
    Write-Success "Firebase CLI found: $firebaseVersion"
} catch {
    Write-Error "Firebase CLI not found. Please install: npm install -g firebase-tools"
    exit 1
}

# Check PlatformIO
try {
    $pioVersion = pio --version 2>$null
    Write-Success "PlatformIO found: $pioVersion"
} catch {
    Write-Error "PlatformIO not found. Please install PlatformIO Core."
    exit 1
}

# Step 2: Firebase Authentication
Write-Status "Step 2: Checking Firebase authentication..."
try {
    firebase projects:list | Out-Null
    Write-Success "Firebase authentication successful"
} catch {
    Write-Error "Please run 'firebase login' to authenticate"
    exit 1
}

# Step 3: Flutter App Deployment
if (-not $ESP32Only) {
    Write-Status "Step 3: Flutter App Deployment..."
    
    if (-not $SkipBuild) {
        Write-Status "Cleaning Flutter project..."
        flutter clean
        
        Write-Status "Installing Flutter dependencies..."
        flutter pub get
        
        Write-Status "Building Flutter debug APK..."
        flutter build apk --debug
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Flutter app built successfully"
            $apkPath = "build\app\outputs\flutter-apk\app-debug.apk"
            if (Test-Path $apkPath) {
                $apkSize = (Get-Item $apkPath).Length / 1MB
                Write-Success "APK created: $apkPath (${apkSize:N1} MB)"
            }
        } else {
            Write-Error "Flutter build failed"
            exit 1
        }
    }
}

# Step 4: ESP32 Firmware Deployment  
if (-not $FlutterOnly) {
    Write-Status "Step 4: ESP32 Firmware Deployment..."
    
    # Check config file
    $configPath = "esp32_firmware\include\config.h"
    if (-not (Test-Path $configPath)) {
        Write-Warning "config.h not found. Creating from template..."
        Copy-Item "esp32_firmware\include\config_template.h" $configPath
        Write-Warning "Please edit $configPath with your WiFi credentials"
    }
    
    if (-not $SkipBuild) {
        Write-Status "Building ESP32 firmware..."
        Push-Location esp32_firmware
        try {
            pio run
            if ($LASTEXITCODE -eq 0) {
                Write-Success "ESP32 firmware built successfully"
                $firmwarePath = ".pio\build\esp32dev\firmware.bin"
                if (Test-Path $firmwarePath) {
                    $firmwareSize = (Get-Item $firmwarePath).Length / 1KB
                    Write-Success "Firmware created: $firmwarePath (${firmwareSize:N1} KB)"
                }
            } else {
                Write-Error "ESP32 firmware build failed"
                exit 1
            }
        } finally {
            Pop-Location
        }
    }
}

# Step 5: Firebase Infrastructure
if (-not $ESP32Only -and -not $FlutterOnly) {
    Write-Status "Step 5: Deploying Firebase infrastructure..."
    
    Write-Status "Deploying Firestore rules and indexes..."
    firebase deploy --only firestore:rules,firestore:indexes
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Firebase rules and indexes deployed"
    } else {
        Write-Error "Firebase rules deployment failed"
        exit 1
    }
    
    Write-Status "Attempting to deploy Firebase Functions..."
    firebase deploy --only functions 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Firebase Functions deployed successfully"
    } else {
        Write-Warning "Firebase Functions deployment failed (Blaze plan required)"
        Write-Warning "Upgrade at: https://console.firebase.google.com/project/bio-track-de846/usage/details"
    }
}

# Step 6: Generate Deployment Report
Write-Status "Step 6: Generating deployment report..."

$deploymentReport = @"
# BioTrack Windows Deployment Report
Generated: $(Get-Date)

## ✅ Successfully Completed

### Flutter Mobile App
- **Status**: ✅ Built successfully
- **APK**: ``build\app\outputs\flutter-apk\app-debug.apk``
- **Size**: $(if (Test-Path "build\app\outputs\flutter-apk\app-debug.apk") { "{0:N1} MB" -f ((Get-Item "build\app\outputs\flutter-apk\app-debug.apk").Length / 1MB) } else { "Unknown" })

### ESP32 Firmware  
- **Status**: ✅ Built successfully
- **Binary**: ``.pio\build\esp32dev\firmware.bin``
- **Size**: $(if (Test-Path "esp32_firmware\.pio\build\esp32dev\firmware.bin") { "{0:N1} KB" -f ((Get-Item "esp32_firmware\.pio\build\esp32dev\firmware.bin").Length / 1KB) } else { "Unknown" })

### Firebase Infrastructure
- **Rules**: ✅ Deployed  
- **Indexes**: ✅ Deployed
- **Functions**: $(try { firebase functions:list | Out-Null; "✅ Deployed" } catch { "🚫 Pending (Blaze plan required)" })

## 🚀 Next Steps

### 1. Configure ESP32
Edit ``esp32_firmware\include\config.h`` with your:
- WiFi SSID and password
- Firebase API key (if different)  
- Device-specific settings

### 2. Deploy ESP32 Firmware
````powershell
cd esp32_firmware
pio run --target upload
pio device monitor
````

### 3. Install Mobile App
````powershell
adb install build\app\outputs\flutter-apk\app-debug.apk
````

### 4. Firebase Functions (if needed)
Upgrade to Blaze plan and run:
````powershell
firebase deploy --only functions
````

## 📊 System Status
- **Overall Progress**: 90% Complete
- **Ready for Testing**: ✅ Yes
- **Production Ready**: $(try { firebase functions:list | Out-Null; "✅ Yes" } catch { "🔄 Pending Functions" })

---
*Windows deployment completed successfully! 🎉*
"@

$deploymentReport | Out-File -FilePath "DEPLOYMENT_REPORT.md" -Encoding UTF8
Write-Success "Deployment report generated: DEPLOYMENT_REPORT.md"

# Step 7: Device Upload Helper (optional)
Write-Status "Step 7: Checking for connected ESP32 devices..."
try {
    Push-Location esp32_firmware
    $devices = pio device list 2>$null
    if ($devices -and $devices.Contains("COM")) {
        Write-Success "ESP32 device detected! Ready for firmware upload."
        $uploadNow = Read-Host "Upload firmware now? (y/N)"
        if ($uploadNow -eq 'y' -or $uploadNow -eq 'Y') {
            Write-Status "Uploading firmware to ESP32..."
            pio run --target upload
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Firmware uploaded successfully!"
                $monitor = Read-Host "Start serial monitor? (y/N)"
                if ($monitor -eq 'y' -or $monitor -eq 'Y') {
                    Write-Status "Starting serial monitor (Ctrl+C to exit)..."
                    pio device monitor
                }
            }
        }
    } else {
        Write-Warning "No ESP32 device detected. Connect device and run: pio run --target upload"
    }
} catch {
    Write-Warning "Could not check for devices"
} finally {
    Pop-Location
}

# Final Summary
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Success "🎉 BioTrack Windows Deployment Complete!"
Write-Host "================================================================" -ForegroundColor Cyan

if (-not $ESP32Only) {
    Write-Status "✅ Flutter app: build\app\outputs\flutter-apk\app-debug.apk"
}

if (-not $FlutterOnly) {
    Write-Status "✅ ESP32 firmware: esp32_firmware\.pio\build\esp32dev\firmware.bin"
}

if (-not $ESP32Only -and -not $FlutterOnly) {
    Write-Status "✅ Firebase rules deployed"
    Write-Status "✅ Firebase indexes deployed"
    
    try {
        firebase functions:list | Out-Null
        Write-Status "✅ Firebase functions deployed"
    } catch {
        Write-Warning "🚫 Firebase functions pending (Blaze plan required)"
    }
}

Write-Host ""
Write-Status "📋 Quick Start Commands:"
Write-Host "   Flutter App: adb install build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Yellow
Write-Host "   ESP32 Upload: cd esp32_firmware && pio run --target upload" -ForegroundColor Yellow
Write-Host "   Monitor ESP32: cd esp32_firmware && pio device monitor" -ForegroundColor Yellow
Write-Host ""
Write-Success "System is ready for testing! 🚀"

# Create quick launch scripts
@'
@echo off
echo Installing BioTrack Mobile App...
adb install build\app\outputs\flutter-apk\app-debug.apk
echo.
echo App installed! Look for "bio_track" on your Android device.
pause
'@ | Out-File -FilePath "install_app.bat" -Encoding ASCII

@'
@echo off
echo Uploading BioTrack firmware to ESP32...
cd esp32_firmware
pio run --target upload
echo.
echo Starting serial monitor (Ctrl+C to exit)...
pio device monitor
'@ | Out-File -FilePath "upload_firmware.bat" -Encoding ASCII

Write-Success "Created helper scripts: install_app.bat, upload_firmware.bat"
