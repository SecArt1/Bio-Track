# ESP32 Certificate Generation Script
# This script generates all necessary certificates for ESP32 AWS IoT connection

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
try {
    $deviceCert = aws iot describe-certificate --certificate-id $CERT_ID --query "certificateDescription.certificatePem" --output text
    if ($deviceCert -and $deviceCert -ne "None") {
        $deviceCert | Out-File -FilePath "device-cert.pem" -Encoding ASCII
        Write-Host "✓ Device certificate saved to device-cert.pem" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to retrieve device certificate" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Error downloading device certificate: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "2. Downloading AWS Root CA..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "https://www.amazontrust.com/repository/AmazonRootCA1.pem" -OutFile "aws-root-ca.pem"
    Write-Host "✓ AWS Root CA saved to aws-root-ca.pem" -ForegroundColor Green
} catch {
    Write-Host "✗ Error downloading AWS Root CA: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "3. Certificate information:" -ForegroundColor Cyan
try {
    $certInfo = aws iot describe-certificate --certificate-id $CERT_ID --query "certificateDescription.{Status:status,CreationDate:creationDate,CertificateArn:certificateArn}" --output table
    Write-Host $certInfo
} catch {
    Write-Host "✗ Error retrieving certificate info" -ForegroundColor Red
}

Write-Host "`n4. Checking certificate attachment to thing..." -ForegroundColor Cyan
try {
    $attachedThings = aws iot list-principal-things --principal "arn:aws:iot:eu-central-1:447191070724:cert/$CERT_ID" --query "things" --output text
    if ($attachedThings) {
        Write-Host "✓ Certificate is attached to: $attachedThings" -ForegroundColor Green
    } else {
        Write-Host "⚠ Certificate not attached to any thing" -ForegroundColor Yellow
        Write-Host "Attaching certificate to biotrack-device-001..." -ForegroundColor Cyan
        aws iot attach-thing-principal --thing-name "biotrack-device-001" --principal "arn:aws:iot:eu-central-1:447191070724:cert/$CERT_ID"
        Write-Host "✓ Certificate attached to biotrack-device-001" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Error checking certificate attachment: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Certificate Generation Complete ===" -ForegroundColor Green
Write-Host "Files generated in ${CERT_DIR}:" -ForegroundColor Yellow
if (Test-Path "device-cert.pem") { Write-Host "  ✓ device-cert.pem" -ForegroundColor Green }
if (Test-Path "aws-root-ca.pem") { Write-Host "  ✓ aws-root-ca.pem" -ForegroundColor Green }

Write-Host "`nNote: You'll need the private key file that was generated when the certificate was created." -ForegroundColor Yellow
Write-Host "If you don't have it, you may need to create a new certificate pair." -ForegroundColor Yellow

Set-Location ..
