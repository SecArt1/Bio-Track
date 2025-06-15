# AWS Lambda Project Cleanup Script
# Removes obsolete files and organizes the project structure

Write-Host "🧹 Starting AWS Lambda Project Cleanup..." -ForegroundColor Cyan

# Create cleanup log
$cleanupLog = @()
$cleanedFiles = 0
$totalSpaceSaved = 0

# Function to log cleanup actions
function Add-CleanupLog {
    param($action, $file, $reason)
    $script:cleanupLog += "[$(Get-Date -Format 'HH:mm:ss')] $action - $file - $reason"
    Write-Host "  ✓ $action $file" -ForegroundColor Green
}

# Function to safely remove files
function Remove-FilesSafely {
    param($files, $reason)
    foreach ($file in $files) {
        if (Test-Path $file) {
            $size = (Get-Item $file).Length
            Remove-Item $file -Force
            Add-CleanupLog "REMOVED" $file $reason
            $script:cleanedFiles++
            $script:totalSpaceSaved += $size
        }
    }
}
}

Write-Host "📁 Cleaning obsolete test response files..." -ForegroundColor Yellow

# Remove obsolete response files (keeping only the most recent)
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

# Remove duplicate/obsolete test files (keeping the most useful ones)
$obsoleteTestFiles = @(
    "test-payload.json",
    "test-payload-ascii.json", 
    "test-payload-clean.json",
    "test-payload-updated.json",
    "test-clean-payload.json",
    "test-connectivity.json"
)
Remove-FilesSafely $obsoleteTestFiles "Duplicate or obsolete test files"

Write-Host "📁 Cleaning duplicate deployment files..." -ForegroundColor Yellow

# Remove duplicate deployment files
$duplicateDeployFiles = @(
    "check-deployment.ps1"  # Keep check-deployment-fixed.ps1
)
Remove-FilesSafely $duplicateDeployFiles "Duplicate deployment files"

Write-Host "📁 Creating organized test directory..." -ForegroundColor Yellow

# Create a tests directory and move remaining test files
$testsDir = "tests"
if (-not (Test-Path $testsDir)) {
    New-Item -ItemType Directory -Path $testsDir | Out-Null
    Add-CleanupLog "CREATED" $testsDir "Organized test directory"
}

# Move important test files to tests directory
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
        Add-CleanupLog "MOVED" "$file -> tests/$file" "Organized into tests directory"
    }
}

Write-Host "📁 Creating documentation directory..." -ForegroundColor Yellow

# Create docs directory and move documentation
$docsDir = "docs"
if (-not (Test-Path $docsDir)) {
    New-Item -ItemType Directory -Path $docsDir | Out-Null
    Add-CleanupLog "CREATED" $docsDir "Organized documentation directory"
}

$docsToMove = @(
    "CLEANUP_SUMMARY.md",
    "DEPLOYMENT_GUIDE_COMPLETE.md"
)

foreach ($file in $docsToMove) {
    if (Test-Path $file) {
        $destination = Join-Path $docsDir $file
        Move-Item $file $destination -Force
        Add-CleanupLog "MOVED" "$file -> docs/$file" "Organized into docs directory"
    }
}

Write-Host "📁 Creating deployment directory..." -ForegroundColor Yellow

# Create deployment directory and move deployment files
$deployDir = "deployment"
if (-not (Test-Path $deployDir)) {
    New-Item -ItemType Directory -Path $deployDir | Out-Null
    Add-CleanupLog "CREATED" $deployDir "Organized deployment directory"
}

$deployFilesToMove = @(
    "cloudformation-template.yaml",
    "cloudformation-simple.yaml",
    "deploy.ps1",
    "deploy.sh",
    "check-deployment-fixed.ps1"
)

foreach ($file in $deployFilesToMove) {
    if (Test-Path $file) {
        $destination = Join-Path $deployDir $file
        Move-Item $file $destination -Force
        Add-CleanupLog "MOVED" "$file -> deployment/$file" "Organized into deployment directory"
    }
}

Write-Host "🔧 Fixing package-lambda.ps1..." -ForegroundColor Yellow

# Fix the empty package-lambda.ps1 file
if ((Test-Path "package-lambda.ps1") -and (Get-Item "package-lambda.ps1").Length -eq 0) {
    Remove-Item "package-lambda.ps1" -Force
    Add-CleanupLog "REMOVED" "package-lambda.ps1" "Empty file - will be recreated"
}

Write-Host "📊 Cleanup Summary:" -ForegroundColor Cyan
Write-Host "  Files cleaned: $cleanedFiles" -ForegroundColor White
Write-Host "  Space saved: $([math]::Round($totalSpaceSaved / 1KB, 2)) KB" -ForegroundColor White

# Save cleanup log
$cleanupLog | Out-File "cleanup-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
Add-CleanupLog "CREATED" "cleanup-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt" "Cleanup log file"

Write-Host "✅ Project cleanup completed!" -ForegroundColor Green
Write-Host "📁 New project structure:" -ForegroundColor Cyan
Write-Host "  /tests/           - All test files" -ForegroundColor White
Write-Host "  /docs/            - Documentation" -ForegroundColor White  
Write-Host "  /deployment/      - Deployment scripts" -ForegroundColor White
Write-Host "  /certificates/    - SSL certificates" -ForegroundColor White
Write-Host "  index.js          - Main Lambda function" -ForegroundColor White
Write-Host "  package.json      - Dependencies" -ForegroundColor White
Write-Host "  README.md         - Project documentation" -ForegroundColor White

Write-Host ""
Write-Host "🔄 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Recreate package-lambda.ps1" -ForegroundColor White
Write-Host "  2. Test Lambda function with organized test files" -ForegroundColor White
Write-Host "  3. Deploy using deployment/deploy.ps1" -ForegroundColor White
