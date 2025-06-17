# IoT Data Flow Test Script with Proper PowerShell Escaping
# Following cloud automation best practices with inventory management

param(
    [int]$NumberOfMessages = 2,
    [string]$DeviceId = 'biotrack-device-001'
)

# Function to update inventory safely
function Update-Inventory {
    param([hashtable]$Updates)
    
    try {
        $inventoryPath = 'cloud-inventory.json'
        if (Test-Path $inventoryPath) {
            $inventory = Get-Content $inventoryPath -Raw | ConvertFrom-Json
            
            foreach ($key in $Updates.Keys) {
                $inventory.testingProgress.$key = $Updates[$key]
            }
            
            $inventory.timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
            $inventory | ConvertTo-Json -Depth 10 | Set-Content $inventoryPath -Encoding UTF8
            
            Write-Host "Inventory updated successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Failed to update inventory: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Function to create test payload with proper escaping
function New-TestPayload {
    param([string]$deviceId, [int]$messageIndex)
    
    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
    $messageId = "test_msg_$((Get-Date).Ticks)_$messageIndex"
    
    # Create hashtable first, then convert to JSON to avoid escaping issues
    $payload = @{
        deviceId = $deviceId
        timestamp = $timestamp
        messageId = $messageId
        topic = "biotrack/device/$deviceId/telemetry"
        vitals = @{
            heartRate = (Get-Random -Minimum 65 -Maximum 95)
            temperature = [math]::Round((Get-Random -Minimum 36.2 -Maximum 37.8), 1)
            spo2 = (Get-Random -Minimum 95 -Maximum 100)
        }
        weight = [math]::Round((Get-Random -Minimum 65.0 -Maximum 85.0), 1)
        batteryLevel = (Get-Random -Minimum 75 -Maximum 100)
        userId = 'user_placeholder'
    }
    
    return $payload
}

# Function to invoke Lambda with proper error handling
function Invoke-LambdaTest {
    param([hashtable]$Payload, [string]$FunctionName)
    
    try {
        # Convert payload to JSON with proper depth
        $jsonPayload = $Payload | ConvertTo-Json -Depth 10 -Compress
        
        # Create temporary file with UTF8 encoding (no BOM)
        $tempFile = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($tempFile, $jsonPayload, [System.Text.UTF8Encoding]::new($false))
        
        Write-Host "Invoking Lambda function: $FunctionName" -ForegroundColor Cyan
        Write-Host "Payload size: $($jsonPayload.Length) bytes" -ForegroundColor Gray
        
        # Use properly escaped AWS CLI command
        $responseFile = [System.IO.Path]::GetTempFileName()
        
        # Execute AWS CLI with proper parameter escaping
        $awsCmd = "aws lambda invoke --function-name `"$FunctionName`" --payload `"file://$tempFile`" --region eu-central-1 `"$responseFile`""
        $result = Invoke-Expression $awsCmd 2>&1
        
        # Clean up temp file
        Remove-Item $tempFile -ErrorAction SilentlyContinue
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Lambda invocation successful" -ForegroundColor Green
            
            if (Test-Path $responseFile) {
                $response = Get-Content $responseFile -Raw
                Write-Host "Lambda response: $response" -ForegroundColor White
                Remove-Item $responseFile -ErrorAction SilentlyContinue
                return $true
            }
        } else {
            Write-Host "Lambda invocation failed: $result" -ForegroundColor Red
            Remove-Item $responseFile -ErrorAction SilentlyContinue
            return $false
        }
    }
    catch {
        Write-Host "Error during Lambda invocation: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution
Write-Host 'Starting IoT Data Flow Test with Proper Escaping' -ForegroundColor Green
Write-Host "Device ID: $DeviceId" -ForegroundColor Yellow
Write-Host "Messages to test: $NumberOfMessages" -ForegroundColor Yellow

# Update inventory with test start
Update-Inventory @{
    currentStep = 'starting-lambda-test-with-escaping'
    testStartTime = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    messagesPlanned = $NumberOfMessages
}

$testStartTime = Get-Date
$successCount = 0

# Load inventory to get function name
$inventory = Get-Content 'cloud-inventory.json' -Raw | ConvertFrom-Json
$functionName = $inventory.resources.lambdaFunction

for ($i = 1; $i -le $NumberOfMessages; $i++) {
    Write-Host "Processing test message $i/$NumberOfMessages" -ForegroundColor Blue
    
    # Generate test payload
    $testPayload = New-TestPayload -deviceId $DeviceId -messageIndex $i
    
    Write-Host "Generated sensor data:" -ForegroundColor Gray
    Write-Host "  Heart Rate: $($testPayload.vitals.heartRate) BPM" -ForegroundColor Gray
    Write-Host "  Temperature: $($testPayload.vitals.temperature) C" -ForegroundColor Gray
    Write-Host "  Weight: $($testPayload.weight) kg" -ForegroundColor Gray
    Write-Host "  Battery: $($testPayload.batteryLevel)%" -ForegroundColor Gray
    
    # Test Lambda function
    $success = Invoke-LambdaTest -Payload $testPayload -FunctionName $functionName
    
    if ($success) {
        $successCount++
        Update-Inventory @{
            messagesSent = $successCount
            lastSuccessfulTest = $testPayload.messageId
        }
    }
    
    # Wait between tests
    if ($i -lt $NumberOfMessages) {
        Write-Host 'Waiting 3 seconds before next test...' -ForegroundColor Gray
        Start-Sleep -Seconds 3
    }
}

# Wait for processing
Write-Host "Waiting 10 seconds for Lambda processing..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Final report
$testDuration = (Get-Date) - $testStartTime
$successRate = [math]::Round(($successCount / $NumberOfMessages) * 100, 1)

Write-Host "Test Results Summary" -ForegroundColor Green
Write-Host "Messages sent successfully: $successCount" -ForegroundColor Green
Write-Host "Messages failed: $($NumberOfMessages - $successCount)" -ForegroundColor Red
Write-Host "Success rate: $successRate%" -ForegroundColor Yellow
Write-Host "Test duration: $($testDuration.ToString('mm\:ss'))" -ForegroundColor Gray

# Update final inventory
Update-Inventory @{
    currentStep = 'lambda-test-completed'
    endTime = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    successCount = $successCount
    failureCount = ($NumberOfMessages - $successCount)
    successRate = $successRate
    duration = $testDuration.ToString()
}

Write-Host "Test completed successfully!" -ForegroundColor Green
Write-Host 'Results saved to cloud-inventory.json' -ForegroundColor Cyan
