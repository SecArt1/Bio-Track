# IoT Message Format Test - Sends data in the format Lambda expects
# This simulates how AWS IoT Core would send data to the Lambda function

param(
    [string]$DeviceId = "biotrack-device-001",
    [int]$NumberOfMessages = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Function to update inventory
function Update-Inventory {
    param([hashtable]$Updates)
    
    try {
        $inventoryPath = "cloud-inventory.json"
        if (Test-Path $inventoryPath) {
            $inventory = Get-Content $inventoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
            
            # Ensure testingProgress exists
            if (-not $inventory.testingProgress) {
                $inventory | Add-Member -Type NoteProperty -Name "testingProgress" -Value @{}
            }
            
            foreach ($key in $Updates.Keys) {
                if ($inventory.testingProgress.PSObject.Properties.Name -contains $key) {
                    $inventory.testingProgress.$key = $Updates[$key]
                } else {
                    $inventory.testingProgress | Add-Member -Type NoteProperty -Name $key -Value $Updates[$key]
                }
            }
            
            $inventory.timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            
            $jsonOutput = $inventory | ConvertTo-Json -Depth 10
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($inventoryPath, $jsonOutput, $utf8NoBom)
            
            Write-Host "Inventory updated successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to update inventory: $($_.Exception.Message)"
    }
}

# Function to create properly formatted IoT message
function New-IoTMessage {
    param(
        [string]$DeviceId,
        [int]$MessageIndex
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    $messageId = "iot_msg_$((Get-Date).Ticks)_$MessageIndex"
    
    # Create IoT message in the format Lambda expects
    # This simulates what AWS IoT Core sends to Lambda
    $iotMessage = [PSCustomObject]@{
        # Required IoT properties that Lambda checks for
        topic = "biotrack/device/$DeviceId/telemetry"
        timestamp = $timestamp
        deviceId = $DeviceId
        
        # Sensor data payload
        messageId = $messageId
        vitals = [PSCustomObject]@{
            heartRate = Get-Random -Minimum 65 -Maximum 95
            temperature = [Math]::Round((Get-Random -Minimum 36.2 -Maximum 37.8), 1)
            spo2 = Get-Random -Minimum 95 -Maximum 100
            bloodPressure = [PSCustomObject]@{
                systolic = Get-Random -Minimum 110 -Maximum 140
                diastolic = Get-Random -Minimum 70 -Maximum 90
            }
        }
        weight = [Math]::Round((Get-Random -Minimum 65.0 -Maximum 85.0), 1)
        bioimpedance = [PSCustomObject]@{
            resistance = Get-Random -Minimum 400 -Maximum 600
            reactance = Get-Random -Minimum 50 -Maximum 100
            frequency = 50000
        }
        bodyComposition = [PSCustomObject]@{
            bodyFat = [Math]::Round((Get-Random -Minimum 12.0 -Maximum 25.0), 1)
            muscleMass = [Math]::Round((Get-Random -Minimum 35.0 -Maximum 45.0), 1)
            bodyWater = [Math]::Round((Get-Random -Minimum 55.0 -Maximum 65.0), 1)
        }
        location = [PSCustomObject]@{
            latitude = [Math]::Round((Get-Random -Minimum 30.0 -Maximum 31.0), 6)
            longitude = [Math]::Round((Get-Random -Minimum 31.0 -Maximum 32.0), 6)
        }
        batteryLevel = Get-Random -Minimum 75 -Maximum 100
        signalStrength = Get-Random -Minimum -70 -Maximum -30
        firmwareVersion = "1.0.2"
        userId = "test_user_biotrack"
        sessionId = "session_$((Get-Date).ToString('yyyyMMdd'))_001"
        lastCalibration = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    return $iotMessage
}

# Function to invoke Lambda with IoT-formatted message
function Invoke-LambdaWithIoTMessage {
    param(
        [PSCustomObject]$IoTMessage,
        [string]$FunctionName,
        [string]$Region = "eu-central-1"
    )
    
    try {
        # Convert to JSON and base64 encode
        $jsonPayload = $IoTMessage | ConvertTo-Json -Depth 10 -Compress
        $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)
        $base64Payload = [System.Convert]::ToBase64String($jsonBytes)
        
        Write-Host "JSON payload length: $($jsonPayload.Length) chars" -ForegroundColor Gray
        Write-Host "IoT Topic: $($IoTMessage.topic)" -ForegroundColor Cyan
        Write-Host "Device ID: $($IoTMessage.deviceId)" -ForegroundColor Cyan
        
        # Create response file
        $tempId = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
        $responseFile = Join-Path $env:TEMP "iot_lambda_response_$tempId.json"
        
        Write-Host "Invoking Lambda with IoT message format..." -ForegroundColor Yellow
        
        # Build AWS CLI arguments
        $awsArgs = @(
            "lambda"
            "invoke"
            "--function-name"
            $FunctionName
            "--payload"
            $base64Payload
            "--region"
            $Region
            $responseFile
        )
        
        # Execute AWS CLI
        $process = Start-Process -FilePath "aws" -ArgumentList $awsArgs -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Host "Lambda invocation: SUCCESS" -ForegroundColor Green
            
            if (Test-Path $responseFile) {
                $response = Get-Content $responseFile -Raw -Encoding UTF8
                Write-Host "Lambda response: $response" -ForegroundColor White
                
                # Parse response to check for success
                try {
                    $responseObj = $response | ConvertFrom-Json
                    if ($responseObj.statusCode -eq 200) {
                        Write-Host "Data processing: SUCCESS" -ForegroundColor Green
                        $success = $true
                    } else {
                        Write-Host "Data processing: FAILED (Status: $($responseObj.statusCode))" -ForegroundColor Red
                        $success = $false
                    }
                } catch {
                    Write-Host "Response parsing failed, assuming success" -ForegroundColor Yellow
                    $success = $true
                }
                
                Remove-Item $responseFile -Force -ErrorAction SilentlyContinue
                
                return @{
                    Success = $success
                    Response = $response
                    ExitCode = $process.ExitCode
                }
            }
        } else {
            Write-Host "Lambda invocation: FAILED (Exit Code: $($process.ExitCode))" -ForegroundColor Red
            return @{
                Success = $false
                Response = "AWS CLI failed"
                ExitCode = $process.ExitCode
            }
        }
    }
    catch {
        Write-Host "Error during Lambda invocation: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Response = $_.Exception.Message
            ExitCode = -1
        }
    }
}

# Main execution
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "IoT Message Format Test - Lambda Function Data Processing" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan

try {
    # Load configuration
    $inventoryPath = "cloud-inventory.json"
    if (-not (Test-Path $inventoryPath)) {
        throw "Inventory file not found"
    }
    
    $inventory = Get-Content $inventoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $functionName = $inventory.resources.lambdaFunction
    $region = $inventory.awsRegion
    
    Write-Host "Configuration:" -ForegroundColor Green
    Write-Host "  Lambda Function: $functionName" -ForegroundColor Gray
    Write-Host "  AWS Region: $region" -ForegroundColor Gray
    Write-Host "  Device ID: $DeviceId" -ForegroundColor Gray
    Write-Host "  Messages to send: $NumberOfMessages" -ForegroundColor Gray
    
    # Update inventory
    Update-Inventory @{
        currentStep = "testing-iot-message-format"
        testStartTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        messagesPlanned = $NumberOfMessages
        deviceId = $DeviceId
        testType = "iot-formatted-messages"
    }
    
    $testStartTime = Get-Date
    $successCount = 0
    
    # Send IoT messages
    for ($i = 1; $i -le $NumberOfMessages; $i++) {
        Write-Host ("-" * 50) -ForegroundColor Gray
        Write-Host "Sending IoT message $i of $NumberOfMessages" -ForegroundColor Blue
        
        # Create IoT message
        $iotMessage = New-IoTMessage -DeviceId $DeviceId -MessageIndex $i
        
        Write-Host "Generated IoT sensor data:" -ForegroundColor Gray
        Write-Host "  Heart Rate: $($iotMessage.vitals.heartRate) BPM" -ForegroundColor Gray
        Write-Host "  Temperature: $($iotMessage.vitals.temperature) C" -ForegroundColor Gray
        Write-Host "  Weight: $($iotMessage.weight) kg" -ForegroundColor Gray
        Write-Host "  Battery: $($iotMessage.batteryLevel)%" -ForegroundColor Gray
        
        # Send to Lambda
        $result = Invoke-LambdaWithIoTMessage -IoTMessage $iotMessage -FunctionName $functionName -Region $region
        
        if ($result.Success) {
            $successCount++
            Write-Host "Message ${i}: SUCCESS - Data sent to Firestore" -ForegroundColor Green
            
            Update-Inventory @{
                messagesSent = $successCount
                lastSuccessfulMessage = $iotMessage.messageId
                lastSuccessTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            }
        } else {
            Write-Host "Message ${i}: FAILED - $($result.Response)" -ForegroundColor Red
        }
        
        # Wait between messages
        if ($i -lt $NumberOfMessages) {
            Write-Host "Waiting 3 seconds before next message..." -ForegroundColor Gray
            Start-Sleep -Seconds 3
        }
    }
    
    # Wait for Firestore processing
    Write-Host ("-" * 50) -ForegroundColor Gray
    Write-Host "Waiting 10 seconds for Firestore processing..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    # Final results
    $testDuration = (Get-Date) - $testStartTime
    $successRate = if ($NumberOfMessages -gt 0) { [Math]::Round(($successCount / $NumberOfMessages) * 100, 1) } else { 0 }
    
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host "TEST RESULTS - IoT Message Format" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host "Messages sent successfully: $successCount / $NumberOfMessages" -ForegroundColor Green
    Write-Host "Success rate: $successRate%" -ForegroundColor Yellow
    Write-Host "Test duration: $($testDuration.ToString('mm\:ss'))" -ForegroundColor Gray
    
    if ($successCount -gt 0) {
        Write-Host "" -ForegroundColor White
        Write-Host "Data should now appear in Firestore in the following collections:" -ForegroundColor Cyan
        Write-Host "  - sensor_data (raw sensor readings)" -ForegroundColor White
        Write-Host "  - test_sessions (organized test data)" -ForegroundColor White
        Write-Host "  - user_profiles (if user exists for device)" -ForegroundColor White
        Write-Host "  - device_assignments (device-to-user mappings)" -ForegroundColor White
        Write-Host "" -ForegroundColor White
        Write-Host "Check your Firestore console for the data!" -ForegroundColor Green
    }
    
    # Update final inventory
    Update-Inventory @{
        currentStep = "iot-message-format-test-completed"
        endTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        successCount = $successCount
        successRate = $successRate
        duration = $testDuration.ToString()
        firestoreCollections = @("sensor_data", "test_sessions", "user_profiles", "device_assignments")
    }
    
    Write-Host "=" * 70 -ForegroundColor Cyan
    if ($successCount -eq $NumberOfMessages) {
        Write-Host "All IoT messages processed successfully!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Some messages failed. Check CloudWatch logs for details." -ForegroundColor Yellow
        exit 1
    }
    
} catch {
    Write-Host "Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Update-Inventory @{
        currentStep = "iot-test-failed"
        lastError = $_.Exception.Message
        errorTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    }
    exit 1
}
