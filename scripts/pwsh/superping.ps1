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
    [int]$SpikeMultiplier = 200,  # Percentage multiplier for adaptive spike detection (200 = 200%)
    
    [Parameter(Mandatory = $false)]
    [switch]$DebugMode = $false  # Show detailed additional debugging information and internal calculations
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
        # Use script-level variables to get the actual script name, not function name
        $scriptName = if ($PSCommandPath) {
            [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
        }
        elseif ($MyInvocation.ScriptName) {
            [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.ScriptName)
        }
        else { 
            "logs" 
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

# Function to calculate trimmed mean (removing outliers)
function Get-TrimmedMean {
    param([array]$Values, [double]$TrimPercentage = 0.15)
    
    if ($Values.Count -eq 0) { return 0 }
    if ($Values.Count -le 4) { return ($Values | Measure-Object -Average).Average }
    
    # Sort values and calculate trim indices
    $sortedValues = $Values | Sort-Object
    $trimCount = [math]::Floor($sortedValues.Count * $TrimPercentage)
    
    # Remove outliers from both ends
    $trimmedValues = $sortedValues[$trimCount..($sortedValues.Count - 1 - $trimCount)]
    
    return ($trimmedValues | Measure-Object -Average).Average
}

# Function to calculate adaptive spike threshold
function Get-AdaptiveSpikeThreshold {
    param(
        [array]$ResponseTimes,
        [int]$Multiplier = 200,
        [int]$MinThreshold = 20,
        [int]$MaxThreshold = 500
    )
    
    if ($ResponseTimes.Count -lt 15) {
        # Not enough data - use a reasonable default for desktop/laptop networks
        return 20
    }
    
    # Calculate trimmed mean (baseline response time without outliers)
    $trimmedMean = Get-TrimmedMean -Values $ResponseTimes
    
    # Calculate jitter of trimmed data
    $trimCount = [math]::Floor($ResponseTimes.Count * 0.15)
    $sortedTimes = $ResponseTimes | Sort-Object
    $trimmedTimes = $sortedTimes[$trimCount..($sortedTimes.Count - 1 - $trimCount)]
    
    $jitterStats = Get-JitterStatistics -ResponseTimes $trimmedTimes
    $trimmedJitter = if ($jitterStats) { $jitterStats.Jitter } else { 0 }
    
    # Baseline = trimmed mean + trimmed jitter
    $baseline = $trimmedMean + $trimmedJitter
    
    # Adaptive threshold = baseline * multiplier percentage
    $adaptiveThreshold = $baseline * ($Multiplier / 100.0)
    
    # Apply min/max constraints
    $finalThreshold = [math]::Max($MinThreshold, [math]::Min($MaxThreshold, $adaptiveThreshold))
    
    return [math]::Round($finalThreshold, 0)
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
        [string]$LogPath,
        [int]$FinalSpikeThreshold,
        [int]$SpikeMultiplier
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
        Write-Host "Anomalous Spikes (adaptive threshold: ${FinalSpikeThreshold}ms @ ${SpikeMultiplier}%):" -ForegroundColor Yellow
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
        Write-TimestampedOutput "=== ANOMALOUS SPIKES (adaptive threshold: ${FinalSpikeThreshold}ms @ ${SpikeMultiplier}%) ===" $LogPath
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
$currentSpikeThreshold = 20  # Initial threshold before we have enough data (desktop/laptop networks)

Write-Host "Starting ping to $Destination" -ForegroundColor Green
Write-Host "Log file: $LogFile" -ForegroundColor Green
if ($TimeLimit -gt 0) {
    Write-Host "Time limit: $TimeLimit seconds" -ForegroundColor Green
}
else {
    Write-Host "Running continuously (Press Ctrl+C to stop)" -ForegroundColor Green
}
Write-Host "Ping interval: $($Interval)ms" -ForegroundColor Green
Write-Host "Adaptive spike detection: ${SpikeMultiplier}% multiplier (initial threshold: ${currentSpikeThreshold}ms)" -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Green

# Initial log entry
Write-TimestampedOutput "Ping session started - Target: $Destination, Adaptive spike detection: ${SpikeMultiplier}% multiplier" $LogFile

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
            # Store response time
            $responseTimes += $pingResult.Time
            
            # Update adaptive threshold every 10 successful pings
            if ($successCount -gt 0 -and $successCount % 10 -eq 0) {
                $newThreshold = Get-AdaptiveSpikeThreshold -ResponseTimes $responseTimes -Multiplier $SpikeMultiplier
                if ($newThreshold -ne $currentSpikeThreshold) {
                    $currentSpikeThreshold = $newThreshold
                    if ($DebugMode) {
                        # Calculate detailed breakdown for debug output
                        $debugTrimmedMean = Get-TrimmedMean -Values $responseTimes
                        $trimCount = [math]::Floor($responseTimes.Count * 0.15)
                        $sortedTimes = $responseTimes | Sort-Object
                        $trimmedTimes = $sortedTimes[$trimCount..($sortedTimes.Count - 1 - $trimCount)]
                        $jitterStats = Get-JitterStatistics -ResponseTimes $trimmedTimes
                        $debugJitter = if ($jitterStats) { $jitterStats.Jitter } else { 0 }
                        $debugBaseline = $debugTrimmedMean + $debugJitter
                        $debugPreConstraint = $debugBaseline * ($SpikeMultiplier / 100.0)
                        
                        $thresholdMessage = "Adaptive threshold updated: ${currentSpikeThreshold}ms (after $successCount pings)"
                        $detailMessage = "  → Trimmed mean: $([math]::Round($debugTrimmedMean, 1))ms, Jitter: $([math]::Round($debugJitter, 1))ms, Baseline: $([math]::Round($debugBaseline, 1))ms"
                        $calcMessage = "  → Pre-constraint: $([math]::Round($debugPreConstraint, 1))ms, Final: ${currentSpikeThreshold}ms"
                        
                        Write-Host $thresholdMessage -ForegroundColor Cyan
                        Write-Host $detailMessage -ForegroundColor DarkCyan
                        Write-Host $calcMessage -ForegroundColor DarkCyan
                        Write-TimestampedOutput $thresholdMessage $LogFile
                        Write-TimestampedOutput $detailMessage $LogFile
                        Write-TimestampedOutput $calcMessage $LogFile
                    }
                }
            }
            
            # Check for anomalous spikes using adaptive threshold
            if ($pingResult.Time -gt $currentSpikeThreshold) {
                $spikeEntry = @{
                    Timestamp    = Get-Date -Format "yyyy-MM-dd HH.mm.ss"
                    Message      = $pingResult.Message
                    ResponseTime = $pingResult.Time
                    Threshold    = $currentSpikeThreshold
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
    
    Write-SummaryStatistics -TotalPings $pingCount -SuccessfulPings $successCount -FailedPings $failCount -ResponseTimes $responseTimes -AnomalousSpikes $anomalousSpikes -TotalRuntime $totalTime -LogPath $LogFile -FinalSpikeThreshold $currentSpikeThreshold -SpikeMultiplier $SpikeMultiplier
}
