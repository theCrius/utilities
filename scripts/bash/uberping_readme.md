# UberPing - Advanced Network Connectivity Monitor (Bash Version)

## Overview

UberPing for Bash is a Linux/macOS compatible network monitoring tool that performs continuous ping operations with advanced analytics, logging, and anomaly detection. It provides the same powerful features as the PowerShell version but designed for Unix-like systems.

## What It Does

- **Continuous Network Monitoring**: Performs repeated ping operations to monitor network connectivity
- **Advanced Analytics**: Calculates response time statistics including min, max, average, and jitter analysis  
- **Adaptive Spike Detection**: Identifies and logs response times that exceed dynamically calculated thresholds
- **Comprehensive Logging**: Creates timestamped log files with detailed session information
- **Colored Console Output**: Provides color-coded console output for immediate status visibility
- **Cross-Platform**: Works on Linux, macOS, and other Unix-like systems
- **Signal Handling**: Graceful shutdown with Ctrl+C and proper cleanup

## Requirements

- Bash 4.0+ (for associative arrays)
- `ping` command (standard on most Unix systems)
- `bc` command (for floating-point calculations)
- `date` command with GNU or BSD date features

### Installing Requirements

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install bc
```

**CentOS/RHEL/Fedora:**
```bash
sudo yum install bc  # CentOS/RHEL
sudo dnf install bc  # Fedora
```

**macOS:**
```bash
# bc is usually pre-installed
# If not, install via Homebrew:
brew install bc
```

## Usage

### Basic Syntax

```bash
./uberping.sh -d <destination> [options]
```

### Parameters

| Parameter | Short | Long | Required | Default | Description |
|-----------|-------|------|----------|---------|-------------|
| Destination | `-d` | `--destination` | Yes | - | Target hostname or IP address |
| Time Limit | `-t` | `--time-limit` | No | 0 | Time limit in seconds (0 = continuous) |
| Log File | `-l` | `--log-file` | No | Auto-generated | Custom log file path |
| Interval | `-i` | `--interval` | No | 1000 | Ping interval in milliseconds |
| Spike Multiplier | `-s` | `--spike-multiplier` | No | 200 | Adaptive spike detection multiplier (200 = 200%) |
| Debug Mode | | `--debug` | No | False | Show debugging information and internal calculations |
| Help | `-h` | `--help` | No | - | Show help message |

## Examples

### Basic Continuous Monitoring

Monitor Google DNS continuously with default settings:

```bash
./uberping.sh -d 8.8.8.8
```

**Output:**
```
Starting ping to 8.8.8.8
Log file: /home/user/scripts/uberping_logs/uberping_log_20250922_143832.txt
Running continuously (Press Ctrl+C to stop)
Ping interval: 1000ms
Adaptive spike detection: 200% multiplier (initial threshold: 20ms)
----------------------------------------
2025-09-22 14:38:32 - PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
2025-09-22 14:38:32 - 64 bytes from 8.8.8.8: icmp_seq=1 ttl=116 time=12.3 ms
2025-09-22 14:38:33 - 64 bytes from 8.8.8.8: icmp_seq=1 ttl=116 time=11.8 ms
```

### Time-Limited Monitoring

Run for 60 seconds with custom intervals:

```bash
./uberping.sh -d google.com -t 60 -i 2000
```

### High-Sensitivity Adaptive Spike Detection

Monitor with lower multiplier for detecting minor performance issues:

```bash
./uberping.sh -d 192.168.1.1 -s 150 -t 300
```

### Custom Log File

Specify a custom log file location:

```bash
./uberping.sh -d cloudflare.com -l /var/log/network_monitor.log
```

### Rapid Monitoring with Debug Mode

High-frequency monitoring with detailed analysis:

```bash
./uberping.sh -d 8.8.4.4 -i 500 -t 120 --debug
```

### Network Quality Analysis

Monitor with very sensitive spike detection:

```bash
./uberping.sh -d 8.8.8.8 --debug -s 110 -t 45
```

## Sample Output

### Console Output
```bash
Starting ping to 8.8.8.8
Log file: /home/user/uberping_logs/uberping_log_20250922_143832.txt
Time limit: 30 seconds
Ping interval: 1000ms
Adaptive spike detection: 200% multiplier (initial threshold: 20ms)
----------------------------------------
2025-09-22 14:38:32 - 64 bytes from 8.8.8.8: icmp_seq=1 ttl=116 time=12.3 ms
2025-09-22 14:38:33 - 64 bytes from 8.8.8.8: icmp_seq=1 ttl=116 time=11.8 ms
2025-09-22 14:38:34 - 64 bytes from 8.8.8.8: icmp_seq=1 ttl=116 time=156.2 ms [SPIKE]

