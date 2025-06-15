# ESP32 to Mobile App Simulation Script
# This PowerShell script simulates the complete data flow from ESP32 device to mobile app

Write-Host "🧪 ESP32 to Mobile App Data Flow Simulation" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# Configuration
$config = @{
    ApiUrl = "https://5yg8qfthgb.execute-api.us-east-1.amazonaws.com/prod"
    DeviceId = "biotrack_device_001"
    UserId = "FUbmmZXxY0OdJolvrQXP0JxMjmW2"
    Headers = @{
        "Content-Type" = "application/json"
        "User-Agent" = "ESP32-BioTrack-PowerShell/1.0"
    }
}

# Function to send HTTP request
function Send-SensorData {
    param(
        [string]$Endpoint,
        [hashtable]$Data
    )
    
    $url = "$($config.ApiUrl)$Endpoint"
    $json = $Data | ConvertTo-Json -Depth 10
    
    Write-Host "🌐 Sending to: $url" -ForegroundColor Yellow
    Write-Host "📤 Data: $json" -ForegroundColor Gray
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method POST -Body $json -Headers $config.Headers
        Write-Host "✅ Success: $($response | ConvertTo-Json)" -ForegroundColor Green
        return $response
    }
    catch {
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            $errorBody = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorBody)
            $errorText = $reader.ReadToEnd()
            Write-Host "📋 Error Response: $errorText" -ForegroundColor Red
        }
    }
}

# Test 1: Device Registration/Status
Write-Host "`n🔧 Step 1: Sending Device Status" -ForegroundColor Magenta
$deviceStatus = @{
    deviceId = $config.DeviceId
    userId = $config.UserId
    status = "online"
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    battery_level = 87
    signal_strength = -42
    firmware_version = "1.2.3"
    uptime = 3600000
    free_memory = 245760
}

Send-SensorData -Endpoint "/device/status" -Data $deviceStatus
Start-Sleep -Seconds 2

# Test 2: Temperature Sensor
Write-Host "`n🌡️ Step 2: Sending Temperature Data" -ForegroundColor Magenta
$temperatureData = @{
    deviceId = $config.DeviceId
    userId = $config.UserId
    sensor_type = "temperature"
    value = 36.8
    unit = "°C"
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    quality = "good"
    calibration_status = "calibrated"
}

Send-SensorData -Endpoint "/sensor/data" -Data $temperatureData
Start-Sleep -Seconds 1

# Test 3: Heart Rate Sensor
Write-Host "`n❤️ Step 3: Sending Heart Rate Data" -ForegroundColor Magenta
$heartRateData = @{
    deviceId = $config.DeviceId
    userId = $config.UserId
    sensor_type = "heart_rate"
    value = 72
    unit = "bpm"
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    quality = "excellent"
    rhythm = "regular"
    confidence = 95
}

Send-SensorData -Endpoint "/sensor/data" -Data $heartRateData
Start-Sleep -Seconds 1

# Test 4: Weight Sensor
Write-Host "`n⚖️ Step 4: Sending Weight Data" -ForegroundColor Magenta
$weightData = @{
    deviceId = $config.DeviceId
    userId = $config.UserId
    sensor_type = "weight"
    value = 70.5
    unit = "kg"
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    quality = "stable"
    stability = "locked"
}

Send-SensorData -Endpoint "/sensor/data" -Data $weightData
Start-Sleep -Seconds 1

# Test 5: Bioimpedance (Body Composition)
Write-Host "`n🧬 Step 5: Sending Bioimpedance Data" -ForegroundColor Magenta
$bioimpedanceData = @{
    deviceId = $config.DeviceId
    userId = $config.UserId
    sensor_type = "bioimpedance"
    value = 18.5
    unit = "%"
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    quality = "good"
    body_fat_percentage = 18.5
    muscle_mass = 52.3
    bone_mass = 3.2
    water_percentage = 62.1
    metabolic_age = 25
}

Send-SensorData -Endpoint "/sensor/data" -Data $bioimpedanceData
Start-Sleep -Seconds 1

# Test 6: SpO2 (Blood Oxygen)
Write-Host "`n🫁 Step 6: Sending SpO2 Data" -ForegroundColor Magenta
$spo2Data = @{
    deviceId = $config.DeviceId
    userId = $config.UserId
    sensor_type = "spo2"
    value = 98
    unit = "%"
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    quality = "excellent"
    pulse_strength = "strong"
    perfusion_index = 5.2
}

Send-SensorData -Endpoint "/sensor/data" -Data $spo2Data
Start-Sleep -Seconds 2

# Test 7: Complete Health Screening
Write-Host "`n🏥 Step 7: Sending Complete Health Screening" -ForegroundColor Magenta
$healthScreening = @{
    deviceId = $config.DeviceId
    userId = $config.UserId
    screening_id = [System.Guid]::NewGuid().ToString()
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    screening_type = "full_health_check"
    status = "completed"
    duration = 300
    results = @{
        temperature = @{ value = 36.8; unit = "°C"; status = "normal" }
        heart_rate = @{ value = 72; unit = "bpm"; status = "normal" }
        weight = @{ value = 70.5; unit = "kg"; status = "normal" }
        body_fat = @{ value = 18.5; unit = "%"; status = "good" }
        spo2 = @{ value = 98; unit = "%"; status = "excellent" }
        muscle_mass = @{ value = 52.3; unit = "kg"; status = "good" }
        bone_mass = @{ value = 3.2; unit = "kg"; status = "normal" }
    }
    notes = "Automated health screening simulation"
}

Send-SensorData -Endpoint "/health/screening" -Data $healthScreening

# Summary
Write-Host "`n🎉 Simulation Complete!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host "📱 Check your mobile app for real-time updates" -ForegroundColor Cyan
Write-Host "🔥 Data should appear in Firebase at:" -ForegroundColor Yellow
Write-Host "   • devices/$($config.DeviceId)/sensor_data" -ForegroundColor White
Write-Host "   • devices/$($config.DeviceId)/status" -ForegroundColor White
Write-Host "   • users/$($config.UserId)/health_data" -ForegroundColor White
Write-Host "`n📊 The mobile app should show:" -ForegroundColor Yellow
Write-Host "   • Live log updates in the testing screen" -ForegroundColor White
Write-Host "   • Sensor data in the device testing interface" -ForegroundColor White
Write-Host "   • Results in the health summary screen" -ForegroundColor White
Write-Host "   • Historical data in the previous results screen" -ForegroundColor White

Write-Host "`n🔍 To monitor Firebase updates:" -ForegroundColor Yellow
Write-Host "   1. Open Firebase Console" -ForegroundColor White
Write-Host "   2. Go to Realtime Database" -ForegroundColor White
Write-Host "   3. Watch for real-time updates in the data tree" -ForegroundColor White

Write-Host "`n⚡ To run continuous simulation:" -ForegroundColor Yellow
Write-Host "   node test-esp32-simulation.js --continuous --interval 5000" -ForegroundColor White
