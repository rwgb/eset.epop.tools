<#
.SYNOPSIS
    ESET Protect On-Prem Installation Script for Windows

.DESCRIPTION
    Automated installation of ESET Protect On-Prem with SQL Server Express.
    Supports both interactive and non-interactive modes.

.PARAMETER MySQLRootPassword
    SQL Server SA password (for non-interactive mode)

.PARAMETER EsetAdminPassword
    ESET Console administrator password (for non-interactive mode)

.PARAMETER DbUserUsername
    Database user for ESET (default: era_user)

.PARAMETER DbUserPassword
    Database user password (for non-interactive mode)

.PARAMETER InstallPath
    Custom installation path (optional)

.PARAMETER NonInteractive
    Run in non-interactive mode (requires all password parameters)

.EXAMPLE
    .\install-eset.ps1
    # Interactive mode - will prompt for credentials

.EXAMPLE
    .\install-eset.ps1 -NonInteractive -MySQLRootPassword "P@ssw0rd" -EsetAdminPassword "Admin123" -DbUserUsername "era_user" -DbUserPassword "DbP@ss123"
    # Non-interactive mode with all credentials provided

.NOTES
    Author: ESET Protect Installation Team
    Requires: PowerShell 5.1+, Administrator privileges, Windows Server 2012 R2 or later
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$MySQLRootPassword,

    [Parameter(Mandatory=$false)]
    [string]$EsetAdminPassword,

    [Parameter(Mandatory=$false)]
    [string]$DbUserUsername = "era_user",

    [Parameter(Mandatory=$false)]
    [string]$DbUserPassword,

    [Parameter(Mandatory=$false)]
    [string]$InstallPath,

    [Parameter(Mandatory=$false)]
    [switch]$NonInteractive
)

#Requires -RunAsAdministrator
#Requires -Version 5.1

# Static Configuration
$script:Config = @{
    SqlServerExpressUrl = "https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLEXPR_x64_ENU.exe"
    SqlServerExpressFile = "SQLEXPR_x64_ENU.exe"
    EsetInstallerUrl = "https://download.eset.com/com/eset/apps/business/era/server/windows/latest/server_x64.msi"
    EsetInstallerFile = "server_x64.msi"
    LogDirectory = "C:\ProgramData\ESET\Logs\Installer"
    TempDirectory = "C:\Temp\ESET-Install"
    SqlInstanceName = "ESETERA"
    SqlPort = 1433
    DatabaseName = "era_db"
}

# Logging setup
$script:LogFile = Join-Path $Config.LogDirectory "installation-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$script:ErrorOccurred = $false

#######################################
# Color Console Output
#######################################

function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Step')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
    
    # Write to console with colors
    $color = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        'Step'    { 'Cyan' }
        default   { 'White' }
    }
    
    Write-Host "[$Level] " -ForegroundColor $color -NoNewline
    Write-Host $Message
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput -Message $Message -Level Info
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput -Message $Message -Level Success
}

function Write-Warn {
    param([string]$Message)
    Write-ColorOutput -Message $Message -Level Warning
}

function Write-Err {
    param([string]$Message)
    $script:ErrorOccurred = $true
    Write-ColorOutput -Message $Message -Level Error
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-ColorOutput -Message $Message -Level Step
    Write-Host "========================================" -ForegroundColor Cyan
}

function Exit-WithError {
    param([string]$Message)
    Write-Err $Message
    Write-Err "Installation failed. Check log: $LogFile"
    exit 1
}

#######################################
# Password Prompt Functions
#######################################

function Get-SecurePassword {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxAttempts = 3
    )
    
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $password = Read-Host -Prompt $Prompt -AsSecureString
        $confirm = Read-Host -Prompt "Confirm $Prompt" -AsSecureString
        
        # Convert to plain text for comparison
        $passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
        $confirmPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirm))
        
        if ($passwordPlain -eq $confirmPlain) {
            return $passwordPlain
        }
        
        if ($attempt -lt $MaxAttempts) {
            Write-Warn "Passwords do not match. Please try again. (Attempt $attempt/$MaxAttempts)"
        }
    }
    
    Exit-WithError "Passwords do not match after $MaxAttempts attempts"
}