----------------------------------------
Ping Statistics Summary:
Total pings sent: 30
Successful pings: 29
Failed pings: 1
Success rate: 96.67%
Response time - Min: 9ms, Max: 156ms, Avg: 15ms
Jitter (std dev): 12ms - High jitter
Total runtime: 30 seconds
----------------------------------------
Anomalous Spikes (adaptive threshold: 38ms @ 200%):
1 - 2025-09-22 14:38:34 - 64 bytes from 8.8.8.8: icmp_seq=1 ttl=116 time=156.2 ms
Log saved to: /home/user/uberping_logs/uberping_log_20250922_143832.txt
```

### Debug Mode Output

When using `--debug`, you'll see additional information about the adaptive threshold calculations:

```bash
Adaptive threshold updated: 128ms (after 30 pings)
  → Trimmed mean: 58ms, Jitter: 58ms, Baseline: 116ms
  → Pre-constraint: 128ms, Final: 128ms

Adaptive threshold updated: 108ms (after 40 pings)
  → Trimmed mean: 45ms, Jitter: 52ms, Baseline: 97ms
  → Pre-constraint: 107ms, Final: 108ms
```

## Features

- **Cross-Platform Compatibility**: Works on Linux, macOS, and Unix-like systems
- **Adaptive Spike Detection**: Intelligent threshold calculation based on network conditions
- **Colored Output**: Visual indicators using ANSI color codes
- **Signal Handling**: Proper cleanup on Ctrl+C interruption
- **Automatic Logging**: Timestamped log files with session summaries
- **Statistics Engine**: Comprehensive network performance analytics
- **Flexible Timing**: Customizable ping intervals and session duration
- **Error Handling**: Graceful handling of network failures and command errors

## Algorithm Details

### Adaptive Spike Detection

The bash version uses the same sophisticated algorithm as the PowerShell version:

1. **Baseline Calculation**: Uses trimmed mean (removes top/bottom 15% outliers)
2. **Jitter Analysis**: Calculates standard deviation of trimmed dataset
3. **Dynamic Threshold**: `threshold = (trimmed_mean + trimmed_jitter) × multiplier_percentage`
4. **Constraints**: Minimum 20ms, maximum 500ms threshold
5. **Activation**: Requires minimum 15 samples before adaptive detection begins

### Statistics Calculation

- **Response Time Analysis**: Min, max, average calculations
- **Jitter Assessment**: Standard deviation with quality categorization
  - Low jitter: ≤ 2ms
  - Moderate jitter: 2-10ms  
  - High jitter: > 10ms
- **Success Rate**: Percentage of successful vs failed pings
- **Runtime Tracking**: Total session duration

## Installation and Setup

### Make Script Executable

```bash
chmod +x uberping.sh
```

### Optional: Add to PATH

```bash
# Copy to a directory in your PATH
sudo cp uberping.sh /usr/local/bin/uberping
sudo chmod +x /usr/local/bin/uberping

# Then run from anywhere:
uberping -d 8.8.8.8 -t 60
```

### Create Alias

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
alias uberping='/path/to/uberping.sh'
```

## Use Cases

### Network Troubleshooting
```bash
./uberping.sh -d problematic-server.com -t 3600 -s 180
```

### Baseline Performance Measurement
```bash
./uberping.sh -d 8.8.8.8 -t 300 -i 1000 -l baseline_measurement.log
```

### Real-time Network Quality Monitoring
```bash
./uberping.sh -d critical-service.internal -i 500 -s 150
```

### Automated Monitoring with Cron
```bash
# Add to crontab for hourly network checks
0 * * * * /path/to/uberping.sh -d 8.8.8.8 -t 300 -l /var/log/hourly_ping.log
```

## Platform-Specific Notes

### Linux
- Uses standard GNU `ping` command
- Timeout specified with `-W` flag in seconds
- Log files created in script directory by default

### macOS
- Uses BSD `ping` command
- Timeout specified with `-W` flag in milliseconds
- May require different ping syntax adjustments

### WSL (Windows Subsystem for Linux)
- Works with standard Linux ping command
- Ensure `bc` is installed: `sudo apt install bc`

## Troubleshooting

### Common Issues

1. **Permission Denied**: Make script executable with `chmod +x uberping.sh`
2. **bc: command not found**: Install bc package for your distribution
3. **Ping not found**: Ensure ping is installed and in PATH
4. **Log file permissions**: Check write permissions for log directory

### Debug Mode

Use `--debug` flag to see:
- Adaptive threshold calculations
- Internal algorithm decisions
- Trimmed statistics computation
- Threshold constraint applications

### Verbose Ping Output

For more detailed ping information, you can modify the ping command in the script to include additional flags like `-v` for verbose mode.

## Differences from PowerShell Version

### Similarities
- Same adaptive spike detection algorithm
- Identical statistics calculations
- Similar output formatting and logging
- Equivalent command-line interface design

### Bash-Specific Features
- POSIX-compliant signal handling
- ANSI color code output
- Unix-style command-line argument parsing
- Cross-platform ping command handling

### Performance Considerations
- Bash arrays for data storage
- External `bc` for floating-point math
- Platform-specific ping command variations
- Signal-based cleanup handling

## Contributing

This bash version maintains feature parity with the PowerShell version. When adding features:

1. Test on both Linux and macOS
2. Ensure POSIX compliance where possible
3. Handle platform-specific ping command differences
4. Maintain color output compatibility
5. Update both documentation versions

## License

Same license as the main utilities repository.
