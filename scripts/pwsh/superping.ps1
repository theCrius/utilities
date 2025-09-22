# This is a script meant to ping something and show time when the ping was executed as well as write a log
# It's meant to run on powershell 7.1 but could work on previous versions as well, I simply didn't check
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Destination,
    
    [Parameter(Mandatory=$false)]
    [int]$TimeLimit = 0,  # 0 means continuous, any other value is time limit in seconds
    
    [Parameter(Mandatory=$false)]
    [string]$LogFile = "ping_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt",
    
    [Parameter(Mandatory=$false)]
    [int]$Interval = 1000  # Ping interval in milliseconds
)

# Function to write timestamped output
function Write-TimestampedOutput {
    param(
        [string]$Message,
        [string]$LogPath
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
    $output = "$timestamp - $Message"
    
    # Write to console
    Write-Host $output
    
    # Write to log file
    Add-Content -Path $LogPath -Value $output
}

# Validate destination
if (-not $Destination) {
    Write-Error "Destination parameter is required."
    exit 1
}

# Create log file directory if it doesn't exist
$logDir = Split-Path -Path $LogFile -Parent
if ($logDir -and -not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Initialize variables
$startTime = Get-Date
$pingCount = 0
$successCount = 0
$failCount = 0

Write-Host "Starting ping to $Destination" -ForegroundColor Green
Write-Host "Log file: $LogFile" -ForegroundColor Green
if ($TimeLimit -gt 0) {
    Write-Host "Time limit: $TimeLimit seconds" -ForegroundColor Green
} else {
    Write-Host "Running continuously (Press Ctrl+C to stop)" -ForegroundColor Green
}
Write-Host "Ping interval: $($Interval)ms" -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Green

# Initial log entry
Write-TimestampedOutput "Ping session started - Target: $Destination" $LogFile

try {
    while ($true) {
        # Check time limit
        if ($TimeLimit -gt 0) {
            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            if ($elapsed -ge $TimeLimit) {
                Write-TimestampedOutput "Time limit of $TimeLimit seconds reached. Stopping ping." $LogFile
                break
            }
        }
        
        $pingCount++
        
        try {
            # Perform ping using Test-Connection
            $pingResult = Test-Connection -ComputerName $Destination -Count 1 -ErrorAction Stop
            
            # Extract relevant information
            $responseTime = [math]::Round($pingResult.ResponseTime, 0)
            $address = $pingResult.Address
            
            # Format the output similar to traditional ping
            $message = "Reply from ${address}: bytes=32 time=${responseTime}ms TTL=64"
            Write-TimestampedOutput $message $LogFile
            
            $successCount++
        }
        catch {
            # Handle ping failure
            $message = "Request timed out or destination unreachable: $Destination"
            Write-TimestampedOutput $message $LogFile
            $failCount++
        }
        
        # Wait for the specified interval before next ping
        Start-Sleep -Milliseconds $Interval
    }
}
catch {
    Write-TimestampedOutput "Ping session interrupted: $($_.Exception.Message)" $LogFile
}
finally {
    # Summary statistics
    $endTime = Get-Date
    $totalTime = ($endTime - $startTime).TotalSeconds
    
    Write-Host "`n----------------------------------------" -ForegroundColor Green
    Write-Host "Ping Statistics Summary:" -ForegroundColor Green
    Write-Host "Total pings sent: $pingCount" -ForegroundColor White
    Write-Host "Successful pings: $successCount" -ForegroundColor Green
    Write-Host "Failed pings: $failCount" -ForegroundColor Red
    
    if ($pingCount -gt 0) {
        $successRate = [math]::Round(($successCount / $pingCount) * 100, 2)
        Write-Host "Success rate: $successRate%" -ForegroundColor White
    }
    
    Write-Host "Total runtime: $([math]::Round($totalTime, 2)) seconds" -ForegroundColor White
    Write-Host "Log saved to: $LogFile" -ForegroundColor Yellow
    
    # Write summary to log
    Write-TimestampedOutput "=== PING SESSION SUMMARY ===" $LogFile
    Write-TimestampedOutput "Total pings sent: $pingCount" $LogFile
    Write-TimestampedOutput "Successful pings: $successCount" $LogFile
    Write-TimestampedOutput "Failed pings: $failCount" $LogFile
    if ($pingCount -gt 0) {
        Write-TimestampedOutput "Success rate: $([math]::Round(($successCount / $pingCount) * 100, 2))%" $LogFile
    }
    Write-TimestampedOutput "Total runtime: $([math]::Round($totalTime, 2)) seconds" $LogFile
    Write-TimestampedOutput "Ping session ended" $LogFile
}
