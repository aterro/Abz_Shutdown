#!/bin/bash
# install-macports-dependencies.sh - Install complete toolchain dependencies for ABZ_Shutdown

set -euo pipefail

# Color output definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error(){ echo -e "${RED}[✗]${NC} $1"; }

echo "==========================================="
echo "  Installing ABZ_Shutdown Port Packages"
echo "==========================================="

# Ensure the script is run with sudo/root privileges
if [ "$EUID" -ne 0 ]; then
    log_error "Please run this script using sudo:"
    echo "  sudo $0"
    exit 1
fi

# Verify the port command is globally available
if ! command -v port >/dev/null 2>&1; then
    log_error "MacPorts ('port' command) not found. Please install it first from:"
    echo "  https://macports.org"
    exit 1
fi

log_info "Updating MacPorts registry packages..."
port selfupdate

log_info "Installing toolchain cross-compilers and utilities..."
port install mingw-w64 x86_64-elf-gcc i386-elf-gcc aarch64-elf-binutils

log_info "All MacPorts package dependencies successfully installed!"
echo "You can now run your setup workflow:"
echo "  ./setup-toolchain.sh && ./build_via_macports_on_mac.sh"
