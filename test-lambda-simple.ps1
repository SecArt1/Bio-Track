# Simple Lambda Test with Robust PowerShell Escaping
# Focus on testing Lambda invocation without complex features

param(
    [string]$DeviceId = "biotrack-device-001"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Simple Lambda Test - Robust Escaping" -ForegroundColor Green
Write-Host "Device ID: $DeviceId" -ForegroundColor Yellow

try {
    # Load configuration
    $inventoryPath = "cloud-inventory.json"
    if (-not (Test-Path $inventoryPath)) {
        throw "Inventory file not found"
    }
    
    $inventory = Get-Content $inventoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $functionName = $inventory.resources.lambdaFunction
    $region = $inventory.awsRegion
    
    Write-Host "Lambda Function: $functionName" -ForegroundColor Cyan
    Write-Host "AWS Region: $region" -ForegroundColor Cyan
    
    # Create simple test payload
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    $messageId = "simple_test_$((Get-Date).Ticks)"
    
    $payload = [PSCustomObject]@{
        deviceId = $DeviceId
        timestamp = $timestamp
        messageId = $messageId
        vitals = [PSCustomObject]@{
            heartRate = 72
            temperature = 36.5
            spo2 = 98
        }
        weight = 70.5
        batteryLevel = 85
        userId = "test_user"
    }    # Convert to JSON
    $jsonPayload = $payload | ConvertTo-Json -Depth 5 -Compress
    Write-Host "Payload created ($($jsonPayload.Length) chars)" -ForegroundColor Gray
    
    # Create temporary files with safe names
    $tempId = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    $payloadFile = Join-Path $env:TEMP "lambda_payload_$tempId.json"
    $responseFile = Join-Path $env:TEMP "lambda_response_$tempId.json"
    
    # Write payload file with explicit UTF8 encoding (no BOM)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($payloadFile, $jsonPayload, $utf8NoBom)
    
    # Verify the file was created correctly
    if (-not (Test-Path $payloadFile)) {
        throw "Failed to create payload file"
    }
    
    # Debug: Check file content
    $verifyContent = [System.IO.File]::ReadAllText($payloadFile, $utf8NoBom)
    Write-Host "Payload file size: $((Get-Item $payloadFile).Length) bytes" -ForegroundColor Gray
    
    Write-Host "Invoking Lambda function..." -ForegroundColor Cyan
    
    # Build AWS CLI arguments array (no shell escaping needed)
    $awsArgs = @(
        "lambda"
        "invoke"
        "--function-name"
        $functionName
        "--payload"
        "file://$payloadFile"
        "--region"
        $region
        $responseFile
    )
    
    Write-Host "AWS CLI command: aws $($awsArgs -join ' ')" -ForegroundColor Gray
    
    # Execute using Start-Process for reliable execution
    $process = Start-Process -FilePath "aws" -ArgumentList $awsArgs -Wait -PassThru -NoNewWindow
    
    # Clean up payload file
    if (Test-Path $payloadFile) {
        Remove-Item $payloadFile -Force
    }
    
    # Check results
    if ($process.ExitCode -eq 0) {
        Write-Host "Lambda invocation: SUCCESS" -ForegroundColor Green
        
        if (Test-Path $responseFile) {
            $response = Get-Content $responseFile -Raw -Encoding UTF8
            Write-Host "Response: $response" -ForegroundColor White
            
            # Clean up response file
            Remove-Item $responseFile -Force
        } else {
            Write-Host "Warning: No response file created" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Lambda invocation: FAILED (Exit Code: $($process.ExitCode))" -ForegroundColor Red
        
        # Clean up response file on failure
        if (Test-Path $responseFile) {
            Remove-Item $responseFile -Force
        }
    }
    
    # Wait for processing
    Write-Host "Waiting 5 seconds for processing..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    # Check recent CloudWatch logs
    Write-Host "Checking recent CloudWatch logs..." -ForegroundColor Cyan
    
    $logArgs = @(
        "logs"
        "describe-log-streams"
        "--log-group-name"
        "/aws/lambda/$functionName"
        "--order-by"
        "LastEventTime"
        "--descending"
        "--max-items"
        "3"
        "--region"
        $region
    )
    
    $logProcess = Start-Process -FilePath "aws" -ArgumentList $logArgs -Wait -PassThru -NoNewWindow
    
    if ($logProcess.ExitCode -eq 0) {
        Write-Host "CloudWatch logs check: SUCCESS" -ForegroundColor Green
    } else {
        Write-Host "CloudWatch logs check: FAILED" -ForegroundColor Red
    }
    
    Write-Host "Test completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "Test failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
