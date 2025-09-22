param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Destination,
    
    [Parameter(Mandatory = $false)]
    [int]$TimeLimit = 0,  # 0 means continuous, any other value is time limit in seconds
    
    [Parameter(Mandatory = $false)]
    [string]$LogFile = "",
    
    [Parameter(Mandatory = $false)]
    [int]$Interval = 1000,  # Ping interval in milliseconds
    
    [Parameter(Mandatory = $false)]
    [int]$SpikeThreshold = 100  # Response time in ms that constitutes a spike
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
    
    # Write to log file only if LogPath is valid
    if (-not [string]::IsNullOrEmpty($LogPath)) {
        try {
            Add-Content -Path $LogPath -Value $output -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
}

# Function to initialize log file path
function Initialize-LogPath {
    param([string]$CustomLogFile)
    
    if ([string]::IsNullOrEmpty($CustomLogFile)) {
        # Get the directory where the script is located
        $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
        
        # Fallback to current directory if script directory cannot be determined
        if ([string]::IsNullOrEmpty($scriptDir)) {
            $scriptDir = Get-Location
        }
        
        # Create the logs folder name based on script name
        $scriptName = if ($MyInvocation.MyCommand.Name) { 
            [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name) 
        }
        elseif ($PSCommandPath) {
            [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
        }
        else { 
            "superping" 
        }
        $logsFolder = "${scriptName}_logs"
        $logDir = Join-Path -Path $scriptDir -ChildPath $logsFolder
        
        # Create the logs directory if it doesn't exist
        if (-not (Test-Path -Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        # Set the log file path
        return Join-Path -Path $logDir -ChildPath "ping_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    }
    else {
        # Create log file directory if it doesn't exist (for custom paths)
        $logDir = Split-Path -Path $CustomLogFile -Parent
        if ($logDir -and -not (Test-Path -Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        return $CustomLogFile
    }
}

# Function to perform a single ping and return results
function Invoke-SinglePing {
    param(
        [string]$Target,
        [int]$Timeout = 1000
    )
    
    try {
        # Use native ping command for accurate timing
        $pingOutput = ping $Target -n 1 -w $Timeout
        
        # Parse the ping output to extract timing information
        $replyLine = $pingOutput | Where-Object { $_ -match "Reply from" }
        
        if ($replyLine) {
            # Extract the relevant information from the ping output
            if ($replyLine -match "Reply from ([\d\.]+|[^:]+): bytes=(\d+) time[<=](\d+)ms TTL=(\d+)") {
                return @{
                    Success = $true
                    Address = $matches[1]
                    Bytes   = $matches[2]
                    Time    = [int]$matches[3]
                    TTL     = $matches[4]
                    Message = "Reply from $($matches[1]): bytes=$($matches[2]) time=$($matches[3])ms TTL=$($matches[4])"
                }
            }
            elseif ($replyLine -match "Reply from ([\d\.]+|[^:]+): bytes=(\d+) time<(\d+)ms TTL=(\d+)") {
                return @{
                    Success = $true
                    Address = $matches[1]
                    Bytes   = $matches[2]
                    Time    = 0  # Sub-millisecond response
                    TTL     = $matches[4]
                    Message = "Reply from $($matches[1]): bytes=$($matches[2]) time<$($matches[3])ms TTL=$($matches[4])"
                }
            }
            else {
                # Fallback - just use the original line
                return @{
                    Success = $true
                    Address = "Unknown"
                    Bytes   = 32
                    Time    = 0
                    TTL     = 64
                    Message = $replyLine.Trim()
                }
            }
        }
        else {
            # Check for timeout or unreachable messages
            $timeoutLine = $pingOutput | Where-Object { $_ -match "Request timed out|Destination host unreachable|could not find host" }
            $message = if ($timeoutLine) { $timeoutLine.Trim() } else { "Request timed out or destination unreachable: $Target" }
            
            return @{
                Success = $false
                Message = $message
            }
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Ping error: $($_.Exception.Message)"
        }
    }
}

# Function to calculate jitter statistics
function Get-JitterStatistics {
    param([array]$ResponseTimes)
    
    if ($ResponseTimes.Count -le 1) {
        return $null
    }
    
    $minTime = ($ResponseTimes | Measure-Object -Minimum).Minimum
    $maxTime = ($ResponseTimes | Measure-Object -Maximum).Maximum
    $avgTime = [math]::Round(($ResponseTimes | Measure-Object -Average).Average, 2)
    
    # Calculate jitter (standard deviation of response times)
    $variance = 0
    foreach ($time in $ResponseTimes) {
        $variance += [math]::Pow(($time - $avgTime), 2)
    }
    $jitter = [math]::Round([math]::Sqrt($variance / $ResponseTimes.Count), 2)
    
    # Determine jitter quality
    $jitterQuality = if ($jitter -le 2) { "Low jitter" } 
    elseif ($jitter -le 10) { "Moderate jitter" } 
    else { "High jitter" }
    
    return @{
        Min     = $minTime
        Max     = $maxTime
        Average = $avgTime
        Jitter  = $jitter
        Quality = $jitterQuality
    }
}

# Function to display and log summary statistics
function Write-SummaryStatistics {
    param(
        [int]$TotalPings,
        [int]$SuccessfulPings,
        [int]$FailedPings,
        [array]$ResponseTimes,
        [array]$AnomalousSpikes,
        [double]$TotalRuntime,
        [string]$LogPath
    )
    
    Write-Host "`n----------------------------------------" -ForegroundColor Green
    Write-Host "Ping Statistics Summary:" -ForegroundColor Green
    Write-Host "Total pings sent: $TotalPings" -ForegroundColor White
    Write-Host "Successful pings: $SuccessfulPings" -ForegroundColor Green
    Write-Host "Failed pings: $FailedPings" -ForegroundColor Red
    
    if ($TotalPings -gt 0) {
        $successRate = [math]::Round(($SuccessfulPings / $TotalPings) * 100, 2)
        Write-Host "Success rate: $successRate%" -ForegroundColor White
    }
    
    # Display jitter statistics
    $jitterStats = Get-JitterStatistics -ResponseTimes $ResponseTimes
    if ($jitterStats) {
        Write-Host "Response time - Min: $($jitterStats.Min)ms, Max: $($jitterStats.Max)ms, Avg: $($jitterStats.Average)ms" -ForegroundColor Cyan
        Write-Host "Jitter (std dev): $($jitterStats.Jitter)ms - $($jitterStats.Quality)" -ForegroundColor Cyan
    }
    elseif ($ResponseTimes.Count -eq 1) {
        Write-Host "Response time - Single ping: $($ResponseTimes[0])ms" -ForegroundColor Cyan
        Write-Host "Jitter: N/A (insufficient data)" -ForegroundColor Cyan
    }
    
    Write-Host "Total runtime: $([math]::Round($TotalRuntime, 2)) seconds" -ForegroundColor White
    
    # Display anomalous spikes
    if ($AnomalousSpikes.Count -gt 0) {
        Write-Host "----------------------------------------" -ForegroundColor Yellow
        Write-Host "Anomalous Spikes (>${script:SpikeThreshold}ms):" -ForegroundColor Yellow
        for ($i = 0; $i -lt $AnomalousSpikes.Count; $i++) {
            $spike = $AnomalousSpikes[$i]
            Write-Host "$($i + 1) - $($spike.Timestamp) - $($spike.Message)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "Log saved to: $LogPath" -ForegroundColor White
    
    # Write summary to log
    Write-TimestampedOutput "=== PING SESSION SUMMARY ===" $LogPath
    Write-TimestampedOutput "Total pings sent: $TotalPings" $LogPath
    Write-TimestampedOutput "Successful pings: $SuccessfulPings" $LogPath
    Write-TimestampedOutput "Failed pings: $FailedPings" $LogPath
    if ($TotalPings -gt 0) {
        Write-TimestampedOutput "Success rate: $([math]::Round(($SuccessfulPings / $TotalPings) * 100, 2))%" $LogPath
    }
    
    # Add jitter statistics to log
    if ($jitterStats) {
        Write-TimestampedOutput "Response time - Min: $($jitterStats.Min)ms, Max: $($jitterStats.Max)ms, Avg: $($jitterStats.Average)ms" $LogPath
        Write-TimestampedOutput "Jitter (std dev): $($jitterStats.Jitter)ms - $($jitterStats.Quality)" $LogPath
    }
    elseif ($ResponseTimes.Count -eq 1) {
        Write-TimestampedOutput "Response time - Single ping: $($ResponseTimes[0])ms" $LogPath
        Write-TimestampedOutput "Jitter: N/A (insufficient data)" $LogPath
    }
    
    # Log anomalous spikes
    if ($AnomalousSpikes.Count -gt 0) {
        Write-TimestampedOutput "=== ANOMALOUS SPIKES (>${script:SpikeThreshold}ms) ===" $LogPath
        for ($i = 0; $i -lt $AnomalousSpikes.Count; $i++) {
            $spike = $AnomalousSpikes[$i]
            Write-TimestampedOutput "$($i + 1) - $($spike.Timestamp) - $($spike.Message)" $LogPath
        }
    }
    
    Write-TimestampedOutput "Total runtime: $([math]::Round($TotalRuntime, 2)) seconds" $LogPath
    Write-TimestampedOutput "Ping session ended" $LogPath
}

# Main execution starts here
# Validate destination
if (-not $Destination) {
    Write-Error "Destination parameter is required."
    exit 1
}

# Initialize log file path
$LogFile = Initialize-LogPath -CustomLogFile $LogFile

# Initialize variables
$startTime = Get-Date
$pingCount = 0
$successCount = 0
$failCount = 0
$responseTimes = @()
$anomalousSpikes = @()

Write-Host "Starting ping to $Destination" -ForegroundColor Green
Write-Host "Log file: $LogFile" -ForegroundColor Green
if ($TimeLimit -gt 0) {
    Write-Host "Time limit: $TimeLimit seconds" -ForegroundColor Green
}
else {
    Write-Host "Running continuously (Press Ctrl+C to stop)" -ForegroundColor Green
}
Write-Host "Ping interval: $($Interval)ms" -ForegroundColor Green
Write-Host "Spike threshold: ${SpikeThreshold}ms" -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Green

# Initial log entry
Write-TimestampedOutput "Ping session started - Target: $Destination, Spike threshold: ${SpikeThreshold}ms" $LogFile

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
        
        # Perform ping
        $pingResult = Invoke-SinglePing -Target $Destination -Timeout 1000
        
        if ($pingResult.Success) {
            # Store response time and check for spikes
            $responseTimes += $pingResult.Time
            
            # Check for anomalous spikes
            if ($pingResult.Time -gt $SpikeThreshold) {
                $spikeEntry = @{
                    Timestamp    = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
                    Message      = $pingResult.Message
                    ResponseTime = $pingResult.Time
                }
                $anomalousSpikes += $spikeEntry
            }
            
            Write-TimestampedOutput $pingResult.Message $LogFile
            $successCount++
        }
        else {
            Write-TimestampedOutput $pingResult.Message $LogFile
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
    # Calculate total runtime and display summary
    $endTime = Get-Date
    $totalTime = ($endTime - $startTime).TotalSeconds
    
    Write-SummaryStatistics -TotalPings $pingCount -SuccessfulPings $successCount -FailedPings $failCount -ResponseTimes $responseTimes -AnomalousSpikes $anomalousSpikes -TotalRuntime $totalTime -LogPath $LogFile
}
