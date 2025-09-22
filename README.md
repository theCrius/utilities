# Utilities

Scripts, notes and other stuff I need. Might be cool, might be broken, use at your own risk.

## Scripts Index

### PowerShell Scripts (`scripts/pwsh/`)

#### SuperPing - Advanced Network Connectivity Monitor
- **Main Script**: [`superping.ps1`](scripts/pwsh/superping.ps1)
- **Launcher**: [`superping-launcher.ps1`](scripts/pwsh/superping-launcher.ps1) *(handles execution policy issues)*
- **Documentation**: [`superping_readme.md`](scripts/pwsh/superping_readme.md)
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
  - **Direct**: `.\superping.ps1 <destination> [-TimeLimit <seconds>] [options]`
  - **With Launcher** (recommended for PowerShell 5.1): `.\superping-launcher.ps1 <destination> [options]`
  - **Execution Policy Bypass**: `PowerShell -ExecutionPolicy Bypass -File "superping.ps1" <destination> [options]`
