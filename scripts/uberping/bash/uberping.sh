#!/bin/bash

# UberPing - Advanced Network Connectivity Monitor (Bash Version)
# A bash-based network monitoring tool with advanced analytics and adaptive spike detection

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v ping >/dev/null 2>&1; then
        missing_deps+=("ping")
    fi
    
    if ! command -v bc >/dev/null 2>&1; then
        missing_deps+=("bc")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "\033[0;31mError: Missing required dependencies: ${missing_deps[*]}\033[0m" >&2
        echo -e "\033[1;33mInstall them using:\033[0m" >&2
        echo "  Ubuntu/Debian: sudo apt-get install ${missing_deps[*]}" >&2
        echo "  CentOS/RHEL:   sudo yum install ${missing_deps[*]}" >&2
        echo "  Alpine:        sudo apk add ${missing_deps[*]}" >&2
        echo "  macOS:         brew install ${missing_deps[*]}" >&2
        exit 1
    fi
}

# Check dependencies before proceeding
check_dependencies

# Default values
DESTINATION=""
TIME_LIMIT=0
LOG_FILE=""
INTERVAL=1000
SPIKE_MULTIPLIER=200
DEBUG_MODE=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Arrays to store ping data
declare -a response_times=()
declare -a successful_pings=()
declare -a spike_entries=()

# Statistics variables
total_pings=0
successful_count=0
failed_count=0
min_time=999999
max_time=0
total_time=0
start_time=""
adaptive_threshold=20

# Function to display usage
show_help() {
    echo "UberPing - Advanced Network Connectivity Monitor (Bash Version)"
    echo ""
    echo "Usage: $0 -d <destination> [options]"
    echo ""
    echo "Required:"
    echo "  -d, --destination <target>     Target hostname or IP address"
    echo ""
    echo "Optional:"
    echo "  -t, --time-limit <seconds>     Time limit in seconds (0 = continuous, default: 0)"
    echo "  -l, --log-file <path>          Custom log file path (default: auto-generated)"
    echo "  -i, --interval <ms>            Ping interval in milliseconds (default: 1000)"
    echo "  -s, --spike-multiplier <pct>   Adaptive spike detection multiplier (default: 200)"
    echo "  --debug                        Show debugging information"
    echo "  -h, --help                     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -d 8.8.8.8"
    echo "  $0 -d google.com -t 60 -i 2000"
    echo "  $0 -d 192.168.1.1 -s 150 -t 300 --debug"
    echo "  $0 -d cloudflare.com -l /var/log/network_monitor.log"
}

# Function to write timestamped output
write_timestamped_output() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local output="$timestamp - $message"
    
    echo -e "$output"
    
    if [[ -n "$LOG_FILE" ]]; then
        echo "$output" >> "$LOG_FILE"
    fi
}

# Function to initialize log file path
initialize_log_path() {
    if [[ -z "$LOG_FILE" ]]; then
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        local script_name="$(basename "${BASH_SOURCE[0]}" .sh)"
        local logs_dir="${script_dir}/${script_name}_logs"
        
        # Create logs directory if it doesn't exist
        mkdir -p "$logs_dir"
        
        local timestamp=$(date "+%Y%m%d_%H%M%S")
        LOG_FILE="${logs_dir}/uberping_log_${timestamp}.txt"
    else
        # Create directory for custom log file if needed
        local log_dir=$(dirname "$LOG_FILE")
        mkdir -p "$log_dir" 2>/dev/null
    fi
}

# Function to perform a single ping
perform_ping() {
    local destination="$1"
    
    # Use ping command with timeout
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS ping syntax
        local ping_output=$(ping -c 1 -W 5000 "$destination" 2>&1)
    else
        # Linux ping syntax
        local ping_output=$(ping -c 1 -W 5 "$destination" 2>&1)
    fi
    
    local ping_exit_code=$?
    
    if [[ $ping_exit_code -eq 0 ]]; then
        # Extract the response line that contains timing information
        local response_line=$(echo "$ping_output" | grep -E "bytes from.*time=")
        
        if [[ "$response_line" =~ time=([0-9]+\.?[0-9]*) ]]; then
            local time_ms="${BASH_REMATCH[1]}"
            # Convert to integer milliseconds for easier processing
            time_ms=$(echo "$time_ms" | awk '{print int($1 + 0.5)}')
            echo "success:$time_ms:$response_line"
        else
            echo "parse_error:0:$ping_output"
        fi
    else
        echo "failure:0:Request timed out"
    fi
}

