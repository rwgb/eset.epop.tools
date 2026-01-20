# ESET Protect Windows Installer

A Go-based automated installer for ESET Protect On-Prem on Windows Server.

## Features

- **Automated Installation**: Downloads and installs ESET Protect All-in-One package
- **Comprehensive Logging**: Detailed logs with timestamps for debugging
- **Progress Tracking**: Real-time download and installation progress
- **Error Handling**: Robust error detection and reporting
- **Interactive Configuration**: Prompts for passwords and settings
- **Prerequisites Checking**: Validates system requirements before installation
- **Silent Installation**: Runs MSI installer in quiet mode
- **Installation Verification**: Checks services and directories after installation

## Prerequisites

- Windows Server 2012 R2 or later
- Administrator privileges
- Internet connection (for downloading installer)
- Minimum 20 GB free disk space
- 4 GB RAM minimum (8 GB recommended)

## Building the Installer

### On Windows:

```cmd
cd scripts\windows
go mod download
go build -o eset-protect-installer.exe install-eset-windows.go
```

### Cross-compile from Linux/macOS:

```bash
cd scripts/windows
go mod download
GOOS=windows GOARCH=amd64 go build -o eset-protect-installer.exe install-eset-windows.go
```

## Usage

1. **Run as Administrator** (required):
   ```cmd
   # Right-click and select "Run as Administrator"
   eset-protect-installer.exe
   ```

2. **Follow the prompts**:
   - ESET Console Administrator Password
   - Database Password
   - Installation Path (optional, press Enter for default)

3. **Wait for completion**:
   - The installer will download the ESET Protect All-in-One MSI
   - Installation will run silently in the background
   - Progress and detailed logs are displayed in real-time

## Logging

The installer creates detailed logs in two locations:

1. **Main Installation Log**: 
   ```
   C:\ProgramData\ESET\Logs\Installer\eset-install-<timestamp>.log
   ```
   Contains the installer's own logging with timestamps

2. **MSI Installation Log**:
   ```
   C:\ProgramData\ESET\Logs\Installer\eset-msi-<timestamp>.log
   ```
   Contains verbose MSI installer output

### Log Levels:

- `[INFO]` - Normal operation information
- `[WARN]` - Warnings that don't stop installation
- `[ERROR]` - Critical errors that abort installation
- `[STEP]` - Major installation steps

## What Gets Installed

The All-in-One installer includes:

- ESET Protect Server
- ESET Management Console
- Built-in MySQL database
- Apache Tomcat web server
- All necessary dependencies

## Post-Installation

After successful installation:

1. **Access Web Console**:
   ```
   https://<your-server-hostname>:2223
   ```

2. **Default Credentials**:
   - Username: `Administrator`
   - Password: The password you provided during installation

3. **Firewall Configuration**:
   ```powershell
   # Allow ESET Protect ports
   New-NetFirewallRule -DisplayName "ESET Protect Server" -Direction Inbound -LocalPort 2222 -Protocol TCP -Action Allow
   New-NetFirewallRule -DisplayName "ESET Protect Console" -Direction Inbound -LocalPort 2223 -Protocol TCP -Action Allow
   ```

4. **Check Services**:
   ```powershell
   Get-Service | Where-Object {$_.Name -like "*ERA*"}
   ```

## Troubleshooting

### Installation Failed

Check the detailed logs:
```powershell
# View main log
notepad C:\ProgramData\ESET\Logs\Installer\eset-install-*.log

# View MSI log
notepad C:\ProgramData\ESET\Logs\Installer\eset-msi-*.log
```

### Common Issues

**"Must be run as Administrator"**
- Right-click the EXE and select "Run as Administrator"

**Download Fails**
- Check internet connectivity
- Verify firewall allows HTTPS downloads
- Try manual download from: https://download.eset.com/

**Installation Hangs**
- Check MSI log file for detailed error messages
- Ensure no other installations are running
- Verify sufficient disk space

**Services Not Starting**
- Check Windows Event Viewer (Application and System logs)
- Verify database password was set correctly
- Check port 2222 and 2223 are not in use:
  ```powershell
  netstat -ano | findstr "222"
  ```

### Uninstallation

To remove ESET Protect:

```powershell
# Using Programs and Features
appwiz.cpl

# Or via msiexec
msiexec /x {PRODUCT-CODE} /qn
```

## Advanced Options

### Custom Installation Path

When prompted, specify a custom path:
```
Installation Path: D:\ESET\Protect
```

### Automated/Silent Mode

For fully automated installation (future feature):
```cmd
eset-protect-installer.exe --console-password "P@ssw0rd" --db-password "DbP@ss" --silent
```

## Building with Static Binary

For a standalone executable with no external dependencies:

```cmd
go build -ldflags "-s -w" -o eset-protect-installer.exe install-eset-windows.go
```

Flags:
- `-s` - Omit symbol table
- `-w` - Omit DWARF debug info
- Results in smaller binary size

## Security Considerations

⚠️ **Important Security Notes**:

1. **Password Handling**: Passwords are only used during installation and are not stored
2. **Log Files**: MSI logs contain sensitive information - secure these files appropriately
3. **Installer Cleanup**: Option to delete installer file after completion
4. **Network Security**: Ensure secure HTTPS connections to download servers

## Development

### Project Structure

```
scripts/windows/
├── install-eset-windows.go   # Main installer code
├── go.mod                      # Go module definition
└── README.md                   # This file
```

### Key Functions

- `CheckAdminPrivileges()` - Validates administrator rights
- `CheckPrerequisites()` - Verifies system requirements
- `DownloadFile()` - Downloads installer with progress
- `RunMSIInstaller()` - Executes MSI with logging
- `VerifyInstallation()` - Checks installation success

### Adding Features

To add new functionality:

1. Add command-line flags using the `flag` package
2. Extend `InstallConfig` struct with new options
3. Update MSI parameters in `RunMSIInstaller()`
4. Add verification checks in `VerifyInstallation()`

## License

This installer tool is provided as-is. ESET Protect On-Prem is subject to ESET's licensing terms.

## Support

For ESET Protect support:
- ESET Support Portal: https://support.eset.com/
- Documentation: https://help.eset.com/protect_install/

For installer tool issues:
- Check the generated log files
- Review MSI installation logs
- Consult Windows Event Viewer