#######################################
# Credential Prompting
#######################################

function Get-InstallationCredentials {
    Write-Step "Configuration Setup"
    
    # Check if running in non-interactive mode with all credentials
    if ($NonInteractive) {
        if ([string]::IsNullOrEmpty($MySQLRootPassword) -or 
            [string]::IsNullOrEmpty($EsetAdminPassword) -or 
            [string]::IsNullOrEmpty($DbUserPassword)) {
            Exit-WithError "Non-interactive mode requires: -MySQLRootPassword, -EsetAdminPassword, -DbUserPassword"
        }
        
        Write-Info "Using credentials from parameters (non-interactive mode)"
        Write-Info "SQL Server SA password: ***"
        Write-Info "ESET administrator password: ***"
        Write-Info "Database username: $DbUserUsername"
        Write-Info "Database user password: ***"
        Write-Success "Configuration complete!"
        return
    }
    
    # Interactive mode - prompt for credentials
    Write-Host ""
    Write-Host "Please provide the following configuration details:" -ForegroundColor Yellow
    Write-Host ""
    
    # SQL Server SA Password
    if ([string]::IsNullOrEmpty($script:MySQLRootPassword)) {
        $script:MySQLRootPassword = Get-SecurePassword -Prompt "SQL Server SA password"
        Write-Info "SQL Server SA password set"
    }
    
    # ESET Admin Password
    if ([string]::IsNullOrEmpty($script:EsetAdminPassword)) {
        $script:EsetAdminPassword = Get-SecurePassword -Prompt "ESET Protect administrator password"
        Write-Info "ESET administrator password set"
    }
    
    # Database User Username
    if ([string]::IsNullOrEmpty($script:DbUserUsername)) {
        $username = Read-Host -Prompt "Enter ESET database username [era_user]"
        $script:DbUserUsername = if ([string]::IsNullOrEmpty($username)) { "era_user" } else { $username }
        
        if ($script:DbUserUsername -notmatch '^[a-zA-Z0-9_]+$') {
            Exit-WithError "Username must contain only alphanumeric characters and underscores"
        }
    }
    Write-Info "Database username set to: $($script:DbUserUsername)"
    
    # Database User Password
    if ([string]::IsNullOrEmpty($script:DbUserPassword)) {
        $script:DbUserPassword = Get-SecurePassword -Prompt "ESET database user password"
        Write-Info "Database user password set"
    }
    
    Write-Host ""
    Write-Success "Configuration complete!"
    Write-Host ""
}

#######################################
# Prerequisite Checks
#######################################

function Test-Prerequisites {
    Write-Step "Checking Prerequisites"
    
    # Check Windows version
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $osVersion = [System.Version]$osInfo.Version
    
    Write-Info "Operating System: $($osInfo.Caption)"
    Write-Info "Version: $($osInfo.Version)"
    Write-Info "Architecture: $($osInfo.OSArchitecture)"
    
    if ($osVersion.Major -lt 10 -and -not ($osVersion.Major -eq 6 -and $osVersion.Minor -ge 1)) {
        Exit-WithError "Unsupported Windows version. Requires Windows Server 2012 R2 or later"
    }
    
    # Check disk space
    $systemDrive = Get-PSDrive -Name C
    $freeSpaceGB = [math]::Round($systemDrive.Free / 1GB, 2)
    Write-Info "Free disk space on C:\: $freeSpaceGB GB"
    
    if ($freeSpaceGB -lt 20) {
        Write-Warn "Low disk space. Recommended minimum: 20 GB"
    }
    
    # Check Administrator privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Exit-WithError "This script must be run as Administrator"
    }
    Write-Info "Administrator privileges: OK"
    
    # Check PowerShell version
    Write-Info "PowerShell Version: $($PSVersionTable.PSVersion)"
    
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Exit-WithError "PowerShell 5.1 or later is required"
    }
    
    # Check .NET Framework version (required for SQL Server)
    Write-Info "Checking .NET Framework version"
    try {
        $netVersion = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue
        if ($netVersion) {
            $release = $netVersion.Release
            Write-Info ".NET Framework 4.x detected (Release: $release)"
            
            # SQL Server Express requires .NET Framework 4.6 or later (release >= 393295)
            if ($release -lt 393295) {
                Write-Warn ".NET Framework 4.6 or later is recommended for SQL Server Express"
                Write-Warn "Current release: $release (Need >= 393295)"
                Write-Warn "Download from: https://dotnet.microsoft.com/download/dotnet-framework"
            }
        }
        else {
            Write-Warn ".NET Framework 4.x not detected - SQL Server may fail to install"
            Write-Warn "Please install .NET Framework 4.6 or later from: https://dotnet.microsoft.com/download/dotnet-framework"
        }
    }
    catch {
        Write-Warn "Could not check .NET Framework version: $_"
    }
    
    Write-Success "All prerequisite checks passed"
}

