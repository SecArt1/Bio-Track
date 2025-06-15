# AWS Lambda Project Cleanup Script
Write-Host "🧹 Starting AWS Lambda Project Cleanup..." -ForegroundColor Cyan

$cleanedFiles = 0
$totalSpaceSaved = 0

function Remove-FilesSafely {
    param($files, $reason)
    foreach ($file in $files) {
        if (Test-Path $file) {
            $size = (Get-Item $file).Length
            Remove-Item $file -Force
            Write-Host "  ✓ REMOVED $file - $reason" -ForegroundColor Green
            $script:cleanedFiles++
            $script:totalSpaceSaved += $size
        }
    }
}

Write-Host "📁 Cleaning obsolete test response files..." -ForegroundColor Yellow

# Remove obsolete response files
$responseFiles = @(
    "response.json",
    "response-test.json", 
    "response-final.json",
    "response-ping-test.json",
    "response-connectivity-test.json",
    "response-test-updated.json"
)
Remove-FilesSafely $responseFiles "Obsolete test response files"

Write-Host "📁 Cleaning duplicate test payload files..." -ForegroundColor Yellow

# Remove duplicate/obsolete test files
$obsoleteTestFiles = @(
    "test-payload.json",
    "test-payload-ascii.json", 
    "test-payload-clean.json",
    "test-payload-updated.json",
    "test-clean-payload.json",
    "test-connectivity.json"
)
Remove-FilesSafely $obsoleteTestFiles "Duplicate or obsolete test files"

Write-Host "📁 Creating organized test directory..." -ForegroundColor Yellow

# Create tests directory
$testsDir = "tests"
if (-not (Test-Path $testsDir)) {
    New-Item -ItemType Directory -Path $testsDir | Out-Null
    Write-Host "  ✓ CREATED $testsDir directory" -ForegroundColor Green
}

# Move test files to tests directory
$testFilesToMove = @(
    "test-simple.json",
    "test-lambda-input.json",
    "test-user-specific.json",
    "test-user-sensor-data.json",
    "test-esp32-data.js",
    "test-user-functionality.js",
    "test-real-firebase.js"
)

foreach ($file in $testFilesToMove) {
    if (Test-Path $file) {
        $destination = Join-Path $testsDir $file
        Move-Item $file $destination -Force
        Write-Host "  ✓ MOVED $file -> tests/$file" -ForegroundColor Green
    }
}

Write-Host "📁 Creating documentation directory..." -ForegroundColor Yellow

# Create docs directory
$docsDir = "docs"
if (-not (Test-Path $docsDir)) {
    New-Item -ItemType Directory -Path $docsDir | Out-Null
    Write-Host "  ✓ CREATED $docsDir directory" -ForegroundColor Green
}

$docsToMove = @(
    "CLEANUP_SUMMARY.md",
    "DEPLOYMENT_GUIDE_COMPLETE.md"
)

foreach ($file in $docsToMove) {
    if (Test-Path $file) {
        $destination = Join-Path $docsDir $file
        Move-Item $file $destination -Force
        Write-Host "  ✓ MOVED $file -> docs/$file" -ForegroundColor Green
    }
}

Write-Host "📁 Creating deployment directory..." -ForegroundColor Yellow

# Create deployment directory
$deployDir = "deployment"
if (-not (Test-Path $deployDir)) {
    New-Item -ItemType Directory -Path $deployDir | Out-Null
    Write-Host "  ✓ CREATED $deployDir directory" -ForegroundColor Green
}

$deployFilesToMove = @(
    "cloudformation-template.yaml",
    "cloudformation-simple.yaml",
    "deploy.ps1",
    "deploy.sh",
    "check-deployment-fixed.ps1",
    "check-deployment.ps1"
)

foreach ($file in $deployFilesToMove) {
    if (Test-Path $file) {
        $destination = Join-Path $deployDir $file
        Move-Item $file $destination -Force
        Write-Host "  ✓ MOVED $file -> deployment/$file" -ForegroundColor Green
    }
}

Write-Host "🔧 Fixing package-lambda.ps1..." -ForegroundColor Yellow

# Remove empty package-lambda.ps1 if it exists
if ((Test-Path "package-lambda.ps1") -and (Get-Item "package-lambda.ps1").Length -eq 0) {
    Remove-Item "package-lambda.ps1" -Force
    Write-Host "  ✓ REMOVED empty package-lambda.ps1" -ForegroundColor Green
}

Write-Host ""
Write-Host "📊 Cleanup Summary:" -ForegroundColor Cyan
Write-Host "  Files cleaned: $cleanedFiles" -ForegroundColor White
Write-Host "  Space saved: $([math]::Round($totalSpaceSaved / 1KB, 2)) KB" -ForegroundColor White

Write-Host ""
Write-Host "✅ Project cleanup completed!" -ForegroundColor Green
Write-Host "📁 New project structure:" -ForegroundColor Cyan
Get-ChildItem -Directory | ForEach-Object { Write-Host "  📁 $($_.Name)/" -ForegroundColor White }
Get-ChildItem -File | Where-Object { $_.Name -match '\.(js|json|md)$' } | ForEach-Object { Write-Host "  📄 $($_.Name)" -ForegroundColor White }
