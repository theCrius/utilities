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
