# SuperPing - Advanced Network Connectivity Monitor

## Overview

SuperPing is a PowerShell-based network monitoring tool that performs continuous ping operations with advanced analytics, logging, and anomaly detection. It's designed to help network administrators and IT professionals monitor network connectivity, identify performance issues, and analyze network stability over time.

## What It Does

- **Continuous Network Monitoring**: Performs repeated ping operations to monitor network connectivity
- **Advanced Analytics**: Calculates response time statistics including min, max, average, and jitter analysis
- **Spike Detection**: Identifies and logs response times that exceed configurable thresholds
- **Comprehensive Logging**: Creates timestamped log files with detailed session information
- **Real-time Feedback**: Provides color-coded console output for immediate status visibility
- **Flexible Configuration**: Supports various timing, logging, and threshold configurations

## Inner Workings

##### Core Components

1. **Ping Engine**: Uses native Windows `ping` command for accurate timing measurements
2. **Response Parser**: Regex-based parsing to extract timing and status information from ping output
3. **Statistics Calculator**: Computes jitter (standard deviation) and quality assessments
4. **Logging System**: Timestamped file logging with automatic directory creation
5. **Adaptive Anomaly Detector**: Intelligently identifies spikes using baseline calculations and configurable multipliers

### Data Processing Flow

```
[Target Host] → [Native Ping] → [Response Parser] → [Statistics Engine] → [Console + Log Output]
                                                  ↓
                                            [Spike Detector] → [Anomaly Log]
```

### Key Algorithms

- **Jitter Calculation**: Standard deviation of response times
- **Quality Assessment**: 
  - Low jitter: ≤ 2ms
  - Moderate jitter: 2-10ms  
  - High jitter: > 10ms
- **Adaptive Spike Detection**: 
  - Calculates trimmed mean (removing top/bottom 15% outliers)
  - Computes baseline = trimmed_mean + trimmed_jitter
  - Spike threshold = baseline × multiplier_percentage
  - Requires minimum 15 samples before activation
  - Constraints: 20ms minimum, 500ms maximum threshold

## Usage

### Basic Syntax

```powershell
.\superping.ps1 -Destination <target> [parameters]
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `Destination` | String | Yes | - | Target hostname or IP address |
| `TimeLimit` | Integer | No | 0 | Time limit in seconds (0 = continuous) |
| `LogFile` | String | No | Auto-generated | Custom log file path |
| `Interval` | Integer | No | 1000 | Ping interval in milliseconds |
| `SpikeMultiplier` | Integer | No | 200 | Adaptive spike detection multiplier (200 = 200%) |
| `DebugMode` | Switch | No | False | Show additional debugging information and internal calculations |

## Examples

### Basic Continuous Monitoring

Monitor Google DNS continuously with default settings:

```powershell
.\superping.ps1 -Destination "8.8.8.8"
```

**Output:**
```
Starting ping to 8.8.8.8
Log file: C:\Scripts\superping_logs\ping_log_20250922_143832.txt
Running continuously (Press Ctrl+C to stop)
Ping interval: 1000ms
Spike threshold: 100ms
----------------------------------------
2025-09-22 14.38.32 - Reply from 8.8.8.8: bytes=32 time=12ms TTL=116
2025-09-22 14.38.33 - Reply from 8.8.8.8: bytes=32 time=11ms TTL=116
```

### Time-Limited Monitoring

Run for 60 seconds with custom intervals:

```powershell
.\superping.ps1 -Destination "google.com" -TimeLimit 60 -Interval 2000
```

### High-Sensitivity Adaptive Spike Detection

Monitor with lower multiplier for detecting minor performance issues:

```powershell
.\superping.ps1 -Destination "192.168.1.1" -SpikeMultiplier 150 -TimeLimit 300
```

### Custom Log File

Specify a custom log file location:

```powershell
.\superping.ps1 -Destination "cloudflare.com" -LogFile "C:\Logs\network_monitor.log"
```

### Rapid Monitoring

High-frequency monitoring for detailed analysis:

```powershell
.\superping.ps1 -Destination "8.8.4.4" -Interval 500 -TimeLimit 120
```

### Debug Mode

View detailed internal calculations and debugging information:

```powershell
.\superping.ps1 -Destination "8.8.8.8" -DebugMode -TimeLimit 60
```

### High-Sensitivity Network Quality Analysis

Monitor with very sensitive spike detection to catch network congestion:

```powershell
.\superping.ps1 -Destination "8.8.8.8" -DebugMode -SpikeMultiplier 110 -TimeLimit 45
```

## Sample Output

### Console Output
```
Starting ping to 8.8.8.8
Log file: C:\Scripts\superping_logs\ping_log_20250922_143832.txt
Time limit: 30 seconds
Ping interval: 1000ms
Adaptive spike detection: 200% multiplier (initial threshold: 50ms)
----------------------------------------
2025-09-22 14.38.32 - Reply from 8.8.8.8: bytes=32 time=12ms TTL=116
2025-09-22 14.38.33 - Reply from 8.8.8.8: bytes=32 time=11ms TTL=116
2025-09-22 14.38.34 - Reply from 8.8.8.8: bytes=32 time=150ms TTL=116

