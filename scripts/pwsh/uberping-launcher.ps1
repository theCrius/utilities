# UberPing Launcher - Handles execution policy issues
# This script helps run UberPing on systems with strict execution policies

param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

# Check if we have any arguments
if ($Arguments.Count -eq 0) {
    Write-Host "UberPing Launcher" -ForegroundColor Cyan
    Write-Host "Usage: .\uberping-launcher.ps1 <destination> [additional parameters]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "  .\uberping-launcher.ps1 8.8.8.8" -ForegroundColor White
    Write-Host "  .\uberping-launcher.ps1 google.com -TimeLimit 60 -LogFile 'ping.log'" -ForegroundColor White
    exit 1
}

# Get the directory where this launcher script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$uberpingScript = Join-Path $scriptDir "uberping.ps1"

# Check if uberping.ps1 exists
if (-not (Test-Path $uberpingScript)) {
    Write-Host "ERROR: UberPing script not found at: $uberpingScript" -ForegroundColor Red
    Write-Host "Make sure uberping.ps1 is in the same directory as this launcher." -ForegroundColor Yellow
    exit 1
}

# Function to display execution policy help
function Show-ExecutionPolicyHelp {
    Write-Host "`nExecution Policy Issue Detected!" -ForegroundColor Red
    Write-Host "=" * 50 -ForegroundColor Red
    Write-Host "PowerShell cannot run the script due to execution policy restrictions." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "SOLUTIONS (choose one):" -ForegroundColor Green
    Write-Host ""
    Write-Host "1. TEMPORARY - Run once with bypass:" -ForegroundColor Cyan
    Write-Host "   PowerShell -ExecutionPolicy Bypass -File `"$uberpingScript`" $($Arguments -join ' ')" -ForegroundColor White
    Write-Host ""
    Write-Host "2. SESSION - Allow for current session only:" -ForegroundColor Cyan
    Write-Host "   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
    Write-Host "   Then run: .\uberping.ps1 $($Arguments -join ' ')" -ForegroundColor White
    Write-Host ""
    Write-Host "3. PERMANENT - Change user policy (recommended):" -ForegroundColor Cyan
    Write-Host "   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
    Write-Host ""
    Write-Host "4. ADMIN - Change system-wide policy (requires admin):" -ForegroundColor Cyan
    Write-Host "   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned" -ForegroundColor White
    Write-Host ""
    Write-Host "Current Execution Policy: $((Get-ExecutionPolicy).ToString())" -ForegroundColor Yellow
    Write-Host "For more info: Get-Help about_Execution_Policies" -ForegroundColor Gray
}

# Try to run the script and catch execution policy errors
try {
    Write-Host "Launching UberPing..." -ForegroundColor Green
    
    # Try to execute the script
    $expression = "& `"$uberpingScript`" $($Arguments -join ' ')"
    Invoke-Expression $expression
    
}
catch [System.Management.Automation.PSSecurityException] {
    Show-ExecutionPolicyHelp
    
    # Offer to run with bypass if user wants
    Write-Host ""
    $response = Read-Host "Would you like to run with ExecutionPolicy Bypass this time? (y/N)"
    
    if ($response -match '^[Yy]') {
        Write-Host "Running with ExecutionPolicy Bypass..." -ForegroundColor Green
        try {
            $bypassExpression = "PowerShell -ExecutionPolicy Bypass -File `"$uberpingScript`" $($Arguments -join ' ')"
            Invoke-Expression $bypassExpression
        }
        catch {
            Write-Host "Failed to run with bypass: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
}
catch {
    Write-Host "An unexpected error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Error Type: $($_.Exception.GetType().Name)" -ForegroundColor Gray
}
