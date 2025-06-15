# ESP32 BioTrack Clean Simulation - PowerShell Wrapper
# This script provides a clean AWS IoT Core simulation without Firebase dependencies

param(
    [string]$Command = "help",
    [int]$Count = 1,
    [int]$Interval = 5
)

# AWS Configuration from config.h
$AWS_CONFIG = @{
    IoTEndpoint = "azvqnnby4qrmz-ats.iot.eu-central-1.amazonaws.com"
    ApiGatewayUrl = "https://azvqnnby4qrmz.execute-api.eu-central-1.amazonaws.com/prod"
    Region = "eu-central-1" 
    DeviceId = "biotrack-device-001"
    ThingName = "biotrack-device-001"
}

function Show-Help {
    Write-Host "ESP32 BioTrack Clean Simulation" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage: .\esp32-simulation-clean.ps1 -Command <command> [-Count <n>] [-Interval <seconds>]"
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  full-screening    - Simulate complete health screening"
    Write-Host "  heart_rate        - Test heart rate sensor"
    Write-Host "  temperature       - Test temperature sensor"
    Write-Host "  weight            - Test weight sensor"
    Write-Host "  blood_oxygen      - Test SpO2 sensor"
    Write-Host "  bioimpedance      - Test bioimpedance sensor"
    Write-Host "  blood_pressure    - Test blood pressure"
    Write-Host "  heartbeat         - Send device status heartbeat"
    Write-Host "  test-api          - Test API Gateway connectivity"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\esp32-simulation-clean.ps1 -Command full-screening"
    Write-Host "  .\esp32-simulation-clean.ps1 -Command heart_rate -Count 5 -Interval 3"
    Write-Host "  .\esp32-simulation-clean.ps1 -Command test-api"
}

function Test-APIConnectivity {
    Write-Host "Testing AWS API Gateway connectivity..." -ForegroundColor Yellow
    
    try {
        $response = Invoke-WebRequest -Uri "$($AWS_CONFIG.ApiGatewayUrl)/health" -Method GET -UseBasicParsing
        Write-Host "API Gateway is reachable - Status: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "Response: $($response.Content)" -ForegroundColor Gray
        return $true
    }
    catch {
        Write-Host "API Gateway unreachable: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Send-SensorData {
    param(
        [string]$SensorType,
        [hashtable]$SensorData
    )
    
    $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    
    $payload = @{
        deviceId = $AWS_CONFIG.DeviceId
        timestamp = $timestamp
        sensor_type = $SensorType
        firmware_version = "1.0.2"
        battery_level = Get-Random -Minimum 20 -Maximum 100
        signal_strength = Get-Random -Minimum -80 -Maximum -40
    }
    
    # Add sensor-specific data
    foreach ($key in $SensorData.Keys) {
        $payload[$key] = $SensorData[$key]
    }
    
    $jsonPayload = $payload | ConvertTo-Json -Depth 5
    
    Write-Host "Sending $SensorType data..." -ForegroundColor Cyan
    Write-Host $jsonPayload -ForegroundColor Gray
    
    try {
        $body = @{
            topic = "biotrack/device/$($AWS_CONFIG.DeviceId)/telemetry"
            payload = $payload
            deviceId = $AWS_CONFIG.DeviceId
            timestamp = $timestamp
        } | ConvertTo-Json -Depth 5
        
        $response = Invoke-WebRequest -Uri "$($AWS_CONFIG.ApiGatewayUrl)/iot/publish" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing
        Write-Host "Data sent successfully - Status: $($response.StatusCode)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to send data: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-SensorReading {
    param([string]$SensorType)
    
    switch ($SensorType) {
        "heart_rate" {
            return @{
                value = Get-Random -Minimum 60 -Maximum 100
                unit = "bpm"
                confidence = 0.95
                sensor_id = "MAX30102"
            }
        }
        "temperature" {
            return @{
                value = [math]::Round((36.1 + (Get-Random) * 1.4), 1)
                unit = "°C"
                sensor_id = "DS18B20"
            }
        }
        "weight" {
            return @{
                value = [math]::Round((65 + (Get-Random) * 20), 1)
                unit = "kg"
                sensor_id = "HX711"
                calibration_factor = 2280.0
            }
        }
        "blood_oxygen" {
            return @{
                value = Get-Random -Minimum 95 -Maximum 100
                unit = "%"
                sensor_id = "MAX30102"
            }
        }
        "bioimpedance" {
            return @{
                value = [math]::Round((400 + (Get-Random) * 200), 1)
                unit = "Ω"
                sensor_id = "AD5941"
                frequency = "50kHz"
            }
        }
        "blood_pressure" {
            return @{
                systolic = Get-Random -Minimum 110 -Maximum 140
                diastolic = Get-Random -Minimum 70 -Maximum 90
                unit = "mmHg"
                method = "oscillometric"
            }
        }
    }
}

function Send-Heartbeat {
    Write-Host "Sending device heartbeat..." -ForegroundColor Magenta
    
    $heartbeatData = @{
        status = "online"
        uptime = Get-Random -Minimum 0 -Maximum 86400
        free_heap = Get-Random -Minimum 200000 -Maximum 300000
        wifi_rssi = Get-Random -Minimum -80 -Maximum -40
        firmware_version = "1.0.2"
        last_sensor_reading = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - (Get-Random -Minimum 0 -Maximum 30000)
    }
    
    return Send-SensorData -SensorType "heartbeat" -SensorData $heartbeatData
}

function Start-FullScreening {
    Write-Host "Starting Full Health Screening Simulation..." -ForegroundColor Green
    Write-Host ""
    
    # Send heartbeat first
    Send-Heartbeat
    Start-Sleep -Seconds 2
    
    # Sensor sequence
    $sensors = @("heart_rate", "temperature", "weight", "blood_oxygen", "bioimpedance", "blood_pressure")
    
    foreach ($sensor in $sensors) {
        $sensorData = Get-SensorReading -SensorType $sensor
        Send-SensorData -SensorType $sensor -SensorData $sensorData
        Start-Sleep -Seconds 2
    }
    
    Write-Host ""
    Write-Host "Full health screening simulation completed!" -ForegroundColor Green
}

# Main execution logic
switch ($Command.ToLower()) {
    "help" { Show-Help }
    "test-api" { Test-APIConnectivity }
    "heartbeat" { 
        for ($i = 1; $i -le $Count; $i++) {
            Send-Heartbeat
            if ($i -lt $Count) { Start-Sleep -Seconds $Interval }
        }
    }
    "full-screening" { 
        for ($i = 1; $i -le $Count; $i++) {
            Start-FullScreening
            if ($i -lt $Count) { Start-Sleep -Seconds $Interval }
        }
    }
    { $_ -in @("heart_rate", "temperature", "weight", "blood_oxygen", "bioimpedance", "blood_pressure") } {
        for ($i = 1; $i -le $Count; $i++) {
            $sensorData = Get-SensorReading -SensorType $Command
            Send-SensorData -SensorType $Command -SensorData $sensorData
            if ($i -lt $Count) { Start-Sleep -Seconds $Interval }
        }
    }    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Write-Host "Use -Command help for usage information" -ForegroundColor Yellow
    }
}