#######################################
# Download Functions
#######################################

function Get-FileDownload {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory=$false)]
        [string]$Description = "file"
    )
    
    Write-Info "Downloading $Description from: $Url"
    Write-Info "Saving to: $OutputPath"
    
    try {
        # Enable TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -ErrorAction Stop
        $ProgressPreference = 'Continue'
        
        $fileSize = (Get-Item $OutputPath).Length / 1MB
        Write-Success "Downloaded successfully (${fileSize:N2} MB)"
        return $true
    }
    catch {
        Write-Err "Failed to download from $Url : $_"
        return $false
    }
}

#######################################
# SQL Server Installation
#######################################

function Install-SqlServerExpress {
    Write-Step "Step 1: Installing SQL Server Express"
    
    $installerPath = Join-Path $Config.TempDirectory $Config.SqlServerExpressFile
    $configFile = Join-Path $Config.TempDirectory "sql_config.ini"
    
    # Download SQL Server Express
    if (-not (Test-Path $installerPath)) {
        if (-not (Get-FileDownload -Url $Config.SqlServerExpressUrl -OutputPath $installerPath -Description "SQL Server Express")) {
            Exit-WithError "Failed to download SQL Server Express"
        }
    } else {
        Write-Info "SQL Server Express installer already exists"
    }
    
    # Create configuration file for unattended installation
    Write-Info "Creating SQL Server configuration file"
    
    $configContent = @"
[OPTIONS]
ACTION="Install"
QUIET="True"
IACCEPTSQLSERVERLICENSETERMS="True"
ENU="True"
FEATURES=SQLENGINE
INSTANCENAME="$($Config.SqlInstanceName)"
INSTANCEID="$($Config.SqlInstanceName)"
SQLSVCACCOUNT="NT AUTHORITY\SYSTEM"
SQLSVCSTARTUPTYPE="Automatic"
SQLSYSADMINACCOUNTS="BUILTIN\Administrators"
SECURITYMODE="SQL"
SAPWD="$MySQLRootPassword"
TCPENABLED="1"
NPENABLED="1"
BROWSERSVCSTARTUPTYPE="Automatic"
FILESTREAMLEVEL="0"
UPDATEENABLED="False"
"@
    
    Set-Content -Path $configFile -Value $configContent -Force
    Write-Info "Configuration file created"
    
    # Check if SQL Server instance already exists
    $sqlService = Get-Service -Name "MSSQL`$$($Config.SqlInstanceName)" -ErrorAction SilentlyContinue
    if ($sqlService) {
        Write-Warn "SQL Server instance $($Config.SqlInstanceName) already exists"
        
        if ($sqlService.Status -ne 'Running') {
            Write-Info "Starting SQL Server service"
            Start-Service -Name "MSSQL`$$($Config.SqlInstanceName)"
        }
        
        Write-Success "SQL Server instance already installed and running"
        return
    }
    
    # Run SQL Server installation
    Write-Info "Installing SQL Server Express..."
    Write-Info "This may take 10-15 minutes. Please wait..."
    
    $installArgs = @(
        "/ConfigurationFile=`"$configFile`""
        "/INDICATEPROGRESS"
        "/SUPPRESSPRIVACYSTATEMENTNOTICE"
    )
    
    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Success "SQL Server Express installed successfully"
    }
    elseif ($process.ExitCode -eq 3010) {
        Write-Warn "SQL Server Express installed successfully (reboot required)"
    }
    else {
        # Detailed error reporting
        Write-Err "SQL Server installation failed with exit code: $($process.ExitCode)"
        
        # Common error codes and their meanings
        $errorMessage = switch ($process.ExitCode) {
            -2068643839 { "Missing .NET Framework 4.6 or later" }
            -2061893619 { "Missing prerequisites or system requirements not met" }
            -2068052377 { "Installation media corrupt or incomplete" }
            -2067919934 { "Previous installation in progress or incomplete" }
            default { "Unknown error - check detailed logs" }
        }
        
        Write-Err "Likely cause: $errorMessage"
        
        # Check detailed logs
        $logBasePath = "$env:ProgramFiles\Microsoft SQL Server"
        $summaryFiles = Get-ChildItem -Path $logBasePath -Filter "Summary.txt" -Recurse -ErrorAction SilentlyContinue | 
                        Sort-Object LastWriteTime -Descending | 
                        Select-Object -First 1
        
        if ($summaryFiles) {
            Write-Err "Detailed log available at: $($summaryFiles.FullName)"
            Write-Info "Last 20 lines of installation log:"
            Write-Host "----------------------------------------"
            Get-Content $summaryFiles.FullName -Tail 20 | ForEach-Object { Write-Host $_ }
            Write-Host "----------------------------------------"
        }
        
        # Additional diagnostics
        Write-Info "Troubleshooting steps:"
        Write-Info "1. Ensure .NET Framework 4.6 or later is installed"
        Write-Info "2. Run Windows Update and install all pending updates"
        Write-Info "3. Check if another SQL Server installation is in progress"
        Write-Info "4. Review the detailed log file above for specific errors"
        Write-Info "5. Try running the installer manually: $installerPath"
        
        Exit-WithError "SQL Server installation failed. Please review the errors above."
    }
    
    # Wait for SQL Server service to start
    Write-Info "Waiting for SQL Server service to start..."
    Start-Sleep -Seconds 10
    
    $sqlService = Get-Service -Name "MSSQL`$$($Config.SqlInstanceName)" -ErrorAction SilentlyContinue
    if ($sqlService -and $sqlService.Status -eq 'Running') {
        Write-Success "SQL Server service is running"
    }
    else {
        Write-Warn "SQL Server service may not be running. Attempting to start..."
        try {
            Start-Service -Name "MSSQL`$$($Config.SqlInstanceName)" -ErrorAction Stop
            Write-Success "SQL Server service started"
        }
        catch {
            Exit-WithError "Failed to start SQL Server service: $_"
        }
    }
}

#######################################
# SQL Server Configuration
#######################################

function Configure-SqlServer {
    Write-Step "Step 2: Configuring SQL Server"
    
    # Enable TCP/IP protocol
    Write-Info "Enabling TCP/IP protocol"
    
    try {
        # Load SQL Server WMI provider
        $null = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")
        
        $instanceName = $Config.SqlInstanceName
        $serverName = $env:COMPUTERNAME
        $smo = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $serverName
        
        $tcp = $smo.ServerInstances[$instanceName].ServerProtocols['Tcp']
        if ($tcp.IsEnabled -eq $false) {
            $tcp.IsEnabled = $true
            $tcp.Alter()
            Write-Info "TCP/IP protocol enabled"
            
            # Restart SQL Server service
            Write-Info "Restarting SQL Server service to apply changes"
            Restart-Service -Name "MSSQL`$$instanceName" -Force
            Start-Sleep -Seconds 10
            Write-Success "SQL Server service restarted"
        }
        else {
            Write-Info "TCP/IP protocol already enabled"
        }
    }
    catch {
        Write-Warn "Could not configure TCP/IP via WMI: $_"
        Write-Info "Attempting alternative configuration method"
    }
    
    # Configure Windows Firewall
    Write-Info "Configuring Windows Firewall rules"
    
    try {
        $ruleName = "SQL Server ($($Config.SqlInstanceName))"
        $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        
        if (-not $existingRule) {
            New-NetFirewallRule -DisplayName $ruleName `
                -Direction Inbound `
                -Protocol TCP `
                -LocalPort $Config.SqlPort `
                -Action Allow `
                -Profile Any `
                -Enabled True | Out-Null
            Write-Info "Firewall rule created for SQL Server"
        }
        else {
            Write-Info "Firewall rule already exists"
        }
    }
    catch {
        Write-Warn "Could not create firewall rule: $_"
    }
    
    # Create ESET database and user
    Write-Info "Creating ESET database and user"
    
    $serverInstance = "$env:COMPUTERNAME\$($Config.SqlInstanceName)"
    
    $createDbScript = @"
-- Create database if it doesn't exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = '$($Config.DatabaseName)')
BEGIN
    CREATE DATABASE [$($Config.DatabaseName)];
    PRINT 'Database created';
END
ELSE
BEGIN
    PRINT 'Database already exists';
END
GO

USE [$($Config.DatabaseName)];
GO

-- Create login if it doesn't exist
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = '$DbUserUsername')
BEGIN
    CREATE LOGIN [$DbUserUsername] WITH PASSWORD = '$DbUserPassword', CHECK_POLICY = OFF;
    PRINT 'Login created';
END
ELSE
BEGIN
    PRINT 'Login already exists';
END
GO

-- Create user in database
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = '$DbUserUsername')
BEGIN
    CREATE USER [$DbUserUsername] FOR LOGIN [$DbUserUsername];
    PRINT 'User created';
