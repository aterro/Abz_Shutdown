#!/bin/bash
# install-macports-dependencies.sh - Install complete toolchain dependencies for ABZ_Shutdown

set -euo pipefail

# Color output definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error(){ echo -e "${RED}[✗]${NC} $1"; }

echo "==========================================="
echo "  Installing ABZ_Shutdown Port Packages"
echo "==========================================="

# Save the original user identity if invoked through sudo
SUDO_USER_NAME="${SUDO_USER:-$USER}"

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
echo

# Interactive compilation trigger section
if [ -t 0 ]; then
    read -r -p "Would you like to run the setup toolchain and build the project now? [y/N]: " run_ans
    case "$run_ans" in
        [Yy]* )
            echo
            log_info "Stepping into setup and build routines..."
            
            # Drop root permissions for safety if running under sudo
            if [ "$SUDO_USER_NAME" != "root" ]; then
                log_info "Dropping root privileges. Running build scripts as: $SUDO_USER_NAME"
                sudo -u "$SUDO_USER_NAME" ./setup-toolchain.sh
                sudo -u "$SUDO_USER_NAME" ./build_via_macports_on_mac.sh
            else
                ./setup-toolchain.sh
                ./build_via_macports_on_mac.sh
            fi
            ;;
        *)
            log_warn "Build pipeline skipped. You can manually execute later using:"
            echo "  ./setup-toolchain.sh && ./build_via_macports_on_mac.sh"
            ;;
    esac
else
    log_warn "Non-interactive session detected; skipping auto-execution prompt."
    echo "Run manually using: ./setup-toolchain.sh && ./build_via_macports_on_mac.sh"
fi
