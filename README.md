# Utilities

Scripts, notes and other stuff I need. Might be cool, might be broken, use at your own risk.

## Scripts Index

### PowerShell Scripts (`scripts/pwsh/`)

#### SuperPing - Advanced Network Connectivity Monitor
- **File**: [`superping.ps1`](scripts/pwsh/superping.ps1)
- **Documentation**: [`superping_readme.md`](scripts/pwsh/superping_readme.md)
- **Description**: A PowerShell-based network monitoring tool that performs ping operations with advanced analytics, logging, and anomaly detection
- **Features**:
  - Continuous network monitoring with real-time feedback
  - Advanced analytics (min, max, average, jitter analysis)
  - Spike detection with configurable thresholds
  - Comprehensive timestamped logging
  - Color-coded console output
  - Flexible configuration options
- **Quick Usage**: `.\superping.ps1 <destination> [-TimeLimit <seconds>]`
