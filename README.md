# Utilities

Scripts, notes and other stuff I need. Might be cool, might be broken, use at your own risk.

## Scripts Index

### PowerShell Scripts (`scripts/pwsh/`)

#### UberPing - Advanced Network Connectivity Monitor
- **Main Script**: [`uberping.ps1`](scripts/pwsh/uberping.ps1)
- **Launcher**: [`uberping-launcher.ps1`](scripts/pwsh/uberping-launcher.ps1) *(handles execution policy issues)*
- **Documentation**: [`uberping_readme.md`](scripts/pwsh/uberping_readme.md)
- **Description**: A PowerShell-based network monitoring tool that performs ping operations with advanced analytics, logging, and anomaly detection
- **Features**:
  - Continuous network monitoring with real-time feedback
  - Advanced analytics (min, max, average, jitter analysis)
  - Spike detection with configurable thresholds
  - Comprehensive timestamped logging
  - Color-coded console output
  - Flexible configuration options
  - Automatic execution policy problem detection and solutions
- **Usage Options**:
  - **Direct**: `.\uberping.ps1 <destination> [-TimeLimit <seconds>] [options]`
  - **With Launcher** (recommended for PowerShell 5.1): `.\uberping-launcher.ps1 <destination> [options]`
  - **Execution Policy Bypass**: `PowerShell -ExecutionPolicy Bypass -File "uberping.ps1" <destination> [options]`

### Bash Scripts (`scripts/bash/`)

#### UberPing - Advanced Network Connectivity Monitor (Linux/macOS)
- **Main Script**: [`uberping.sh`](scripts/bash/uberping.sh)
- **Launcher**: [`uberping-launcher.sh`](scripts/bash/uberping-launcher.sh) *(handles dependency checks)*
- **Documentation**: [`uberping_readme.md`](scripts/bash/uberping_readme.md)
- **Description**: A bash-compatible network monitoring tool with the same advanced features as the PowerShell version, designed for Linux, macOS, and Unix-like systems
- **Features**:
  - Cross-platform compatibility (Linux, macOS, Unix)
  - Same adaptive spike detection algorithm as PowerShell version
  - ANSI colored console output
  - Signal handling for graceful shutdown (Ctrl+C)
  - Automatic dependency checking
  - Comprehensive logging and statistics
  - Flexible timing and configuration options
- **Requirements**: `ping`, `bc`, Bash 4.0+
- **Usage Options**:
  - **Direct**: `./uberping.sh -d <destination> [-t <seconds>] [options]`
  - **With Launcher** (recommended): `./uberping-launcher.sh -d <destination> [options]`
  - **Global Install**: `sudo cp uberping.sh /usr/local/bin/uberping && chmod +x /usr/local/bin/uberping`