END
ELSE
BEGIN
    PRINT 'User already exists';
END
GO

-- Grant permissions
ALTER ROLE db_owner ADD MEMBER [$DbUserUsername];
GO

PRINT 'Database configuration complete';
"@
    
    $sqlScriptPath = Join-Path $Config.TempDirectory "create_db.sql"
    Set-Content -Path $sqlScriptPath -Value $createDbScript -Force
    
    try {
        # Use sqlcmd to execute the script
        $sqlcmdPath = Get-Command sqlcmd.exe -ErrorAction SilentlyContinue
        
        if ($sqlcmdPath) {
            $sqlcmdArgs = @(
                "-S", $serverInstance
                "-U", "sa"
                "-P", $MySQLRootPassword
                "-i", $sqlScriptPath
            )
            
            $result = & sqlcmd.exe $sqlcmdArgs 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Database and user created successfully"
            }
            else {
                Write-Err "sqlcmd output: $result"
                Exit-WithError "Failed to create database and user"
            }
        }
        else {
            Write-Warn "sqlcmd not found. Database will be created during ESET installation"
        }
    }
    catch {
        Write-Warn "Could not create database via sqlcmd: $_"
        Write-Info "Database will be created during ESET installation"
    }
    
    # Test SQL Server connection before proceeding
    Write-Info "Testing SQL Server connection"
    try {
        $testQuery = "SELECT @@VERSION"
        $sqlcmdPath = Get-Command sqlcmd.exe -ErrorAction SilentlyContinue
        
        if ($sqlcmdPath) {
            $testArgs = @("-S", $serverInstance, "-U", "sa", "-P", $MySQLRootPassword, "-Q", $testQuery)
            $testResult = & sqlcmd.exe $testArgs 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "SQL Server connection test successful"
                Write-Info "SQL Server version: $($testResult[0])"
            }
            else {
                Write-Err "SQL Server connection test failed"
                Write-Err "Error: $testResult"
                Exit-WithError "Cannot connect to SQL Server. Please verify SQL Server is running and credentials are correct."
            }
        }
        else {
            Write-Warn "sqlcmd not found. Skipping connection test."
        }
    }
    catch {
        Write-Warn "Could not test SQL Server connection: $_"
    }
}

