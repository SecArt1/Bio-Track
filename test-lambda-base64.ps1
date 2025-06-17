# Lambda Test with Base64 Payload (No File Encoding Issues)
# Uses base64 payload to avoid any file encoding problems

param(
    [string]$DeviceId = "biotrack-device-001"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Lambda Test - Base64 Payload Method" -ForegroundColor Green
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
    $messageId = "base64_test_$((Get-Date).Ticks)"
    
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
    }
    
    # Convert to JSON and then to base64
    $jsonPayload = $payload | ConvertTo-Json -Depth 5 -Compress
    $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)
    $base64Payload = [System.Convert]::ToBase64String($jsonBytes)
    
    Write-Host "Payload created ($($jsonPayload.Length) chars, $($base64Payload.Length) base64 chars)" -ForegroundColor Gray
    
    # Create response file
    $tempId = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    $responseFile = Join-Path $env:TEMP "lambda_response_$tempId.json"
    
    Write-Host "Invoking Lambda function with base64 payload..." -ForegroundColor Cyan
    
    # Build AWS CLI arguments with base64 payload
    $awsArgs = @(
        "lambda"
        "invoke"
        "--function-name"
        $functionName
        "--payload"
        $base64Payload
        "--region"
        $region
        $responseFile
    )
    
    Write-Host "AWS CLI command: aws lambda invoke --function-name $functionName --payload [base64-data] --region $region $responseFile" -ForegroundColor Gray
    
    # Execute using Start-Process
    $process = Start-Process -FilePath "aws" -ArgumentList $awsArgs -Wait -PassThru -NoNewWindow
    
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
    
    Write-Host "Test completed!" -ForegroundColor Green
    
} catch {
    Write-Host "Test failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
