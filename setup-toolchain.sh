#!/bin/bash
#
# setup-toolchain.sh - Set up cross-compiler toolchain symlinks for ABZ_Shutdown
#
# This script creates symlinks to MacPorts tools in the ./bin/ directory
# allowing the build to work without modifying PATH or MacPorts installations.
#

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$PROJECT_DIR/bin"
MACPORTS_BIN="/opt/local/bin"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

echo "=========================================="
echo "  ABZ_Shutdown Toolchain Setup"
echo "=========================================="
echo

# Check if MacPorts bin directory exists
if [ ! -d "$MACPORTS_BIN" ]; then
    log_error "MacPorts /opt/local/bin not found!"
    log_warn "Please install MacPorts and required tools:"
    echo "  sudo port install x86_64-elf-gcc i686-elf-gcc \\"
    echo "    x86_64-w64-mingw32-binutils i686-w64-mingw32-binutils"
    exit 1
fi

# Create bin directory if it doesn't exist
mkdir -p "$BIN_DIR"

# Tools to symlink
declare -a TOOLS=(
    "x86_64-elf-gcc"
    "x86_64-elf-ld"
    "x86_64-w64-mingw32-objcopy"
    "i686-elf-gcc"
    "i686-elf-ld"
    "i686-w64-mingw32-objcopy"
)

# Check for required tools and create symlinks
missing=0
for tool in "${TOOLS[@]}"; do
    if [ ! -x "$MACPORTS_BIN/$tool" ]; then
        log_error "Missing: $tool (not found in $MACPORTS_BIN)"
        missing=$((missing + 1))
    else
        # Create symlink if it doesn't exist
        if [ ! -e "$BIN_DIR/$tool" ]; then
            ln -s "$MACPORTS_BIN/$tool" "$BIN_DIR/$tool"
            log_info "Symlinked $tool"
        elif [ -L "$BIN_DIR/$tool" ]; then
            log_info "Already symlinked: $tool"
        else
            log_warn "File exists (not a symlink): $BIN_DIR/$tool"
        fi
    fi
done

echo
if [ $missing -eq 0 ]; then
    log_info "All required tools are available!"
    echo
    echo "You can now build with:"
    echo "  ./build_all_with_ports.sh"
    echo
    exit 0
else
    log_error "$missing tool(s) not found"
    log_warn "Install missing tools with:"
    echo "  sudo port install x86_64-elf-gcc i686-elf-gcc \\"
    echo "    x86_64-w64-mingw32-binutils i686-w64-mingw32-binutils"
    exit 1
fi
