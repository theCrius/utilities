param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Destination,
    
    [Parameter(Mandatory=$false)]
    [int]$TimeLimit = 0,  # 0 means continuous, any other value is time limit in seconds
    
    [Parameter(Mandatory=$false)]
    [string]$LogFile = "",
    
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

# Set default log file path if not provided
if ([string]::IsNullOrEmpty($LogFile)) {
    # Get the directory where the script is located
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    # Create the logs folder name based on script name
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
    $logsFolder = "${scriptName}_logs"
    $logDir = Join-Path -Path $scriptDir -ChildPath $logsFolder
    
    # Create the logs directory if it doesn't exist
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    # Set the log file path
    $LogFile = Join-Path -Path $logDir -ChildPath "ping_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
}

# Create log file directory if it doesn't exist (for custom paths)
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
            # Use native ping command for accurate timing
            $pingOutput = ping $Destination -n 1 -w 1000
            
            # Parse the ping output to extract timing information
            $replyLine = $pingOutput | Where-Object { $_ -match "Reply from" }
            
            if ($replyLine) {
                # Extract the relevant information from the ping output
                if ($replyLine -match "Reply from ([\d\.]+|[^:]+): bytes=(\d+) time[<=](\d+)ms TTL=(\d+)") {
                    $address = $matches[1]
                    $bytes = $matches[2]
                    $time = $matches[3]
                    $ttl = $matches[4]
                    
                    $message = "Reply from ${address}: bytes=${bytes} time=${time}ms TTL=${ttl}"
                } elseif ($replyLine -match "Reply from ([\d\.]+|[^:]+): bytes=(\d+) time<(\d+)ms TTL=(\d+)") {
                    $address = $matches[1]
                    $bytes = $matches[2]
                    $time = "<" + $matches[3]
                    $ttl = $matches[4]
                    
                    $message = "Reply from ${address}: bytes=${bytes} time=${time}ms TTL=${ttl}"
                } else {
                    # Fallback - just use the original line
                    $message = $replyLine.Trim()
                }
                
                Write-TimestampedOutput $message $LogFile
                $successCount++
            } else {
                # Check for timeout or unreachable messages
                $timeoutLine = $pingOutput | Where-Object { $_ -match "Request timed out|Destination host unreachable|could not find host" }
                if ($timeoutLine) {
                    $message = $timeoutLine.Trim()
                } else {
                    $message = "Request timed out or destination unreachable: $Destination"
                }
                Write-TimestampedOutput $message $LogFile
                $failCount++
            }
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
