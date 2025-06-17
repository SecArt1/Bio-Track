# ESP32 IoT Data Flow Test Script
param(
    [int]$NumberOfMessages = 2,
    [string]$DeviceId = "biotrack-device-001"
)

Write-Host "🧪 Starting ESP32 Sensor Data Flow Test" -ForegroundColor Green
Write-Host "Device ID: $DeviceId" -ForegroundColor Yellow
Write-Host "Messages to send: $NumberOfMessages" -ForegroundColor Yellow

# Load inventory
$inventoryPath = "cloud-inventory.json"
if (Test-Path $inventoryPath) {
    $inventory = Get-Content $inventoryPath | ConvertFrom-Json
} else {
    Write-Host "❌ cloud-inventory.json not found" -ForegroundColor Red
    exit 1
}

$testStartTime = Get-Date
$successCount = 0

# Function to generate sensor data
function New-SensorData {
    param([string]$deviceId, [int]$index)
    
    return @{
        deviceId = $deviceId
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
        messageId = "test_msg_$((Get-Date).Ticks)_$index"
        topic = "biotrack/device/$deviceId/telemetry"
        vitals = @{
            heartRate = (Get-Random -Minimum 65 -Maximum 95)
            temperature = [math]::Round((Get-Random -Minimum 36.2 -Maximum 37.8), 1)
            spo2 = (Get-Random -Minimum 95 -Maximum 100)
            bloodPressure = @{
                systolic = (Get-Random -Minimum 110 -Maximum 140)
                diastolic = (Get-Random -Minimum 70 -Maximum 90)
            }
        }
        weight = [math]::Round((Get-Random -Minimum 65.0 -Maximum 85.0), 1)
        bioimpedance = @{
            resistance = (Get-Random -Minimum 400 -Maximum 600)
            reactance = (Get-Random -Minimum 50 -Maximum 100)
            frequency = 50000
        }
        bodyComposition = @{
            bodyFat = [math]::Round((Get-Random -Minimum 12.0 -Maximum 25.0), 1)
            muscleMass = [math]::Round((Get-Random -Minimum 35.0 -Maximum 45.0), 1)
            bodyWater = [math]::Round((Get-Random -Minimum 55.0 -Maximum 65.0), 1)
        }
        location = @{
            latitude = [math]::Round((Get-Random -Minimum 30.0 -Maximum 31.0), 6)
            longitude = [math]::Round((Get-Random -Minimum 31.0 -Maximum 32.0), 6)
        }
        batteryLevel = (Get-Random -Minimum 75 -Maximum 100)
        signalStrength = (Get-Random -Minimum -70 -Maximum -30)
        firmwareVersion = "1.0.2"
        userId = "user_placeholder"
    }
}

# Send messages
for ($i = 1; $i -le $NumberOfMessages; $i++) {
    Write-Host "`n🔄 Sending message $i/$NumberOfMessages" -ForegroundColor Blue
    
    # Generate sensor data
    $sensorData = New-SensorData -deviceId $DeviceId -index $i
    
    Write-Host "Generated data:" -ForegroundColor Gray
    Write-Host "- Heart Rate: $($sensorData.vitals.heartRate) BPM" -ForegroundColor Gray
    Write-Host "- Temperature: $($sensorData.vitals.temperature)°C" -ForegroundColor Gray
    Write-Host "- Weight: $($sensorData.weight) kg" -ForegroundColor Gray
    Write-Host "- Battery: $($sensorData.batteryLevel)%" -ForegroundColor Gray
    
    # Convert to JSON and save to temp file
    $jsonPayload = $sensorData | ConvertTo-Json -Depth 10
    $tempFile = [System.IO.Path]::GetTempFileName()
    $jsonPayload | Out-File -FilePath $tempFile -Encoding UTF8
    
    # Send to AWS IoT
    $topic = "biotrack/device/$DeviceId/telemetry"
    Write-Host "📡 Publishing to AWS IoT topic: $topic" -ForegroundColor Cyan
    
    $result = aws iot-data publish --topic $topic --payload "file://$tempFile" --region $($inventory.awsRegion) 2>&1
    Remove-Item $tempFile -ErrorAction SilentlyContinue
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully published to AWS IoT" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "❌ Failed to publish: $result" -ForegroundColor Red
    }
    
    if ($i -lt $NumberOfMessages) {
        Write-Host "⏳ Waiting 3 seconds..." -ForegroundColor Gray
        Start-Sleep -Seconds 3
    }
}

# Wait for processing
Write-Host "`n⏳ Waiting 10 seconds for Lambda processing..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Check Lambda logs
Write-Host "`n📋 Checking Lambda function logs..." -ForegroundColor Cyan
$logGroup = "/aws/lambda/$($inventory.resources.lambdaFunction)"
$startTimeUnix = [DateTimeOffset]::new($testStartTime).ToUnixTimeMilliseconds()

try {
    $logStreams = aws logs describe-log-streams --log-group-name $logGroup --order-by LastEventTime --descending --max-items 2 2>&1
    
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

# Results
Write-Host "`n📊 Test Results" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green
Write-Host "Messages sent: $successCount/$NumberOfMessages" -ForegroundColor Green
Write-Host "Success rate: $([math]::Round(($successCount / $NumberOfMessages) * 100, 1))%" -ForegroundColor Yellow
Write-Host "Duration: $((Get-Date) - $testStartTime)" -ForegroundColor Gray

Write-Host "`n✅ Test completed! Check the logs above for Firestore confirmations." -ForegroundColor Green
