# ESP32 Sensor Data Simulation and IoT Testing Script
# This script emulates ESP32 sensor data and tests the complete data flow to Firestore

param(
    [string]$TestType = "full-simulation",
    [string]$DeviceId = "biotrack-device-001",
    [int]$NumberOfMessages = 3
)

# Import required modules
Import-Module AWS.Tools.IoTCore -ErrorAction SilentlyContinue
Import-Module AWS.Tools.Lambda -ErrorAction SilentlyContinue

# Load inventory file
$inventoryPath = "cloud-inventory.json"
$inventory = Get-Content $inventoryPath | ConvertFrom-Json

# Update inventory with current test
$inventory.testingProgress.currentStep = "generating-sensor-data"
$inventory.testingProgress.testType = $TestType
$inventory.testingProgress.messagesPlanned = $NumberOfMessages
$inventory | ConvertTo-Json -Depth 10 | Set-Content $inventoryPath

Write-Host "🧪 Starting ESP32 Sensor Data Flow Test" -ForegroundColor Green
Write-Host "Device ID: $DeviceId" -ForegroundColor Yellow
Write-Host "Messages to send: $NumberOfMessages" -ForegroundColor Yellow

# Function to generate realistic ESP32 sensor data
function New-ESP32SensorData {
    param([string]$deviceId, [int]$messageIndex)
    
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    
    # Simulate realistic sensor readings with some variation
    $heartRate = Get-Random -Minimum 65 -Maximum 95
    $temperature = [math]::Round((Get-Random -Minimum 36.2 -Maximum 37.8), 1)
    $spo2 = Get-Random -Minimum 95 -Maximum 100
    $weight = [math]::Round((Get-Random -Minimum 65.0 -Maximum 85.0), 1)
    $batteryLevel = Get-Random -Minimum 75 -Maximum 100
    
    # Generate bioimpedance data
    $resistance = Get-Random -Minimum 400 -Maximum 600
    $reactance = Get-Random -Minimum 50 -Maximum 100
    $impedance = [math]::Sqrt($resistance * $resistance + $reactance * $reactance)
    
    # Calculate body composition estimates
    $bodyFat = [math]::Round((Get-Random -Minimum 12.0 -Maximum 25.0), 1)
    $muscleMass = [math]::Round((Get-Random -Minimum 35.0 -Maximum 45.0), 1)
    $bodyWater = [math]::Round((Get-Random -Minimum 55.0 -Maximum 65.0), 1)
    
    $sensorData = @{
        deviceId = $deviceId
        timestamp = $timestamp
        messageId = "msg_$((Get-Date).Ticks)_$messageIndex"
        vitals = @{
            heartRate = $heartRate
            temperature = $temperature
            spo2 = $spo2
            bloodPressure = @{
                systolic = (Get-Random -Minimum 110 -Maximum 140)
                diastolic = (Get-Random -Minimum 70 -Maximum 90)
            }
        }
        weight = $weight
        bioimpedance = @{
            resistance = $resistance
            reactance = $reactance
            impedance = [math]::Round($impedance, 1)
            frequency = 50000
        }
        bodyComposition = @{
            bodyFat = $bodyFat
            muscleMass = $muscleMass
            bodyWater = $bodyWater
            boneMass = [math]::Round((Get-Random -Minimum 2.5 -Maximum 4.0), 1)
            bmr = (Get-Random -Minimum 1400 -Maximum 1800)
        }
        location = @{
            latitude = [math]::Round((Get-Random -Minimum 30.0 -Maximum 31.0), 6)
            longitude = [math]::Round((Get-Random -Minimum 31.0 -Maximum 32.0), 6)
        }
        batteryLevel = $batteryLevel
        signalStrength = (Get-Random -Minimum -70 -Maximum -30)
        firmwareVersion = "1.0.2"
        userId = "user_placeholder"
    }
    
    return $sensorData
}

# Function to send data to AWS IoT Core
function Send-ToAWSIoT {
    param([hashtable]$data, [string]$topic)
    
    try {
        $jsonPayload = $data | ConvertTo-Json -Depth 10
        Write-Host "📡 Sending to AWS IoT Topic: $topic" -ForegroundColor Cyan
        Write-Host "Payload size: $($jsonPayload.Length) bytes" -ForegroundColor Gray
        
        # Use AWS CLI to publish to IoT Core (since PowerShell IoT cmdlets are limited)
        $tempFile = [System.IO.Path]::GetTempFileName()
        $jsonPayload | Out-File -FilePath $tempFile -Encoding UTF8
        
        $result = aws iot-data publish --topic $topic --payload "file://$tempFile" --region $inventory.awsRegion 2>&1
        Remove-Item $tempFile -ErrorAction SilentlyContinue
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Successfully published to AWS IoT" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Failed to publish to AWS IoT: $result" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Error sending to AWS IoT: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}
}