----------------------------------------
Ping Statistics Summary:
Total pings sent: 30
Successful pings: 29
Failed pings: 1
Success rate: 96.67%
Response time - Min: 9ms, Max: 150ms, Avg: 15.2ms
Jitter (std dev): 12.5ms - High jitter
Total runtime: 30.15 seconds
----------------------------------------
Anomalous Spikes (adaptive threshold: 38ms @ 200%):
1 - 2025-09-22 14.38.34 - Reply from 8.8.8.8: bytes=32 time=150ms TTL=116
Log saved to: C:\Scripts\superping_logs\ping_log_20250922_143832.txt
```

### Log File Content
```
2025-09-22 14.38.32 - Ping session started - Target: 8.8.8.8, Adaptive spike detection: 200% multiplier
2025-09-22 14.38.32 - Reply from 8.8.8.8: bytes=32 time=12ms TTL=116
2025-09-22 14.38.33 - Reply from 8.8.8.8: bytes=32 time=11ms TTL=116
...
2025-09-22 14.39.02 - === PING SESSION SUMMARY ===
2025-09-22 14.39.02 - Total pings sent: 30
2025-09-22 14.39.02 - Successful pings: 29
2025-09-22 14.39.02 - Success rate: 96.67%
2025-09-22 14.39.02 - Response time - Min: 9ms, Max: 150ms, Avg: 15.2ms
2025-09-22 14.39.02 - Jitter (std dev): 12.5ms - High jitter
2025-09-22 14.39.02 - === ANOMALOUS SPIKES (adaptive threshold: 38ms @ 200%) ===
2025-09-22 14.39.02 - 1 - 2025-09-22 14.38.34 - Reply from 8.8.8.8: bytes=32 time=150ms TTL=116
2025-09-22 14.39.02 - Ping session ended
```

### Real-World Network Congestion Example

High-sensitivity monitoring during network activity (110% multiplier with debug mode):

**Command:**
```powershell
.\superping.ps1 -Destination "8.8.8.8" -DebugMode -SpikeMultiplier 110 -TimeLimit 45
```

**Sample Output:**
```
Starting ping to 8.8.8.8
Adaptive spike detection: 110% multiplier (initial threshold: 20ms)
----------------------------------------
2025-09-22 15.16.02 - Reply from 8.8.8.8: bytes=32 time=10ms TTL=116
2025-09-22 15.16.03 - Reply from 8.8.8.8: bytes=32 time=12ms TTL=116
...
2025-09-22 15.16.17 - Reply from 8.8.8.8: bytes=32 time=89ms TTL=116
2025-09-22 15.16.18 - Reply from 8.8.8.8: bytes=32 time=136ms TTL=116
2025-09-22 15.16.19 - Reply from 8.8.8.8: bytes=32 time=127ms TTL=116
...
2025-09-22 15.16.26 - Request timed out.
...
Adaptive threshold updated: 128ms (after 30 pings)
  → Trimmed mean: 58ms, Jitter: 58.7ms, Baseline: 116.7ms
  → Pre-constraint: 128.4ms, Final: 128ms
