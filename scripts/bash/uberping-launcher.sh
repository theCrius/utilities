#!/bin/bash

# UberPing Launcher - Handles common setup issues for bash version
# This script helps run UberPing on systems that may need dependency checks

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display help
show_launcher_help() {
    echo -e "${CYAN}UberPing Launcher (Bash)${NC}"
    echo -e "${YELLOW}Usage: $0 [uberping arguments]${NC}"
    echo ""
    echo -e "${GREEN}Examples:${NC}"
    echo "  $0 -d 8.8.8.8"
    echo "  $0 -d google.com -t 60 -i 2000"
    echo "  $0 -d 192.168.1.1 -s 150 -t 300 --debug"
    echo ""
    echo "This launcher will:"
    echo "• Check for required dependencies (ping, bc)"
    echo "• Verify script permissions"
    echo "• Provide helpful error messages"
    echo "• Launch the main UberPing script"
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for ping command
    if ! command -v ping &> /dev/null; then
        missing_deps+=("ping")
    fi
    
    # Check for bc command
    if ! command -v bc &> /dev/null; then
        missing_deps+=("bc")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Missing required dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "  • $dep"
        done
        echo ""
        echo -e "${YELLOW}Installation instructions:${NC}"
        
        # Detect OS and provide specific instructions
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt-get &> /dev/null; then
                echo "Ubuntu/Debian: sudo apt-get install ${missing_deps[*]}"
            elif command -v yum &> /dev/null; then
                echo "CentOS/RHEL: sudo yum install ${missing_deps[*]}"
            elif command -v dnf &> /dev/null; then
                echo "Fedora: sudo dnf install ${missing_deps[*]}"
            elif command -v pacman &> /dev/null; then
                echo "Arch: sudo pacman -S ${missing_deps[*]}"
            else
                echo "Linux: Install using your package manager: ${missing_deps[*]}"
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            echo "macOS: brew install ${missing_deps[*]}"
            echo "   or: sudo port install ${missing_deps[*]} (MacPorts)"
        else
            echo "Install the following packages: ${missing_deps[*]}"
        fi
        
        return 1
    fi
    
    return 0
}

# Function to check script existence and permissions
check_script() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local uberping_script="$script_dir/uberping.sh"
    
    if [[ ! -f "$uberping_script" ]]; then
        echo -e "${RED}ERROR: UberPing script not found at: $uberping_script${NC}"
        echo -e "${YELLOW}Make sure uberping.sh is in the same directory as this launcher.${NC}"
        return 1
    fi
    
    if [[ ! -x "$uberping_script" ]]; then
        echo -e "${YELLOW}UberPing script is not executable. Attempting to fix...${NC}"
        if chmod +x "$uberping_script"; then
            echo -e "${GREEN}✓ Made uberping.sh executable${NC}"
        else
            echo -e "${RED}✗ Failed to make script executable. Try: chmod +x $uberping_script${NC}"
            return 1
        fi
    fi
    
    echo "$uberping_script"
    return 0
}

# Function to show system information
show_system_info() {
    echo -e "${CYAN}System Information:${NC}"
    echo "OS: $OSTYPE"
    echo "Shell: $SHELL"
    echo "Bash Version: $BASH_VERSION"
    
    if command -v ping &> /dev/null; then
        local ping_version=$(ping -V 2>&1 | head -n1 || ping 2>&1 | head -n1)
        echo "Ping: $ping_version"
    fi
    
    if command -v bc &> /dev/null; then
        local bc_version=$(bc --version 2>&1 | head -n1 || echo "bc available")
        echo "BC: $bc_version"
    fi
    echo ""
}

# Main launcher function
main() {
    # Handle help request
    if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
        show_launcher_help
        exit 0
    fi
    
    # Show system info in debug mode
    for arg in "$@"; do
        if [[ "$arg" == "--debug" ]]; then
            show_system_info
            break
        fi
    done
    
    echo -e "${GREEN}Launching UberPing (Bash)...${NC}"
    
    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi
    
    # Check script
    local uberping_script
    if ! uberping_script=$(check_script); then
        exit 1
    fi
    
    echo -e "${GREEN}✓ All dependencies found${NC}"
    echo -e "${GREEN}✓ UberPing script ready${NC}"
    echo ""
    
    # Execute the main script with all arguments
    exec "$uberping_script" "$@"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
