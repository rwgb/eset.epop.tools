package main

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"golang.org/x/sys/windows"
)

const (
	// ESET Protect All-in-One Installer URL
	ESETInstallerURL = "https://download.eset.com/com/eset/apps/business/era/server/windows/latest/era_server_x64.msi"

	// Installer file name
	InstallerFileName = "era_server_x64.msi"

	// Log directory
	LogDirectory = "C:\\ProgramData\\ESET\\Logs\\Installer"

	// Color codes for Windows console
	ColorReset  = "\033[0m"
	ColorRed    = "\033[31m"
	ColorGreen  = "\033[32m"
	ColorYellow = "\033[33m"
	ColorBlue   = "\033[34m"
)

// Logger wraps log functionality with timestamps and colors
type Logger struct {
	file   *os.File
	logger *log.Logger
}

// NewLogger creates a new logger instance
func NewLogger(logPath string) (*Logger, error) {
	// Create log directory if it doesn't exist
	logDir := filepath.Dir(logPath)
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create log directory: %w", err)
	}

	// Open log file
	file, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return nil, fmt.Errorf("failed to open log file: %w", err)
	}

	// Create multi-writer to write to both file and stdout
	mw := io.MultiWriter(os.Stdout, file)
	logger := log.New(mw, "", 0)

	return &Logger{
		file:   file,
		logger: logger,
	}, nil
}

// Close closes the log file
func (l *Logger) Close() error {
	return l.file.Close()
}

// Info logs an info message
func (l *Logger) Info(format string, v ...interface{}) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	msg := fmt.Sprintf(format, v...)
	l.logger.Printf("[%s] %s[INFO]%s %s", timestamp, ColorGreen, ColorReset, msg)
}

// Warn logs a warning message
func (l *Logger) Warn(format string, v ...interface{}) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	msg := fmt.Sprintf(format, v...)
	l.logger.Printf("[%s] %s[WARN]%s %s", timestamp, ColorYellow, ColorReset, msg)
}

// Error logs an error message
func (l *Logger) Error(format string, v ...interface{}) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	msg := fmt.Sprintf(format, v...)
	l.logger.Printf("[%s] %s[ERROR]%s %s", timestamp, ColorRed, ColorReset, msg)
}

// Step logs a step header
func (l *Logger) Step(format string, v ...interface{}) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	msg := fmt.Sprintf(format, v...)
	l.logger.Println()
	l.logger.Println("========================================")
	l.logger.Printf("[%s] %s[STEP]%s %s", timestamp, ColorBlue, ColorReset, msg)
	l.logger.Println("========================================")
}

// InstallConfig holds installation configuration
type InstallConfig struct {
	ConsolePassword string
	DBPassword      string
	InstallPath     string
	LogPath         string
	SkipDownload    bool
}

// PromptForInput prompts user for input
func PromptForInput(prompt string, hideInput bool) (string, error) {
	fmt.Print(prompt)

	if hideInput {
		// For passwords, hide input
		password, err := readPassword()
		fmt.Println()
		return password, err
	}

	// For regular input
	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(input), nil
}

// readPassword reads password input without echoing
func readPassword() (string, error) {
	var password []byte
	var err error

	// Try to read password using Windows API
	fd := int(syscall.Stdin)
	state, err := windows.GetConsoleMode(windows.Handle(fd))
	if err != nil {
		// Fallback to regular input if not a console
		reader := bufio.NewReader(os.Stdin)
		input, err := reader.ReadString('\n')
		if err != nil {
			return "", err
		}
		return strings.TrimSpace(input), nil
	}

	// Disable echo
	newState := state &^ windows.ENABLE_ECHO_INPUT
	err = windows.SetConsoleMode(windows.Handle(fd), newState)
	if err != nil {
		return "", err
	}
	defer windows.SetConsoleMode(windows.Handle(fd), state)

	// Read input
	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(input), nil
}

// CheckAdminPrivileges checks if running with administrator privileges
func CheckAdminPrivileges() bool {
	_, err := os.Open("\\\\.\\PHYSICALDRIVE0")
	return err == nil
}