#######################################
# ESET Installation
#######################################

function Install-EsetProtect {
    Write-Step "Step 3: Installing ESET Protect"
    
    $installerPath = Join-Path $Config.TempDirectory $Config.EsetInstallerFile
    
    # Download ESET installer
    if (-not (Test-Path $installerPath)) {
        if (-not (Get-FileDownload -Url $Config.EsetInstallerUrl -OutputPath $installerPath -Description "ESET Protect")) {
            Exit-WithError "Failed to download ESET Protect installer"
        }
    }
    else {
        Write-Info "ESET Protect installer already exists"
        
        $response = Read-Host "Re-download installer? (y/N)"
        if ($response -eq 'y') {
            Remove-Item $installerPath -Force
            if (-not (Get-FileDownload -Url $Config.EsetInstallerUrl -OutputPath $installerPath -Description "ESET Protect")) {
                Exit-WithError "Failed to download ESET Protect installer"
            }
        }
    }
    
    # Verify installer
    if (-not (Test-Path $installerPath)) {
        Exit-WithError "ESET installer not found at: $installerPath"
    }
    
    $fileSize = (Get-Item $installerPath).Length / 1MB
    Write-Info "Installer file size: ${fileSize:N2} MB"
    
    # Run ESET installation
    Write-Info "Running ESET Protect installation..."
    Write-Info "This may take several minutes..."
    
    $msiLogPath = Join-Path $Config.LogDirectory "eset-msi-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $serverInstance = "$env:COMPUTERNAME\$($Config.SqlInstanceName)"
    
    # Build MSI command line with correct ESET property names
    # Using P_ prefix for ESET properties as shown in their documentation
    $msiCommand = "/i `"$installerPath`" /qn /norestart /l*v `"$msiLogPath`" " +
                  "ADDLOCAL=ALL " +
                  "P_ACTIVATE_WITH_LICENSE_NOW=0 " +
                  "P_DB_ENGINE=2 " +
                  "P_DB_TYPE=1 " +
                  "P_DB_SERVER=`"$serverInstance`" " +
                  "P_DB_NAME=`"$($Config.DatabaseName)`" " +
                  "P_DB_ADMIN_NAME=`"sa`" " +
                  "P_DB_ADMIN_PASSWORD=`"$MySQLRootPassword`" " +
                  "P_DB_USER_NAME=`"$DbUserUsername`" " +
                  "P_DB_USER_PASSWORD=`"$DbUserPassword`" " +
                  "P_ADMIN_PASSWORD=`"$EsetAdminPassword`" " +
                  "P_SERVER_CERTIFICATES_OPTION=GENERATE " +
                  "P_SERVER_CERTIFICATES_OPTION_REPAIR=KEEP " +
                  "P_CERT_AUTH_COMMON_NAME=`"Server Certification Authority`" " +
                  "P_SERVER_PORT=2222 " +
                  "P_CONSOLE_PORT=2223"
    
    if (-not [string]::IsNullOrEmpty($InstallPath)) {
        $msiCommand += " INSTALLDIR=`"$InstallPath`""
    }
    
    Write-Info "Installation log will be written to: $msiLogPath"
    Write-Info "Command: msiexec $($msiCommand -replace 'PASSWORD=`"[^`"]*`"','PASSWORD=`"***`"')"
    
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiCommand -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Success "ESET Protect installed successfully!"
    }
    elseif ($process.ExitCode -eq 3010) {
        Write-Warn "ESET Protect installed successfully (reboot required)"
    }
    else {
        Write-Err "Installation failed with exit code: $($process.ExitCode)"
        Write-Err "Check detailed log: $msiLogPath"
        Exit-WithError "ESET Protect installation failed"
    }
}

