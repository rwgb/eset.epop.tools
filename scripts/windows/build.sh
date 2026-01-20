#!/bin/bash

# Build script for ESET Protect Windows Installer
# Can be run on Linux/macOS to cross-compile

set -e

echo "========================================"
echo "Building ESET Protect Windows Installer"
echo "Cross-compiling for Windows"
echo "========================================"
echo

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "ERROR: Go is not installed"
    echo "Please install Go from https://golang.org/dl/"
    exit 1
fi

echo "Go version:"
go version
echo

# Download dependencies
echo "Downloading dependencies..."
go mod download
echo

# Build for Windows
echo "Building executable for Windows (amd64)..."
GOOS=windows GOARCH=amd64 go build -ldflags "-s -w" -o eset-protect-installer.exe install-eset-windows.go
echo

# Get file size
if [[ "$OSTYPE" == "darwin"* ]]; then
    SIZE=$(ls -lh eset-protect-installer.exe | awk '{print $5}')
else
    SIZE=$(ls -lh eset-protect-installer.exe | awk '{print $5}')
fi

echo "========================================"
echo "Build completed successfully!"
echo "========================================"
echo
echo "Executable: eset-protect-installer.exe"
echo "Size: $SIZE"
echo
echo "Transfer this file to your Windows Server and run as Administrator"
echo