// DownloadFile downloads a file from URL with progress reporting
func DownloadFile(logger *Logger, url, filepath string) error {
	logger.Info("Downloading from: %s", url)
	logger.Info("Saving to: %s", filepath)

	// Create the file
	out, err := os.Create(filepath)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer out.Close()

	// Get the data
	resp, err := http.Get(url)
	if err != nil {
		return fmt.Errorf("failed to download: %w", err)
	}
	defer resp.Body.Close()

	// Check server response
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("bad status: %s", resp.Status)
	}

	// Get file size
	size := resp.ContentLength
	logger.Info("File size: %.2f MB", float64(size)/(1024*1024))

	// Create progress reader
	counter := &WriteCounter{
		Total:  size,
		Logger: logger,
	}

	// Write the body to file with progress
	_, err = io.Copy(out, io.TeeReader(resp.Body, counter))
	if err != nil {
		return fmt.Errorf("failed to save file: %w", err)
	}

	logger.Info("Download completed successfully")
	return nil
}

// WriteCounter counts bytes written and reports progress
type WriteCounter struct {
	Total      int64
	Downloaded int64
	Logger     *Logger
	LastPrint  time.Time
}

func (wc *WriteCounter) Write(p []byte) (int, error) {
	n := len(p)
	wc.Downloaded += int64(n)

	// Print progress every second
	if time.Since(wc.LastPrint) > time.Second {
		wc.PrintProgress()
		wc.LastPrint = time.Now()
	}

	return n, nil
}

func (wc *WriteCounter) PrintProgress() {
	percent := float64(wc.Downloaded) / float64(wc.Total) * 100
	downloaded := float64(wc.Downloaded) / (1024 * 1024)
	total := float64(wc.Total) / (1024 * 1024)

	fmt.Printf("\r%sDownloading... %.2f MB / %.2f MB (%.1f%%)%s",
		ColorGreen, downloaded, total, percent, ColorReset)
}

// RunMSIInstaller runs the MSI installer with specified parameters
func RunMSIInstaller(logger *Logger, msiPath string, config *InstallConfig) error {
	logger.Info("Starting MSI installation...")
	logger.Info("MSI Path: %s", msiPath)

	// Build msiexec command
	// /i - install
	// /qn - quiet mode, no UI
	// /l*v - verbose logging
	args := []string{
		"/i", msiPath,
		"/qn",
		"/l*v", config.LogPath,
		"ADDLOCAL=ALL",
		fmt.Sprintf("CONSOLEPASSWORD=%s", config.ConsolePassword),
		fmt.Sprintf("DBPASSWORD=%s", config.DBPassword),
	}

	// Add install path if specified
	if config.InstallPath != "" {
		args = append(args, fmt.Sprintf("INSTALLDIR=%s", config.InstallPath))
	}

	// Log the command (without passwords)
	safeArgs := make([]string, len(args))
	copy(safeArgs, args)
	for i, arg := range safeArgs {
		if strings.Contains(arg, "PASSWORD=") {
			parts := strings.SplitN(arg, "=", 2)
			safeArgs[i] = parts[0] + "=********"
		}
	}
	logger.Info("Running command: msiexec %s", strings.Join(safeArgs, " "))

	// Execute msiexec
	cmd := exec.Command("msiexec", args...)

	// Capture stdout and stderr
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("failed to create stdout pipe: %w", err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("failed to create stderr pipe: %w", err)
	}

	// Start the command
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start installer: %w", err)
	}

	// Read stdout in goroutine
	go func() {
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			logger.Info("[INSTALLER] %s", scanner.Text())
		}
	}()

	// Read stderr in goroutine
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			logger.Warn("[INSTALLER] %s", scanner.Text())
		}
	}()

	// Wait for installation to complete
	logger.Info("Installation in progress... This may take several minutes.")
	logger.Info("Detailed logs are being written to: %s", config.LogPath)

	if err := cmd.Wait(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			logger.Error("Installation failed with exit code: %d", exitErr.ExitCode())
			return fmt.Errorf("installation failed with exit code %d", exitErr.ExitCode())
		}
		return fmt.Errorf("installation failed: %w", err)
	}

	logger.Info("Installation completed successfully!")
	return nil
}