...
Adaptive threshold updated: 108ms (after 40 pings)
  → Trimmed mean: 45.4ms, Jitter: 52.4ms, Baseline: 97.9ms
  → Pre-constraint: 107.7ms, Final: 108ms
...
2025-09-22 15.16.47 - Time limit of 45 seconds reached. Stopping ping.

----------------------------------------
Ping Statistics Summary:
Total pings sent: 51
Successful pings: 50
Failed pings: 1
Success rate: 98.04%
Response time - Min: 9ms, Max: 163ms, Avg: 47.96ms
Jitter (std dev): 57.48ms - High jitter
Total runtime: 45.03 seconds
----------------------------------------
Anomalous Spikes (adaptive threshold: 108ms @ 110%):
1 - 2025-09-22 15.16.17 - Reply from 8.8.8.8: bytes=32 time=89ms TTL=116
2 - 2025-09-22 15.16.18 - Reply from 8.8.8.8: bytes=32 time=136ms TTL=116
3 - 2025-09-22 15.16.19 - Reply from 8.8.8.8: bytes=32 time=127ms TTL=116
...
14 - 2025-09-22 15.16.32 - Reply from 8.8.8.8: bytes=32 time=163ms TTL=116
Log saved to: C:\Users\Claudio\Downloads\superping_logs\ping_log_20250922_151602.txt
```

**Key Features Demonstrated:**
- **Adaptive threshold calculation** in real-time
- **Network congestion detection** (89-163ms spikes)
- **Packet loss tracking** (1 timeout)
- **Debug mode insights** showing algorithm internals
- **Dynamic threshold adjustment** (128ms → 108ms as network recovered)
- **Comprehensive spike logging** (14 anomalous events detected)

## Use Cases

### Network Troubleshooting
Monitor intermittent connectivity issues with adaptive detection:
```powershell
.\superping.ps1 -Destination "problematic-server.com" -TimeLimit 3600 -SpikeMultiplier 180
```

### Baseline Performance Measurement
Establish network performance baselines:
```powershell
.\superping.ps1 -Destination "8.8.8.8" -TimeLimit 300 -Interval 1000 -LogFile "baseline_measurement.log"
```

### Real-time Network Quality Monitoring
Monitor critical services during maintenance windows with high sensitivity:
```powershell
.\superping.ps1 -Destination "critical-service.internal" -Interval 500 -SpikeMultiplier 150
```

## Features

- **Cross-platform**: Works on Windows PowerShell and PowerShell Core
- **Auto-logging**: Automatic log file creation with timestamped entries
- **Adaptive spike detection**: Intelligent context-aware anomaly detection
- **Statistics**: Comprehensive network performance analytics
- **Color output**: Visual status indicators in console
- **Error handling**: Graceful handling of network failures and timeouts
- **Flexible timing**: Customizable ping intervals and session duration
- **Summary reports**: Detailed session summaries with jitter analysis

## Requirements

- Windows PowerShell 5.1+ or PowerShell Core 6.0+
- Network connectivity to target destination
- Write permissions for log file creation (if using auto-generated paths)

## Notes

- The script uses the native Windows `ping` command for accurate timing
- Log files are automatically created in a `superping_logs` directory relative to the script location
- Press `Ctrl+C` to stop continuous monitoring sessions
- All timestamps use the format: `yyyy-MM-dd HH.mm.ss`
- Jitter calculation uses standard deviation of response times

## Troubleshooting

### Common Issues

1. **"Destination parameter is required"**: Ensure you specify a target hostname or IP
2. **Log file permissions**: Verify write permissions for the log directory
3. **Network timeouts**: Check network connectivity to the target destination
4. **High jitter readings**: May indicate network congestion or unstable connections

### Getting Help

Run the script with invalid parameters to see the parameter help:
```powershell
Get-Help .\superping.ps1 -Full
```
