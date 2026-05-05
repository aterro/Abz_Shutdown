#!/usr/bin/env bash
#
# build_with_local_gnuefi.sh - Build ABZ_Shutdown with local gnu-efi sources
# This wrapper script sets up the environment to use the local gnu-efi installation
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GNUEFI_ROOT="${GNUEFI_ROOT:-$(cd "$SCRIPT_DIR/../gnu-efi" && pwd)}"

# Detect architecture
ARCH="$(uname -m | sed 's/i[3456789]86/ia32/')"

echo "Using GNU-EFI from: $GNUEFI_ROOT"
echo "Building for architecture: $ARCH"

# Verify gnu-efi is built
if [ ! -f "$GNUEFI_ROOT/$ARCH/lib/libefi.a" ] || [ ! -f "$GNUEFI_ROOT/$ARCH/gnuefi/libgnuefi.a" ]; then
    echo "GNU-EFI not built yet. Building now..."
    (cd "$GNUEFI_ROOT" && make)
    
    # Create symlink if needed
    if [ ! -f "$GNUEFI_ROOT/$ARCH/gnuefi/libefi.a" ]; then
        ln -sf ../lib/libefi.a "$GNUEFI_ROOT/$ARCH/gnuefi/libefi.a"
    fi
fi

# Find the linker script
LDSCRIPT="$GNUEFI_ROOT/gnuefi/elf_${ARCH}_efi.lds"
if [ ! -f "$LDSCRIPT" ]; then
    echo "ERROR: Linker script not found: $LDSCRIPT"
    exit 1
fi

# Set environment and build
export GNUEFI_INCLUDE_DIR="$GNUEFI_ROOT/inc"
export GNUEFI_LIB_DIR="$GNUEFI_ROOT/$ARCH/gnuefi"
export LDSCRIPT="$LDSCRIPT"
export CRT0="$GNUEFI_ROOT/$ARCH/gnuefi/crt0-efi-${ARCH}.o"

echo "Building ABZ_Shutdown.efi..."
exec "$SCRIPT_DIR/build_shutdown.sh" "$@"