// CheckPrerequisites checks system prerequisites
func CheckPrerequisites(logger *Logger) error {
	logger.Step("Checking Prerequisites")

	// Check Windows version
	version := windows.RtlGetVersion()
	logger.Info("Windows Version: %d.%d Build %d", version.MajorVersion, version.MinorVersion, version.BuildNumber)

	if version.MajorVersion < 10 && !(version.MajorVersion == 6 && version.MinorVersion >= 1) {
		return fmt.Errorf("unsupported Windows version. Requires Windows Server 2012 R2 or later")
	}

	// Check disk space
	var freeBytesAvailable, totalNumberOfBytes, totalNumberOfFreeBytes uint64
	path, _ := syscall.UTF16PtrFromString("C:\\")
	err := windows.GetDiskFreeSpaceEx(path, &freeBytesAvailable, &totalNumberOfBytes, &totalNumberOfFreeBytes)
	if err == nil {
		freeGB := float64(freeBytesAvailable) / (1024 * 1024 * 1024)
		logger.Info("Free disk space on C:\\: %.2f GB", freeGB)

		if freeGB < 20 {
			logger.Warn("Low disk space. Recommended minimum: 20 GB")
		}
	}

	// Check if running as administrator
	if !CheckAdminPrivileges() {
		return fmt.Errorf("this program must be run as Administrator")
	}
	logger.Info("Administrator privileges: OK")

	logger.Info("All prerequisites checks passed")
	return nil
}

// VerifyInstallation verifies the installation
func VerifyInstallation(logger *Logger) error {
	logger.Step("Verifying Installation")

	// Check if ESET services are installed
	services := []string{
		"ERA_Server",
		"ERA_Database",
	}

	for _, svc := range services {
		cmd := exec.Command("sc", "query", svc)
		output, err := cmd.CombinedOutput()
		if err != nil {
			logger.Warn("Service %s not found or not running", svc)
			continue
		}

		if strings.Contains(string(output), "RUNNING") {
			logger.Info("Service %s is running", svc)
		} else {
			logger.Warn("Service %s is not running", svc)
		}
	}

	// Check installation directory
	installDirs := []string{
		"C:\\Program Files\\ESET\\RemoteAdministrator\\Server",
		"C:\\Program Files\\ESET\\RemoteAdministrator\\Console",
	}

	for _, dir := range installDirs {
		if _, err := os.Stat(dir); err == nil {
			logger.Info("Installation directory found: %s", dir)
		} else {
			logger.Warn("Installation directory not found: %s", dir)
		}
	}

	return nil
}

