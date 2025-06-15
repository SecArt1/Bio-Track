# ESP32 Traffic Simulation Script
# Simulates realistic ESP32 sensor data and network traffic

param(
    [switch]$Single,
    [switch]$Status,
    [switch]$Continuous,
    [switch]$Help
)

# Configuration from ESP32 config.h
$CONFIG = @{
    DEVICE_ID = "biotrack-device-001"
    USER_ID = "FUbmmZXxY0OdJolvrQXP0JxMjmW2"
    API_GATEWAY_URL = "https://vn5ycnp8nh.execute-api.eu-central-1.amazonaws.com/prod"
    FIREBASE_HOST = "bio-track-de846-default-rtdb.firebaseio.com"
    AWS_IOT_ENDPOINT = "azvqnnby4qrmz-ats.iot.eu-central-1.amazonaws.com"
}

function Show-Help {
    Write-Host "ESP32 Traffic Simulator" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\simulate-esp32.ps1 -Single      # Run single sensor cycle"
    Write-Host "  .\simulate-esp32.ps1 -Status      # Send device status only"
    Write-Host "  .\simulate-esp32.ps1 -Continuous  # Run continuous simulation"
    Write-Host "  .\simulate-esp32.ps1 -Help        # Show this help"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "  node esp32-simulator.js --single"
    Write-Host "  node esp32-simulator.js --status"
    Write-Host "  node esp32-simulator.js"
    Write-Host ""
}