# Function to calculate statistics
calculate_statistics() {
    if [[ ${#response_times[@]} -eq 0 ]]; then
        return
    fi
    
    # Calculate min, max, average
    local sum=0
    min_time=${response_times[0]}
    max_time=${response_times[0]}
    
    for time in "${response_times[@]}"; do
        sum=$((sum + time))
        if [[ $time -lt $min_time ]]; then
            min_time=$time
        fi
        if [[ $time -gt $max_time ]]; then
            max_time=$time
        fi
    done
    
    local avg_time=$((sum / ${#response_times[@]}))
    
    # Calculate jitter (standard deviation)
    local variance_sum=0
    for time in "${response_times[@]}"; do
        local diff=$((time - avg_time))
        variance_sum=$((variance_sum + diff * diff))
    done
    
    local variance=$((variance_sum / ${#response_times[@]}))
    local jitter=$(echo "sqrt($variance)" | bc -l | awk '{print int($1 + 0.5)}')
    
    echo "$min_time:$max_time:$avg_time:$jitter"
}

# Function to update adaptive threshold
update_adaptive_threshold() {
    local count=${#response_times[@]}
    
    if [[ $count -lt 15 ]]; then
        return
    fi
    
    # Create sorted copy for trimmed mean calculation
    local sorted_times=($(printf '%s\n' "${response_times[@]}" | sort -n))
    
    # Calculate trimmed mean (remove top/bottom 15%)
    local trim_count=$((count * 15 / 100))
    local trimmed_start=$trim_count
    local trimmed_end=$((count - trim_count - 1))
    
    local trimmed_sum=0
    local trimmed_count=0
    
    for ((i=trimmed_start; i<=trimmed_end; i++)); do
        trimmed_sum=$((trimmed_sum + sorted_times[i]))
        ((trimmed_count++))
    done
    
    local trimmed_mean=$((trimmed_sum / trimmed_count))
    
    # Calculate trimmed jitter
    local trimmed_variance_sum=0
    for ((i=trimmed_start; i<=trimmed_end; i++)); do
        local diff=$((sorted_times[i] - trimmed_mean))
        trimmed_variance_sum=$((trimmed_variance_sum + diff * diff))
    done
    
    local trimmed_variance=$((trimmed_variance_sum / trimmed_count))
    local trimmed_jitter=$(echo "sqrt($trimmed_variance)" | bc -l | awk '{print int($1 + 0.5)}')
    
    # Calculate baseline and threshold
    local baseline=$((trimmed_mean + trimmed_jitter))
    local pre_constraint_threshold=$((baseline * SPIKE_MULTIPLIER / 100))
    
    # Apply constraints (20ms minimum, 500ms maximum)
    if [[ $pre_constraint_threshold -lt 20 ]]; then
        adaptive_threshold=20
    elif [[ $pre_constraint_threshold -gt 500 ]]; then
        adaptive_threshold=500
    else
        adaptive_threshold=$pre_constraint_threshold
    fi
    
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${CYAN}Adaptive threshold updated: ${adaptive_threshold}ms (after $count pings)${NC}"
        echo -e "${CYAN}  → Trimmed mean: ${trimmed_mean}ms, Jitter: ${trimmed_jitter}ms, Baseline: ${baseline}ms${NC}"
        echo -e "${CYAN}  → Pre-constraint: ${pre_constraint_threshold}ms, Final: ${adaptive_threshold}ms${NC}"
    fi
}

# Function to check for spike
check_spike() {
    local time_ms=$1
    local ping_output="$2"
    
    if [[ ${#response_times[@]} -ge 15 && $time_ms -gt $adaptive_threshold ]]; then
        spike_entries+=("$(date "+%Y-%m-%d %H:%M:%S") - $ping_output")
        return 0
    fi
    
    return 1
}

# Function to display final statistics
display_final_statistics() {
    local end_time=$(date "+%Y-%m-%d %H:%M:%S")
    local stats=$(calculate_statistics)
    IFS=':' read -r min_ms max_ms avg_ms jitter_ms <<< "$stats"
    
    local success_rate=0
    if [[ $total_pings -gt 0 ]]; then
        success_rate=$(echo "scale=2; $successful_count * 100 / $total_pings" | bc -l)
    fi
    
    # Determine jitter quality
    local jitter_quality="Low jitter"
    if [[ $jitter_ms -gt 10 ]]; then
        jitter_quality="High jitter"
    elif [[ $jitter_ms -gt 2 ]]; then
        jitter_quality="Moderate jitter"
    fi
    
    # Calculate runtime
    local runtime_seconds=$(date -d "$end_time" +%s)
    local start_seconds=$(date -d "$start_time" +%s)
    local total_runtime=$((runtime_seconds - start_seconds))
    
    echo ""
    echo "----------------------------------------"
    echo -e "${GREEN}Ping Statistics Summary:${NC}"
    echo "Total pings sent: $total_pings"
    echo "Successful pings: $successful_count"
    echo "Failed pings: $failed_count"
    printf "Success rate: %.2f%%\n" "$success_rate"
    echo "Response time - Min: ${min_ms}ms, Max: ${max_ms}ms, Avg: ${avg_ms}ms"
    echo "Jitter (std dev): ${jitter_ms}ms - $jitter_quality"
    echo "Total runtime: ${total_runtime} seconds"
    
    # Display spikes if any
    if [[ ${#spike_entries[@]} -gt 0 ]]; then
        echo "----------------------------------------"
        echo -e "${YELLOW}Anomalous Spikes (adaptive threshold: ${adaptive_threshold}ms @ ${SPIKE_MULTIPLIER}%):${NC}"
        local spike_num=1
        for spike in "${spike_entries[@]}"; do
            echo "$spike_num - $spike"
            ((spike_num++))
        done
    fi
    
    echo "Log saved to: $LOG_FILE"
    
    # Write summary to log file
    if [[ -n "$LOG_FILE" ]]; then
        echo "" >> "$LOG_FILE"
        write_timestamped_output "=== PING SESSION SUMMARY ==="
        write_timestamped_output "Total pings sent: $total_pings"
        write_timestamped_output "Successful pings: $successful_count"
        write_timestamped_output "Failed pings: $failed_count"
        write_timestamped_output "Success rate: ${success_rate}%"
        write_timestamped_output "Response time - Min: ${min_ms}ms, Max: ${max_ms}ms, Avg: ${avg_ms}ms"
        write_timestamped_output "Jitter (std dev): ${jitter_ms}ms - $jitter_quality"
        write_timestamped_output "Total runtime: ${total_runtime} seconds"
        
        if [[ ${#spike_entries[@]} -gt 0 ]]; then
            write_timestamped_output "=== ANOMALOUS SPIKES (adaptive threshold: ${adaptive_threshold}ms @ ${SPIKE_MULTIPLIER}%) ==="
            local spike_num=1
            for spike in "${spike_entries[@]}"; do
                write_timestamped_output "$spike_num - $spike"
                ((spike_num++))
            done
        fi
        
        write_timestamped_output "Ping session ended"
    fi
}

# Signal handler for graceful shutdown
cleanup() {
    echo ""
    echo -e "${YELLOW}Interrupted by user. Generating final statistics...${NC}"
    display_final_statistics
    exit 0
}

# Main execution function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--destination)
                DESTINATION="$2"
                shift 2
                ;;
            -t|--time-limit)
                TIME_LIMIT="$2"
                shift 2
                ;;
            -l|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -i|--interval)
                INTERVAL="$2"
                shift 2
                ;;
            -s|--spike-multiplier)
                SPIKE_MULTIPLIER="$2"
                shift 2
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$DESTINATION" ]]; then
        echo -e "${RED}Error: Destination parameter is required${NC}"
        show_help
        exit 1
    fi
    
    # Check for required commands
    if ! command -v ping &> /dev/null; then
        echo -e "${RED}Error: ping command not found${NC}"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        echo -e "${RED}Error: bc command not found (required for calculations)${NC}"
        exit 1
    fi
    
    # Initialize logging
    initialize_log_path
    
    # Set up signal handlers
    trap cleanup SIGINT SIGTERM
    
    # Display startup information
    start_time=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo -e "${GREEN}Starting ping to $DESTINATION${NC}"
    echo "Log file: $LOG_FILE"
    
    if [[ $TIME_LIMIT -eq 0 ]]; then
        echo "Running continuously (Press Ctrl+C to stop)"
    else
        echo "Time limit: $TIME_LIMIT seconds"
    fi
    
    echo "Ping interval: ${INTERVAL}ms"
    echo "Adaptive spike detection: ${SPIKE_MULTIPLIER}% multiplier (initial threshold: ${adaptive_threshold}ms)"
    echo "----------------------------------------"
    
    # Log session start
    write_timestamped_output "Ping session started - Target: $DESTINATION, Adaptive spike detection: ${SPIKE_MULTIPLIER}% multiplier"
    
    # Main ping loop
    local session_start=$(date +%s)
    local next_ping=$session_start
    
    while true; do
        local current_time=$(date +%s)
        
        # Check time limit
        if [[ $TIME_LIMIT -gt 0 && $((current_time - session_start)) -ge $TIME_LIMIT ]]; then
            write_timestamped_output "Time limit of $TIME_LIMIT seconds reached. Stopping ping."
            break
        fi
        
        # Check if it's time for next ping
        if [[ $current_time -ge $next_ping ]]; then
            ((total_pings++))
            
            # Perform ping
            local result=$(perform_ping "$DESTINATION")
            IFS=':' read -r status time_ms ping_output <<< "$result"
            
            if [[ "$status" == "success" ]]; then
                ((successful_count++))
                response_times+=($time_ms)
                
                # Check for spike
                if check_spike $time_ms "$ping_output"; then
                    write_timestamped_output "${ping_output} ${RED}[SPIKE]${NC}"
                else
                    write_timestamped_output "$ping_output"
                fi
                
                # Update adaptive threshold periodically
                if [[ $((total_pings % 5)) -eq 0 ]]; then
                    update_adaptive_threshold
                fi
                
            else
                ((failed_count++))
                write_timestamped_output "${RED}Request timed out or failed${NC}"
            fi
            
            # Calculate next ping time
            next_ping=$((next_ping + INTERVAL / 1000))
        fi
        
        # Small sleep to prevent busy waiting
        sleep 0.1
    done
    
    # Display final statistics
    display_final_statistics
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
