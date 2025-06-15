# ESP32 BioTrack Data Flow Demonstration
# Shows the clean AWS IoT Core data structure without Firebase dependencies

Write-Host "ESP32 BioTrack - Clean AWS IoT Core Data Flow Demo" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""

# Device Configuration from config.h
$deviceConfig = @{
    DeviceId = "biotrack-device-001"
    ThingName = "biotrack-device-001"
    IoTEndpoint = "azvqnnby4qrmz-ats.iot.eu-central-1.amazonaws.com"
    FirmwareVersion = "1.0.2"
}

Write-Host "Device Configuration:" -ForegroundColor Yellow
$deviceConfig | Format-Table -AutoSize

# MQTT Topics
$topics = @{
    Telemetry = "biotrack/device/$($deviceConfig.DeviceId)/telemetry"
    Commands = "biotrack/device/$($deviceConfig.DeviceId)/commands"
    Status = "biotrack/device/$($deviceConfig.DeviceId)/status"
    Responses = "biotrack/device/$($deviceConfig.DeviceId)/responses"
}

Write-Host "MQTT Topics:" -ForegroundColor Yellow
$topics | Format-Table -AutoSize

# Generate sample sensor data
function Get-SampleSensorData {
    param([string]$SensorType)
    
    $baseData = @{
        deviceId = $deviceConfig.DeviceId
        timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        sensor_type = $SensorType
        firmware_version = $deviceConfig.FirmwareVersion
        battery_level = Get-Random -Minimum 75 -Maximum 95
        signal_strength = Get-Random -Minimum -45 -Maximum -35
    }
    
    switch ($SensorType) {
        "heart_rate" {
            $baseData.value = Get-Random -Minimum 65 -Maximum 85
            $baseData.unit = "bpm"
            $baseData.sensor_id = "MAX30102"
            $baseData.confidence = 0.95
        }
        "temperature" {
            $baseData.value = [math]::Round((36.5 + (Get-Random) * 0.8), 1)
            $baseData.unit = "°C"
            $baseData.sensor_id = "DS18B20"
        }
        "weight" {
            $baseData.value = [math]::Round((70 + (Get-Random) * 10), 1)
            $baseData.unit = "kg"
            $baseData.sensor_id = "HX711"
            $baseData.calibration_factor = 2280.0
        }
        "blood_oxygen" {
            $baseData.value = Get-Random -Minimum 96 -Maximum 99
            $baseData.unit = "%"
            $baseData.sensor_id = "MAX30102"
        }
        "bioimpedance" {
            $baseData.value = [math]::Round((450 + (Get-Random) * 100), 1)
            $baseData.unit = "Ω"
            $baseData.sensor_id = "AD5941"
            $baseData.frequency = "50kHz"
        }
    }
    
    return $baseData
}

Write-Host ""
Write-Host "Sample ESP32 Sensor Data Payloads:" -ForegroundColor Yellow
Write-Host "===================================" -ForegroundColor Yellow

$sensors = @("heart_rate", "temperature", "weight", "blood_oxygen", "bioimpedance")

foreach ($sensor in $sensors) {
    Write-Host ""
    Write-Host "[$sensor] Topic: $($topics.Telemetry)" -ForegroundColor Cyan
    $sensorData = Get-SampleSensorData -SensorType $sensor
    $sensorData | ConvertTo-Json -Depth 3 | Write-Host -ForegroundColor Gray
}

Write-Host ""
Write-Host "Expected Data Flow:" -ForegroundColor Yellow
Write-Host "==================" -ForegroundColor Yellow
Write-Host "1. ESP32 sends sensor data to AWS IoT Core MQTT topic" -ForegroundColor White
Write-Host "2. AWS IoT Core triggers Lambda function via IoT Rules" -ForegroundColor White
Write-Host "3. Lambda function processes data and stores in Firebase Realtime Database" -ForegroundColor White
Write-Host "4. Flutter app listens to Firebase real-time updates" -ForegroundColor White
Write-Host "5. Mobile app displays updated sensor readings" -ForegroundColor White

Write-Host ""
Write-Host "Note: This demonstrates the clean AWS IoT Core architecture" -ForegroundColor Green
Write-Host "without the mixed Firebase/MQTT configuration from the old config.h" -ForegroundColor Green