function Test-NodeJS {
    try {
        $nodeVersion = node --version 2>$null
        if ($nodeVersion) {
            Write-Host "✅ Node.js detected: $nodeVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "❌ Node.js not found. Please install Node.js first." -ForegroundColor Red
        return $false
    }
    return $false
}

function Generate-SensorData {
    param([string]$SensorType)
    
    $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    
    switch ($SensorType) {
        "heart_rate" {
            $value = Get-Random -Minimum 65 -Maximum 85
            return @{
                sensor_type = "heart_rate"
                value = $value
                unit = "bpm"
                device_id = $CONFIG.DEVICE_ID
                user_id = $CONFIG.USER_ID
                timestamp = $timestamp
                raw_data = @{
                    ir_value = Get-Random -Minimum 50000 -Maximum 150000
                    red_value = Get-Random -Minimum 40000 -Maximum 120000
                    signal_quality = [math]::Round((Get-Random -Minimum 70 -Maximum 100) / 100, 2)
                }
            }
        }
        "temperature" {
            $value = [math]::Round((Get-Random -Minimum 360 -Maximum 375) / 10, 1)
            return @{
                sensor_type = "temperature"
                value = $value
                unit = "°C"
                device_id = $CONFIG.DEVICE_ID
                user_id = $CONFIG.USER_ID
                timestamp = $timestamp
                raw_data = @{
                    sensor_resolution = 12
                    conversion_time = 750
                }
            }
        }
        "weight" {
            $value = [math]::Round((Get-Random -Minimum 680 -Maximum 720) / 10, 1)
            return @{
                sensor_type = "weight"
                value = $value
                unit = "kg"
                device_id = $CONFIG.DEVICE_ID
                user_id = $CONFIG.USER_ID
                timestamp = $timestamp
                raw_data = @{
                    raw_adc = Get-Random -Minimum 1000000 -Maximum 16777215
                    calibration_factor = 2280.0
                    tare_offset = 0
                }
            }
        }
        "bioimpedance" {
            $value = [math]::Round((Get-Random -Minimum 170 -Maximum 200) / 10, 1)
            return @{
                sensor_type = "bioimpedance"
                value = $value
                unit = "%"
                device_id = $CONFIG.DEVICE_ID
                user_id = $CONFIG.USER_ID
                timestamp = $timestamp
                raw_data = @{
                    impedance_50khz = Get-Random -Minimum 400 -Maximum 500
                    impedance_100khz = Get-Random -Minimum 380 -Maximum 460
                    phase_angle = [math]::Round((Get-Random -Minimum 50 -Maximum 150) / 10, 1)
                    reactance = Get-Random -Minimum 20 -Maximum 70
                }
            }
        }
        "spo2" {
            $value = [math]::Round((Get-Random -Minimum 960 -Maximum 1000) / 10, 1)
            return @{
                sensor_type = "spo2"
                value = $value
                unit = "%"
                device_id = $CONFIG.DEVICE_ID
                user_id = $CONFIG.USER_ID
                timestamp = $timestamp
                raw_data = @{
                    ratio_of_ratios = [math]::Round((Get-Random -Minimum 150 -Maximum 200) / 100, 2)
                    signal_strength = [math]::Round((Get-Random -Minimum 80 -Maximum 100) / 100, 2)
                }
            }
        }
        "device_status" {
            return @{
                device_id = $CONFIG.DEVICE_ID
                user_id = $CONFIG.USER_ID
                status = "online"
                firmware_version = "1.0.2"
                battery_level = Get-Random -Minimum 70 -Maximum 100
                wifi_rssi = -(Get-Random -Minimum 30 -Maximum 60)
                free_heap = Get-Random -Minimum 200000 -Maximum 250000
                uptime = Get-Random -Minimum 3600000 -Maximum 86400000
                timestamp = $timestamp
            }
        }
    }
}

function Send-HttpRequest {
    param(
        [string]$Url,
        [hashtable]$Data,
        [string]$Method = "POST"
    )
    
    try {
        $headers = @{
            "Content-Type" = "application/json"
            "User-Agent" = "ESP32-BioTrack/1.0.2"
            "X-Device-ID" = $CONFIG.DEVICE_ID
            "X-User-ID" = $CONFIG.USER_ID
        }
        
        $jsonData = $Data | ConvertTo-Json -Depth 10
        
        Write-Host "📤 Sending to: $Url" -ForegroundColor Cyan
        Write-Host "📊 Data: $($jsonData.Substring(0, [Math]::Min(150, $jsonData.Length)))..." -ForegroundColor Gray
        
        if ($Method -eq "GET") {
            $response = Invoke-RestMethod -Uri $Url -Method $Method -Headers $headers -TimeoutSec 10
        } else {
            $response = Invoke-RestMethod -Uri $Url -Method $Method -Headers $headers -Body $jsonData -TimeoutSec 10
        }
        
        Write-Host "✅ Success: $Url" -ForegroundColor Green
        return $response
        
    } catch {
        Write-Host "❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Send-ToAWSIoT {
    param([hashtable]$SensorData)
    
    $payload = @{
        topic = "biotrack/device/$($CONFIG.DEVICE_ID)/telemetry"
        payload = $SensorData
        timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        clientId = $CONFIG.DEVICE_ID
    }
    
    $response = Send-HttpRequest -Url "$($CONFIG.API_GATEWAY_URL)/iot/publish" -Data $payload
    return $response
}

function Send-ToFirebase {
    param([hashtable]$SensorData)
    
    $url = "https://$($CONFIG.FIREBASE_HOST)/devices/$($CONFIG.DEVICE_ID)/sensor_data.json"
    $response = Send-HttpRequest -Url $url -Data $SensorData -Method "PUT"
    return $response
}

function Test-Endpoints {
    Write-Host "🔍 Testing endpoints..." -ForegroundColor Yellow
    
    # Test API Gateway health
    try {
        $healthResponse = Send-HttpRequest -Url "$($CONFIG.API_GATEWAY_URL)/health" -Data @{} -Method "GET"
        Write-Host "✅ API Gateway health check passed" -ForegroundColor Green
    } catch {
        Write-Host "❌ API Gateway health check failed" -ForegroundColor Red
    }
    
    # Test Firebase
    try {
        $firebaseTest = @{ test = "connection"; timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
        $firebaseResponse = Send-ToFirebase -SensorData $firebaseTest
        Write-Host "✅ Firebase connection test passed" -ForegroundColor Green
    } catch {
        Write-Host "❌ Firebase connection test failed" -ForegroundColor Red
    }
}

function Start-SingleCycle {
    Write-Host "🔄 Running single sensor cycle..." -ForegroundColor Cyan
    
    $sensors = @("heart_rate", "spo2", "temperature", "weight", "bioimpedance")
    
    foreach ($sensor in $sensors) {
        $sensorData = Generate-SensorData -SensorType $sensor
        
        # Try AWS IoT first
        $awsResponse = Send-ToAWSIoT -SensorData $sensorData
        
        if (-not $awsResponse) {
            Write-Host "🔄 Falling back to Firebase..." -ForegroundColor Yellow
            $firebaseResponse = Send-ToFirebase -SensorData $sensorData
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "✅ Single cycle complete" -ForegroundColor Green
}

function Start-StatusUpdate {
    Write-Host "📊 Sending device status..." -ForegroundColor Cyan
    
    $statusData = Generate-SensorData -SensorType "device_status"
    
    $payload = @{
        topic = "biotrack/device/$($CONFIG.DEVICE_ID)/status"
        payload = $statusData
        timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        clientId = $CONFIG.DEVICE_ID
    }
    
    $response = Send-HttpRequest -Url "$($CONFIG.API_GATEWAY_URL)/iot/publish" -Data $payload
    
    if ($response) {
        Write-Host "✅ Status sent successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to send status" -ForegroundColor Red
    }
}

# Main execution logic
Write-Host "ESP32 Traffic Simulator" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host "Device ID: $($CONFIG.DEVICE_ID)" -ForegroundColor Gray
Write-Host "User ID: $($CONFIG.USER_ID)" -ForegroundColor Gray
Write-Host ""

if ($Help) {
    Show-Help
    exit 0
}

if (-not (Test-NodeJS)) {
    Write-Host ""
    Write-Host "💡 Alternative: Use PowerShell simulation (current mode)" -ForegroundColor Yellow
    Write-Host ""
}

# Test endpoints first
Test-Endpoints
Write-Host ""

if ($Single) {
    Start-SingleCycle
} elseif ($Status) {
    Start-StatusUpdate
} elseif ($Continuous) {
    Write-Host "🚀 Starting continuous simulation..." -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
    Write-Host ""
    
    try {
        while ($true) {
            Start-SingleCycle
            Write-Host "⏱️ Waiting 10 seconds..." -ForegroundColor Gray
            Start-Sleep -Seconds 10
        }
    } catch {
        Write-Host "🛑 Simulation stopped" -ForegroundColor Yellow
    }
} else {
    Show-Help
    Write-Host ""
    Write-Host "💡 For Node.js simulation, run:" -ForegroundColor Yellow
    Write-Host "   node esp32-simulator.js --single" -ForegroundColor White
    Write-Host "   node esp32-simulator.js" -ForegroundColor White
}
