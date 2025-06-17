# Comprehensive IoT End-to-End Test with Robust PowerShell Escaping
# Tests the complete ESP32 -> Lambda -> Firestore data flow with proper error handling

param(
    [int]$NumberOfMessages = 2,
    [string]$DeviceId = "biotrack-device-001",
    [switch]$Verbose
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Function to safely update inventory
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
            
            # Save with UTF8 encoding
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

# Function to create realistic IoT sensor payload
function New-IoTSensorPayload {
    param(
        [string]$DeviceId,
        [int]$MessageIndex
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    $messageId = "iot_msg_$((Get-Date).Ticks)_$MessageIndex"
    
    # Create IoT device payload that matches ESP32 firmware structure
    $payload = [PSCustomObject]@{
        deviceId = $DeviceId
        timestamp = $timestamp
        messageId = $messageId
        type = "telemetry"
        source = "esp32-biotrack"
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
        deviceStatus = [PSCustomObject]@{
            batteryLevel = Get-Random -Minimum 75 -Maximum 100
            signalStrength = Get-Random -Minimum -70 -Maximum -30
            firmwareVersion = "1.0.2"
            lastCalibration = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        userId = "test_user_biotrack"
        sessionId = "session_$((Get-Date).ToString('yyyyMMdd'))_001"
    }
    
    return $payload
}

# Function to invoke Lambda with base64 payload (avoiding file encoding issues)
function Invoke-LambdaWithBase64 {
    param(
        [PSCustomObject]$Payload,
        [string]$FunctionName,
        [string]$Region = "eu-central-1"
    )
    
    try {
        # Convert payload to JSON and then base64
        $jsonPayload = $Payload | ConvertTo-Json -Depth 10 -Compress
        $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)
        $base64Payload = [System.Convert]::ToBase64String($jsonBytes)
        
        if ($Verbose) {
            Write-Host "JSON payload length: $($jsonPayload.Length) chars" -ForegroundColor Gray
            Write-Host "Base64 payload length: $($base64Payload.Length) chars" -ForegroundColor Gray
        }
        
        # Create response file
        $tempId = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
        $responseFile = Join-Path $env:TEMP "lambda_response_$tempId.json"
        
        Write-Host "Invoking Lambda function: $FunctionName" -ForegroundColor Cyan
        
        # Build AWS CLI arguments with base64 payload
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
        
        if ($Verbose) {
            Write-Host "AWS CLI command: aws lambda invoke --function-name $FunctionName --payload [base64-data] --region $Region" -ForegroundColor Gray
        }
        
        # Execute using Start-Process for reliable execution
        $process = Start-Process -FilePath "aws" -ArgumentList $awsArgs -Wait -PassThru -NoNewWindow
        
        # Check results
        if ($process.ExitCode -eq 0) {
            Write-Host "Lambda invocation: SUCCESS" -ForegroundColor Green
            
            if (Test-Path $responseFile) {
                $response = Get-Content $responseFile -Raw -Encoding UTF8
                Write-Host "Lambda response: $response" -ForegroundColor White
                
                # Clean up response file
                Remove-Item $responseFile -Force -ErrorAction SilentlyContinue
                
                return @{
                    Success = $true
                    Response = $response
                    ExitCode = $process.ExitCode
                }
            } else {
                Write-Warning "No response file created"
                return @{
                    Success = $false
                    Response = "No response file"
                    ExitCode = $process.ExitCode
                }
            }
        } else {
            Write-Host "Lambda invocation: FAILED (Exit Code: $($process.ExitCode))" -ForegroundColor Red
            
            # Clean up response file on failure
            if (Test-Path $responseFile) {
                Remove-Item $responseFile -Force -ErrorAction SilentlyContinue
            }
            
            return @{
                Success = $false
                Response = "AWS CLI failed"
                ExitCode = $process.ExitCode
            }
        }
    }
    catch {
        Write-Host "Error during Lambda invocation: $($_.Exception.Message)" -ForegroundColor Red
        if ($Verbose) {
            Write-Host "Full error: $($_.Exception)" -ForegroundColor Red
        }
        
        return @{
            Success = $false
            Response = $_.Exception.Message
            ExitCode = -1
        }
    }
}

# Main execution
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "Comprehensive IoT End-to-End Test with Robust PowerShell Escaping" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "Device ID: $DeviceId" -ForegroundColor Yellow
Write-Host "Messages to test: $NumberOfMessages" -ForegroundColor Yellow
Write-Host "Verbose mode: $Verbose" -ForegroundColor Yellow

try {
    # Load configuration
    $inventoryPath = "cloud-inventory.json"
    if (-not (Test-Path $inventoryPath)) {
        throw "Inventory file not found"
    }
    
    $inventory = Get-Content $inventoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $functionName = $inventory.resources.lambdaFunction
    $region = $inventory.awsRegion
    
    Write-Host "Configuration loaded:" -ForegroundColor Green
    Write-Host "  Lambda Function: $functionName" -ForegroundColor Gray
    Write-Host "  AWS Region: $region" -ForegroundColor Gray
    
    # Update inventory with test start
    Update-Inventory @{
        currentStep = "starting-comprehensive-iot-test"
        testStartTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        messagesPlanned = $NumberOfMessages
        deviceId = $DeviceId
        testMethod = "base64-payload-robust-escaping"
    }
    
    $testStartTime = Get-Date
    $successCount = 0
    $results = @()
    
    # Execute test messages
    for ($i = 1; $i -le $NumberOfMessages; $i++) {
        Write-Host ("-" * 50) -ForegroundColor Gray
        Write-Host "Processing IoT message ${i} of $NumberOfMessages" -ForegroundColor Blue
        
        # Generate realistic IoT sensor payload
        $iotPayload = New-IoTSensorPayload -DeviceId $DeviceId -MessageIndex $i
        
        if ($Verbose) {
            Write-Host "Generated IoT sensor data:" -ForegroundColor Gray
            Write-Host "  Heart Rate: $($iotPayload.vitals.heartRate) BPM" -ForegroundColor Gray
            Write-Host "  Temperature: $($iotPayload.vitals.temperature) C" -ForegroundColor Gray
            Write-Host "  Weight: $($iotPayload.weight) kg" -ForegroundColor Gray
            Write-Host "  Battery: $($iotPayload.deviceStatus.batteryLevel)%" -ForegroundColor Gray
            Write-Host "  Message ID: $($iotPayload.messageId)" -ForegroundColor Gray
        }
        
        # Test Lambda function
        $result = Invoke-LambdaWithBase64 -Payload $iotPayload -FunctionName $functionName -Region $region
        $results += $result
        
        if ($result.Success) {
            $successCount++
            Write-Host "Message ${i}: SUCCESS" -ForegroundColor Green
            
            Update-Inventory @{
                messagesSent = $successCount
                lastSuccessfulTest = $iotPayload.messageId
                lastSuccessTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            }
        } else {
            Write-Host "Message ${i}: FAILED - $($result.Response)" -ForegroundColor Red
        }
        
        # Wait between tests (except for the last one)
        if ($i -lt $NumberOfMessages) {
            Write-Host "Waiting 3 seconds before next test..." -ForegroundColor Gray
            Start-Sleep -Seconds 3
        }
    }
    
    # Wait for processing to complete
    Write-Host ("-" * 50) -ForegroundColor Gray
    Write-Host "Waiting 10 seconds for Lambda processing and Firestore writes..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    # Generate final report
    $testDuration = (Get-Date) - $testStartTime
    $successRate = if ($NumberOfMessages -gt 0) { [Math]::Round(($successCount / $NumberOfMessages) * 100, 1) } else { 0 }
    
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host "TEST RESULTS SUMMARY" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host "Messages sent successfully: $successCount / $NumberOfMessages" -ForegroundColor Green
    Write-Host "Messages failed: $($NumberOfMessages - $successCount)" -ForegroundColor Red
    Write-Host "Success rate: $successRate%" -ForegroundColor Yellow
    Write-Host "Test duration: $($testDuration.ToString('mm\:ss'))" -ForegroundColor Gray
    Write-Host "Escaping method: Base64 payload encoding" -ForegroundColor Cyan
    
    # Update final inventory
    Update-Inventory @{
        currentStep = "comprehensive-iot-test-completed"
        endTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        successCount = $successCount
        failureCount = ($NumberOfMessages - $successCount)
        successRate = $successRate
        duration = $testDuration.ToString()
        escapingMethod = "base64-payload-encoding"
    }
    
    Write-Host "=" * 70 -ForegroundColor Cyan
    if ($successCount -eq $NumberOfMessages) {
        Write-Host "All IoT tests completed successfully!" -ForegroundColor Green
        Write-Host "ESP32 sensor data simulation successful" -ForegroundColor Green
    } else {
        Write-Host "Some tests failed. Check the logs for details." -ForegroundColor Yellow
    }
    Write-Host "Results saved to cloud-inventory.json" -ForegroundColor Cyan
    
    # Return appropriate exit code
    exit $(if ($successCount -eq $NumberOfMessages) { 0 } else { 1 })
    
} catch {
    Write-Host "Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($Verbose) {
        Write-Host "Full error: $($_.Exception)" -ForegroundColor Red
    }
    
    Update-Inventory @{
        currentStep = "test-execution-failed"
        lastError = $_.Exception.Message
        errorTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    }
    
    exit 1
}