func main() {
	// Create timestamp for log file
	timestamp := time.Now().Format("20060102-150405")
	logPath := filepath.Join(LogDirectory, fmt.Sprintf("eset-install-%s.log", timestamp))

	// Create logger
	logger, err := NewLogger(logPath)
	if err != nil {
		fmt.Printf("Failed to create logger: %v\n", err)
		os.Exit(1)
	}
	defer logger.Close()

	// Print banner
	logger.Info("========================================")
	logger.Info("ESET Protect On-Prem Installer")
	logger.Info("Windows All-in-One Installation")
	logger.Info("========================================")
	logger.Info("Log file: %s", logPath)
	logger.Info("")

	// Check prerequisites
	if err := CheckPrerequisites(logger); err != nil {
		logger.Error("Prerequisites check failed: %v", err)
		logger.Error("Installation aborted")
		os.Exit(1)
	}

	// Prompt for configuration
	logger.Step("Configuration")

	fmt.Println("\nPlease provide the following information:")
	fmt.Println("(Press Enter to use default values where applicable)")
	fmt.Println()

	consolePassword, err := PromptForInput("ESET Console Administrator Password: ", true)
	if err != nil {
		logger.Error("Failed to read password: %v", err)
		os.Exit(1)
	}

	consolePasswordConfirm, err := PromptForInput("Confirm Console Password: ", true)
	if err != nil {
		logger.Error("Failed to read password: %v", err)
		os.Exit(1)
	}

	if consolePassword != consolePasswordConfirm {
		logger.Error("Passwords do not match")
		os.Exit(1)
	}

	dbPassword, err := PromptForInput("Database Password: ", true)
	if err != nil {
		logger.Error("Failed to read password: %v", err)
		os.Exit(1)
	}

	dbPasswordConfirm, err := PromptForInput("Confirm Database Password: ", true)
	if err != nil {
		logger.Error("Failed to read password: %v", err)
		os.Exit(1)
	}

	if dbPassword != dbPasswordConfirm {
		logger.Error("Passwords do not match")
		os.Exit(1)
	}

	installPath, err := PromptForInput("Installation Path (press Enter for default): ", false)
	if err != nil {
		logger.Error("Failed to read input: %v", err)
		os.Exit(1)
	}

	config := &InstallConfig{
		ConsolePassword: consolePassword,
		DBPassword:      dbPassword,
		InstallPath:     installPath,
		LogPath:         filepath.Join(LogDirectory, fmt.Sprintf("eset-msi-%s.log", timestamp)),
	}

	logger.Info("Configuration collected successfully")

	// Download installer
	logger.Step("Downloading ESET Protect Installer")

	installerPath := filepath.Join(os.TempDir(), InstallerFileName)

	// Check if installer already exists
	if _, err := os.Stat(installerPath); err == nil {
		logger.Info("Installer already exists at: %s", installerPath)
		response, err := PromptForInput("Re-download installer? (y/N): ", false)
		if err == nil && strings.ToLower(response) == "y" {
			os.Remove(installerPath)
		} else {
			config.SkipDownload = true
		}
	}

	if !config.SkipDownload {
		if err := DownloadFile(logger, ESETInstallerURL, installerPath); err != nil {
			logger.Error("Failed to download installer: %v", err)
			logger.Error("Installation aborted")
			os.Exit(1)
		}
	}

	// Verify installer exists
	if _, err := os.Stat(installerPath); err != nil {
		logger.Error("Installer not found at: %s", installerPath)
		os.Exit(1)
	}

	fileInfo, _ := os.Stat(installerPath)
	logger.Info("Installer file size: %.2f MB", float64(fileInfo.Size())/(1024*1024))

	// Run installation
	logger.Step("Running Installation")

	if err := RunMSIInstaller(logger, installerPath, config); err != nil {
		logger.Error("Installation failed: %v", err)
		logger.Error("Please check the detailed log at: %s", config.LogPath)
		logger.Error("Installation aborted")
		os.Exit(1)
	}

	// Verify installation
	if err := VerifyInstallation(logger); err != nil {
		logger.Warn("Verification encountered issues: %v", err)
	}

	// Print completion message
	logger.Info("")
	logger.Info("========================================")
	logger.Info("Installation Complete!")
	logger.Info("========================================")
	logger.Info("")
	logger.Info("Web Console URL: https://%s:2223", getHostname())
	logger.Info("Username: Administrator")
	logger.Info("Password: <the password you provided>")
	logger.Info("")
	logger.Info("Installation logs:")
	logger.Info("  - Main log: %s", logPath)
	logger.Info("  - MSI log: %s", config.LogPath)
	logger.Info("")
	logger.Info("Please ensure Windows Firewall allows ports 2222 and 2223")
	logger.Info("")

	// Optional: Clean up installer
	response, err := PromptForInput("Delete installer file? (y/N): ", false)
	if err == nil && strings.ToLower(response) == "y" {
		os.Remove(installerPath)
		logger.Info("Installer file deleted")
	}

	logger.Info("Thank you for installing ESET Protect On-Prem!")
}

func getHostname() string {
	hostname, err := os.Hostname()
	if err != nil {
		return "localhost"
	}
	return hostname
}