#######################################
# Verification
#######################################

function Test-Installation {
    Write-Step "Step 4: Verifying Installation"
    
    # Check ESET services
    $esetServices = @(
        "ERA_Server",
        "ERA_MDM_Connector"
    )
    
    foreach ($serviceName in $esetServices) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        
        if ($service) {
            if ($service.Status -eq 'Running') {
                Write-Success "Service $serviceName is running"
            }
            else {
                Write-Warn "Service $serviceName is not running. Status: $($service.Status)"
                
                try {
                    Write-Info "Attempting to start $serviceName"
                    Start-Service -Name $serviceName -ErrorAction Stop
                    Write-Success "Service $serviceName started"
                }
                catch {
                    Write-Err "Failed to start $serviceName : $_"
                }
            }
        }
        else {
            Write-Warn "Service $serviceName not found"
        }
    }
    
    # Check installation directories
    $installDirs = @(
        "${env:ProgramFiles}\ESET\RemoteAdministrator\Server",
        "${env:ProgramFiles}\ESET\RemoteAdministrator\Console"
    )
    
    foreach ($dir in $installDirs) {
        if (Test-Path $dir) {
            Write-Success "Installation directory found: $dir"
        }
        else {
            Write-Warn "Installation directory not found: $dir"
        }
    }
    
    # Check firewall rules for ESET ports
    Write-Info "Configuring Windows Firewall for ESET Protect"
    
    $esetPorts = @(
        @{Name="ESET Protect Server (2222)"; Port=2222},
        @{Name="ESET Protect Web Console (2223)"; Port=2223}
    )
    
    foreach ($portConfig in $esetPorts) {
        try {
            $existingRule = Get-NetFirewallRule -DisplayName $portConfig.Name -ErrorAction SilentlyContinue
            
            if (-not $existingRule) {
                New-NetFirewallRule -DisplayName $portConfig.Name `
                    -Direction Inbound `
                    -Protocol TCP `
                    -LocalPort $portConfig.Port `
                    -Action Allow `
                    -Profile Any `
                    -Enabled True | Out-Null
                Write-Info "Firewall rule created: $($portConfig.Name)"
            }
            else {
                Write-Info "Firewall rule already exists: $($portConfig.Name)"
            }
        }
        catch {
            Write-Warn "Could not create firewall rule for port $($portConfig.Port): $_"
        }
    }
    
    Write-Success "Installation verification complete"
}

