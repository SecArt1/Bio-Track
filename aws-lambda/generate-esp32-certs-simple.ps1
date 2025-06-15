# ESP32 Certificate Generation Script
Write-Host "=== ESP32 Certificate Generation ===" -ForegroundColor Green

$CERT_ID = "7f024911d9857e9882fbdb1a4b469259cb99247e795c99c2d4374b952f9e1737"
$CERT_DIR = "esp32-certificates"

# Create certificate directory
if (!(Test-Path $CERT_DIR)) {
    New-Item -ItemType Directory -Path $CERT_DIR
    Write-Host "Created directory: $CERT_DIR" -ForegroundColor Yellow
}

Set-Location $CERT_DIR

Write-Host "1. Downloading device certificate..." -ForegroundColor Cyan
$deviceCert = aws iot describe-certificate --certificate-id $CERT_ID --query "certificateDescription.certificatePem" --output text
if ($deviceCert -and $deviceCert -ne "None") {
    $deviceCert | Out-File -FilePath "device-cert.pem" -Encoding ASCII
    Write-Host "✓ Device certificate saved to device-cert.pem" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to retrieve device certificate" -ForegroundColor Red
}

Write-Host "2. Downloading AWS Root CA..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://www.amazontrust.com/repository/AmazonRootCA1.pem" -OutFile "aws-root-ca.pem"
Write-Host "✓ AWS Root CA saved to aws-root-ca.pem" -ForegroundColor Green

Write-Host "3. Certificate information:" -ForegroundColor Cyan
aws iot describe-certificate --certificate-id $CERT_ID --query "certificateDescription.{Status:status,CreationDate:creationDate}" --output table

Write-Host "4. Checking certificate attachment..." -ForegroundColor Cyan
$attachedThings = aws iot list-principal-things --principal "arn:aws:iot:eu-central-1:447191070724:cert/$CERT_ID" --query "things" --output text
if ($attachedThings) {
    Write-Host "✓ Certificate is attached to: $attachedThings" -ForegroundColor Green
} else {
    Write-Host "⚠ Certificate not attached to any thing" -ForegroundColor Yellow
}

Write-Host "`n=== Certificate Generation Complete ===" -ForegroundColor Green
Write-Host "Files generated:" -ForegroundColor Yellow
if (Test-Path "device-cert.pem") { Write-Host "  ✓ device-cert.pem" -ForegroundColor Green }
if (Test-Path "aws-root-ca.pem") { Write-Host "  ✓ aws-root-ca.pem" -ForegroundColor Green }

Set-Location ..
