# IoT Data Flow Test Script with Robust PowerShell Escaping
# Designed for reliable automation with proper error handling and escaping

param(
    [int]$NumberOfMessages = 2,
    [string]$DeviceId = "biotrack-device-001",
    [switch]$Verbose
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Function to safely update inventory with proper error handling
function Update-Inventory {
    param([hashtable]$Updates)
    
    try {
        $inventoryPath = Join-Path $PSScriptRoot "cloud-inventory.json"
        
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
            
            # Save with proper encoding
            $jsonOutput = $inventory | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($inventoryPath, $jsonOutput, [System.Text.UTF8Encoding]::new($false))
            
            Write-Host "Inventory updated successfully" -ForegroundColor Green
        } else {
            Write-Warning "Inventory file not found at: $inventoryPath"
        }
    }
    catch {
        Write-Warning "Failed to update inventory: $($_.Exception.Message)"
        if ($Verbose) {
            Write-Host "Full error details: $($_.Exception)" -ForegroundColor Red
        }
    }
}

# Function to create test payload with safe random data
function New-TestPayload {
    param(
        [string]$DeviceId,
        [int]$MessageIndex
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    $messageId = "test_msg_$((Get-Date).Ticks)_$MessageIndex"
    
    # Create structured payload with realistic biodata
    $payload = [PSCustomObject]@{
        deviceId = $DeviceId
        timestamp = $timestamp
        messageId = $messageId
        topic = "biotrack/device/$DeviceId/telemetry"
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
        userId = "user_placeholder"
    }
    
    return $payload
}

# Function to invoke Lambda using native PowerShell without Invoke-Expression
function Invoke-LambdaTest {
    param(
        [PSCustomObject]$Payload,
        [string]$FunctionName,
        [string]$Region = "eu-central-1"
    )
    
    try {
        # Convert payload to JSON with consistent formatting
        $jsonPayload = $Payload | ConvertTo-Json -Depth 10 -Compress
        
        if ($Verbose) {
            Write-Host "JSON Payload length: $($jsonPayload.Length) characters" -ForegroundColor Gray
            Write-Host "Sample payload: $($jsonPayload.Substring(0, [Math]::Min(200, $jsonPayload.Length)))..." -ForegroundColor Gray
        }
        
        # Create temporary files with safe naming
        $tempPrefix = [System.IO.Path]::GetRandomFileName().Replace(".", "")
        $payloadFile = Join-Path $env:TEMP "biotrack_payload_$tempPrefix.json"
        $responseFile = Join-Path $env:TEMP "biotrack_response_$tempPrefix.json"
        
        # Write payload to file with UTF8 encoding (no BOM)
        [System.IO.File]::WriteAllText($payloadFile, $jsonPayload, [System.Text.UTF8Encoding]::new($false))
        
        Write-Host "Invoking Lambda function: $FunctionName" -ForegroundColor Cyan
        
        # Use Start-Process for better control and escaping
        $awsArgs = @(
            "lambda", "invoke",
            "--function-name", $FunctionName,
            "--payload", "file://$payloadFile",
            "--region", $Region,
            $responseFile
        )
        
        if ($Verbose) {
            Write-Host "AWS CLI command: aws $($awsArgs -join ' ')" -ForegroundColor Gray
        }
        
        # Execute AWS CLI with proper process handling
        $processInfo = Start-Process -FilePath "aws" -ArgumentList $awsArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput $true -RedirectStandardError $true
        
        # Clean up payload file immediately
        if (Test-Path $payloadFile) {
            Remove-Item $payloadFile -Force -ErrorAction SilentlyContinue
        }
        
        if ($processInfo.ExitCode -eq 0) {
            Write-Host "Lambda invocation successful" -ForegroundColor Green
            
            if (Test-Path $responseFile) {
                $response = Get-Content $responseFile -Raw -Encoding UTF8
                Write-Host "Lambda response: $response" -ForegroundColor White
                
                # Clean up response file
                Remove-Item $responseFile -Force -ErrorAction SilentlyContinue
                
                return @{
                    Success = $true
                    Response = $response
                    ExitCode = $processInfo.ExitCode
                }
            } else {
                Write-Warning "Response file not created"
                return @{
                    Success = $false
                    Response = "No response file"
                    ExitCode = $processInfo.ExitCode
                }
            }
        } else {
            Write-Host "Lambda invocation failed with exit code: $($processInfo.ExitCode)" -ForegroundColor Red
            
            # Clean up response file on failure
            if (Test-Path $responseFile) {
                Remove-Item $responseFile -Force -ErrorAction SilentlyContinue
            }
            
            return @{
                Success = $false
                Response = "AWS CLI failed"
                ExitCode = $processInfo.ExitCode
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

# Function to test CloudWatch logs for Lambda execution
function Test-LambdaLogs {
    param(
        [string]$FunctionName,
        [string]$Region = "eu-central-1",
        [datetime]$StartTime
    )
    
    try {        $logGroupName = "/aws/lambda/$FunctionName"
        # Convert StartTime to epoch milliseconds for CloudWatch API
        $epochStart = [int64](($StartTime.ToUniversalTime() - (Get-Date "1970-01-01")).TotalMilliseconds)
        
        Write-Host "Checking CloudWatch logs for function: $FunctionName" -ForegroundColor Yellow
        
        # Get recent log streams
        $streamArgs = @(
            "logs", "describe-log-streams",
            "--log-group-name", $logGroupName,
            "--order-by", "LastEventTime",
            "--descending",
            "--max-items", "5",
            "--region", $Region
        )
        
        $streamsProcess = Start-Process -FilePath "aws" -ArgumentList $streamArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput $true -RedirectStandardError $true
        
        if ($streamsProcess.ExitCode -eq 0) {
            Write-Host "Successfully retrieved log stream information" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Failed to retrieve log streams" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "Error checking logs: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution starts here
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "IoT Data Flow Test - Robust PowerShell Implementation" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Device ID: $DeviceId" -ForegroundColor Yellow
Write-Host "Messages to test: $NumberOfMessages" -ForegroundColor Yellow
Write-Host "Verbose mode: $Verbose" -ForegroundColor Yellow

# Load configuration from inventory
try {
    $inventoryPath = Join-Path $PSScriptRoot "cloud-inventory.json"
    if (-not (Test-Path $inventoryPath)) {
        throw "Inventory file not found at: $inventoryPath"
    }
    
    $inventory = Get-Content $inventoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $functionName = $inventory.resources.lambdaFunction
    $region = $inventory.awsRegion
    
    Write-Host "Loaded configuration:" -ForegroundColor Green
    Write-Host "  Lambda Function: $functionName" -ForegroundColor Gray
    Write-Host "  AWS Region: $region" -ForegroundColor Gray
}
catch {
    Write-Host "Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Update inventory with test start
Update-Inventory @{
    currentStep = "starting-robust-lambda-test"
    testStartTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    messagesPlanned = $NumberOfMessages
    deviceId = $DeviceId
}

$testStartTime = Get-Date
$successCount = 0
$results = @()

# Execute test messages
for ($i = 1; $i -le $NumberOfMessages; $i++) {
    Write-Host ("-" * 40) -ForegroundColor Gray
    Write-Host "Processing test message $i of $NumberOfMessages" -ForegroundColor Blue
    
    # Generate test payload
    $testPayload = New-TestPayload -DeviceId $DeviceId -MessageIndex $i
    
    if ($Verbose) {
        Write-Host "Generated sensor data:" -ForegroundColor Gray
        Write-Host "  Heart Rate: $($testPayload.vitals.heartRate) BPM" -ForegroundColor Gray
        Write-Host "  Temperature: $($testPayload.vitals.temperature) C" -ForegroundColor Gray
        Write-Host "  Weight: $($testPayload.weight) kg" -ForegroundColor Gray
        Write-Host "  Battery: $($testPayload.batteryLevel)%" -ForegroundColor Gray
    }
    
    # Test Lambda function
    $result = Invoke-LambdaTest -Payload $testPayload -FunctionName $functionName -Region $region
    $results += $result
    
    if ($result.Success) {
        $successCount++
        Write-Host "Message ${i}: SUCCESS" -ForegroundColor Green
        
        Update-Inventory @{
            messagesSent = $successCount
            lastSuccessfulTest = $testPayload.messageId
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
Write-Host ("-" * 40) -ForegroundColor Gray
Write-Host "Waiting 10 seconds for Lambda processing to complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Check CloudWatch logs
Write-Host "Checking CloudWatch logs..." -ForegroundColor Yellow
$logCheckResult = Test-LambdaLogs -FunctionName $functionName -Region $region -StartTime $testStartTime

# Generate final report
$testDuration = (Get-Date) - $testStartTime
$successRate = if ($NumberOfMessages -gt 0) { [Math]::Round(($successCount / $NumberOfMessages) * 100, 1) } else { 0 }

Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "TEST RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Messages sent successfully: $successCount / $NumberOfMessages" -ForegroundColor Green
Write-Host "Messages failed: $($NumberOfMessages - $successCount)" -ForegroundColor Red
Write-Host "Success rate: $successRate%" -ForegroundColor Yellow
Write-Host "Test duration: $($testDuration.ToString('mm\:ss'))" -ForegroundColor Gray
Write-Host "CloudWatch log check: $(if ($logCheckResult) { 'SUCCESS' } else { 'FAILED' })" -ForegroundColor $(if ($logCheckResult) { 'Green' } else { 'Red' })

# Update final inventory
Update-Inventory @{
    currentStep = "robust-lambda-test-completed"
    endTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    successCount = $successCount
    failureCount = ($NumberOfMessages - $successCount)
    successRate = $successRate
    duration = $testDuration.ToString()
    logCheckResult = $logCheckResult
}

Write-Host "=" * 60 -ForegroundColor Cyan
if ($successCount -eq $NumberOfMessages) {
    Write-Host "All tests completed successfully!" -ForegroundColor Green
} else {
    Write-Host "Some tests failed. Check the logs for details." -ForegroundColor Yellow
}
Write-Host "Results saved to cloud-inventory.json" -ForegroundColor Cyan

# Return exit code based on success
exit $(if ($successCount -eq $NumberOfMessages) { 0 } else { 1 })