# Function to check Lambda function logs
function Get-LambdaLogs {
    param([string]$functionName, [datetime]$startTime)
    
    try {
        Write-Host "📋 Checking Lambda function logs..." -ForegroundColor Cyan
        
        # Get log streams for the function
        $logGroup = "/aws/lambda/$functionName"
        $startTimeUnix = [DateTimeOffset]::new($startTime).ToUnixTimeMilliseconds()
        
        $logStreams = aws logs describe-log-streams --log-group-name $logGroup --order-by LastEventTime --descending --max-items 3 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $streams = $logStreams | ConvertFrom-Json
            
            foreach ($stream in $streams.logStreams) {
                $streamName = $stream.logStreamName
                Write-Host "Checking log stream: $streamName" -ForegroundColor Gray
                
                $events = aws logs get-log-events --log-group-name $logGroup --log-stream-name $streamName --start-time $startTimeUnix 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $logEvents = $events | ConvertFrom-Json
                    
                    foreach ($event in $logEvents.events) {
                        $timestamp = [DateTimeOffset]::FromUnixTimeMilliseconds($event.timestamp).ToString("yyyy-MM-dd HH:mm:ss")
                        Write-Host "[$timestamp] $($event.message)" -ForegroundColor White
                    }
                }
            }
        } else {
            Write-Host "⚠️ Could not retrieve logs: $logStreams" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "⚠️ Error checking logs: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Function to verify data in Firestore
function Test-FirestoreData {
    param([string]$deviceId, [string]$messageId)
    
    Write-Host "🔍 Checking if data was stored in Firestore..." -ForegroundColor Cyan
    
    # For now, we'll check through Firebase CLI or logs
    # In a real scenario, you might use Firebase Admin SDK or REST API
    Write-Host "Note: Direct Firestore verification requires Firebase CLI setup" -ForegroundColor Yellow
    Write-Host "Check the Lambda logs above for Firestore write confirmations" -ForegroundColor Yellow
}

# Main execution
Write-Progress -Activity "IoT Data Flow Testing" -Status "Step 2: Generating sensor data" -PercentComplete 20

$testStartTime = Get-Date
$successCount = 0
$failureCount = 0

# Update inventory
$inventory.testingProgress.currentStep = "sending-messages"
$inventory.testingProgress.startTime = $testStartTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$inventory | ConvertTo-Json -Depth 10 | Set-Content $inventoryPath

for ($i = 1; $i -le $NumberOfMessages; $i++) {
    Write-Progress -Activity "IoT Data Flow Testing" -Status "Step 3: Sending message $i of $NumberOfMessages" -PercentComplete (20 + ($i * 40 / $NumberOfMessages))
    
    Write-Host "`n🔄 Generating and sending message $i/$NumberOfMessages" -ForegroundColor Blue
    
    # Generate sensor data
    $sensorData = New-ESP32SensorData -deviceId $DeviceId -messageIndex $i
    
    Write-Host "Generated sensor data:" -ForegroundColor Gray
    Write-Host "- Heart Rate: $($sensorData.vitals.heartRate) BPM" -ForegroundColor Gray
    Write-Host "- Temperature: $($sensorData.vitals.temperature)°C" -ForegroundColor Gray
    Write-Host "- SpO2: $($sensorData.vitals.spo2)%" -ForegroundColor Gray
    Write-Host "- Weight: $($sensorData.weight) kg" -ForegroundColor Gray
    Write-Host "- Battery: $($sensorData.batteryLevel)%" -ForegroundColor Gray
    
    # Send to AWS IoT
    $topic = "biotrack/device/$DeviceId/telemetry"
    $success = Send-ToAWSIoT -data $sensorData -topic $topic
    
    if ($success) {
        $successCount++
        
        # Update inventory with successful message
        $inventory.testingProgress.messagesSent = $successCount
        $inventory.testingProgress.lastSuccessfulMessage = $sensorData.messageId
        $inventory | ConvertTo-Json -Depth 10 | Set-Content $inventoryPath
    } else {
        $failureCount++
    }
    
    # Wait between messages
    if ($i -lt $NumberOfMessages) {
        Write-Host "⏳ Waiting 3 seconds before next message..." -ForegroundColor Gray
        Start-Sleep -Seconds 3
    }
}

Write-Progress -Activity "IoT Data Flow Testing" -Status "Step 4: Checking Lambda logs and Firestore" -PercentComplete 80

# Wait a bit for processing
Write-Host "`n⏳ Waiting 10 seconds for Lambda processing..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Check Lambda logs
Get-LambdaLogs -functionName $inventory.resources.lambdaFunction -startTime $testStartTime

Write-Progress -Activity "IoT Data Flow Testing" -Status "Step 5: Verification complete" -PercentComplete 100

# Final report
Write-Host "`n📊 Test Results Summary" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host "Messages sent successfully: $successCount" -ForegroundColor Green
Write-Host "Messages failed: $failureCount" -ForegroundColor Red
Write-Host "Success rate: $([math]::Round(($successCount / $NumberOfMessages) * 100, 1))%" -ForegroundColor Yellow
Write-Host "Test duration: $((Get-Date) - $testStartTime)" -ForegroundColor Gray

# Update final inventory
$inventory.testingProgress.currentStep = "completed"
$inventory.testingProgress.endTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$inventory.testingProgress.successCount = $successCount
$inventory.testingProgress.failureCount = $failureCount
$inventory.testingProgress.duration = ((Get-Date) - $testStartTime).ToString()
$inventory.lastCompletedStep = "iot-data-flow-test-complete"
$inventory | ConvertTo-Json -Depth 10 | Set-Content $inventoryPath

Write-Host "`n✅ Test completed! Check the Lambda logs above for Firestore storage confirmations." -ForegroundColor Green
Write-Host "📝 Test results saved to cloud-inventory.json" -ForegroundColor Cyan