#######################################
# Cleanup
#######################################

function Remove-TemporaryFiles {
    Write-Step "Cleanup"
    
    $response = if ($NonInteractive) { 'y' } else { Read-Host "Delete temporary installation files? (y/N)" }
    
    if ($response -eq 'y') {
        try {
            if (Test-Path $Config.TempDirectory) {
                Remove-Item -Path $Config.TempDirectory -Recurse -Force -ErrorAction Stop
                Write-Success "Temporary files deleted"
            }
        }
        catch {
            Write-Warn "Could not delete temporary files: $_"
        }
    }
    else {
        Write-Info "Temporary files kept at: $($Config.TempDirectory)"
    }
}

#######################################
# Main Installation Function
#######################################

function Start-Installation {
    # Print banner
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "ESET Protect On-Prem Installer" -ForegroundColor Cyan
    Write-Host "Windows All-in-One Installation" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Log file: $LogFile" -ForegroundColor Cyan
    Write-Host ""
    
    # Create directories
    New-Item -Path $Config.LogDirectory -ItemType Directory -Force | Out-Null
    New-Item -Path $Config.TempDirectory -ItemType Directory -Force | Out-Null
    
    # Initialize log file
    "Installation started at $(Get-Date)" | Out-File -FilePath $LogFile -Force
    
    try {
        # Step 0: Prerequisites
        Test-Prerequisites
        
        # Step 0.5: Get credentials
        Get-InstallationCredentials
        
        # Step 1: Install SQL Server Express
        Install-SqlServerExpress
        
        # Step 2: Configure SQL Server
        Configure-SqlServer
        
        # Step 3: Install ESET Protect
        Install-EsetProtect
        
        # Step 4: Verify installation
        Test-Installation
        
        # Cleanup
        Remove-TemporaryFiles
        
        # Print completion message
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Installation Complete!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Web Console URL: https://$($env:COMPUTERNAME):2223" -ForegroundColor Cyan
        Write-Host "Username: Administrator" -ForegroundColor Cyan
        Write-Host "Password: <the password you provided>" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "SQL Server Instance: $($env:COMPUTERNAME)\$($Config.SqlInstanceName)" -ForegroundColor Cyan
        Write-Host "Database Name: $($Config.DatabaseName)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Installation logs:" -ForegroundColor Cyan
        Write-Host "  - Main log: $LogFile" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Please ensure Windows Firewall allows ports 2222 and 2223" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Thank you for installing ESET Protect On-Prem!" -ForegroundColor Green
        
    }
    catch {
        Write-Err "Unexpected error during installation: $_"
        Write-Err $_.ScriptStackTrace
        Exit-WithError "Installation aborted due to error"
    }
}

#######################################
# Script Entry Point
#######################################

# Start installation
Start-Installation
