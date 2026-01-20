@echo off
REM Build script for ESET Protect Windows Installer

echo ========================================
echo Building ESET Protect Windows Installer
echo ========================================
echo.

REM Check if Go is installed
where go >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Go is not installed or not in PATH
    echo Please install Go from https://golang.org/dl/
    exit /b 1
)

echo Go version:
go version
echo.

REM Download dependencies
echo Downloading dependencies...
go mod download
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to download dependencies
    exit /b 1
)
echo.

REM Build the executable
echo Building executable...
go build -ldflags "-s -w" -o eset-protect-installer.exe install-eset-windows.go
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Build failed
    exit /b 1
)
echo.

echo ========================================
echo Build completed successfully!
echo ========================================
echo.
echo Executable: eset-protect-installer.exe
echo.
echo To run the installer:
echo   1. Right-click eset-protect-installer.exe
echo   2. Select "Run as Administrator"
echo.
pause
