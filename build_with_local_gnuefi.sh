#!/usr/bin/env bash
#
# build_with_local_gnuefi.sh - Build ABZ_Shutdown with local GNU-EFI files
# This wrapper supports both a bundled in-project gnuefi/ directory and an
# external GNU-EFI source tree.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_GNUEFI_ROOT=""
REQUESTED_ARCH="${1:-auto}"

if [ -d "$SCRIPT_DIR/gnuefi/inc" ] && [ -d "$SCRIPT_DIR/gnuefi/lib" ]; then
    DEFAULT_GNUEFI_ROOT="$SCRIPT_DIR/gnuefi"
elif [ -d "$SCRIPT_DIR/../gnu-efi" ]; then
    DEFAULT_GNUEFI_ROOT="$(cd "$SCRIPT_DIR/../gnu-efi" && pwd)"
else
    DEFAULT_GNUEFI_ROOT="$SCRIPT_DIR/gnuefi"
fi

GNUEFI_ROOT="${GNUEFI_ROOT:-$DEFAULT_GNUEFI_ROOT}"

fail() {
    echo "ERROR: $1" >&2
    exit 1
}

detect_arch() {
    local machine

    if [ "$REQUESTED_ARCH" = "auto" ]; then
        machine="$(uname -m)"
    else
        machine="$REQUESTED_ARCH"
    fi

    case "$machine" in
        x86_64)
            ARCH="x86_64"
            ;;
        i[3456789]86|ia32)
            ARCH="ia32"
            ;;
        aarch64|arm64)
            ARCH="aarch64"
            ;;
        --help|-h|help)
            exec "$SCRIPT_DIR/build_shutdown.sh" "$@"
            ;;
        *)
            fail "Unsupported architecture: $machine"
            ;;
    esac
}

is_bundled_layout() {
    [ -d "$GNUEFI_ROOT/inc" ] && [ -d "$GNUEFI_ROOT/lib/$ARCH" ]
}

is_source_layout() {
    [ -d "$GNUEFI_ROOT/inc" ] && [ -d "$GNUEFI_ROOT/$ARCH" ] && [ -d "$GNUEFI_ROOT/gnuefi" ]
}

bundled_layout_complete() {
    [ -f "$GNUEFI_ROOT/inc/efi.h" ] &&
    [ -f "$GNUEFI_ROOT/lib/$ARCH/libefi.a" ] &&
    [ -f "$GNUEFI_ROOT/lib/$ARCH/libgnuefi.a" ] &&
    [ -f "$GNUEFI_ROOT/lib/$ARCH/elf_${ARCH}_efi.lds" ] &&
    [ -f "$GNUEFI_ROOT/lib/$ARCH/crt0-efi-${ARCH}.o" ]
}

detect_arch "$@"

echo "Using GNU-EFI from: $GNUEFI_ROOT"
echo "Building for architecture: $ARCH"

# Configure paths for bundled files in the project or for a source tree build.
if is_bundled_layout && bundled_layout_complete; then
    export GNUEFI_INCLUDE_DIR="$GNUEFI_ROOT/inc"
    export GNUEFI_LIB_DIR="$GNUEFI_ROOT/lib/$ARCH"
    export LDSCRIPT="$GNUEFI_LIB_DIR/elf_${ARCH}_efi.lds"
    export CRT0="$GNUEFI_LIB_DIR/crt0-efi-${ARCH}.o"
elif is_source_layout; then
    if [ ! -f "$GNUEFI_ROOT/$ARCH/lib/libefi.a" ] || [ ! -f "$GNUEFI_ROOT/$ARCH/gnuefi/libgnuefi.a" ]; then
        if [ ! -f "$GNUEFI_ROOT/Makefile" ] && [ ! -f "$GNUEFI_ROOT/makefile" ]; then
            fail "GNU-EFI source tree at $GNUEFI_ROOT is not built and has no Makefile"
        fi

        echo "GNU-EFI not built yet. Building now..."
        (cd "$GNUEFI_ROOT" && make)

        if [ ! -f "$GNUEFI_ROOT/$ARCH/gnuefi/libefi.a" ]; then
            ln -sf ../lib/libefi.a "$GNUEFI_ROOT/$ARCH/gnuefi/libefi.a"
        fi
    fi

    export GNUEFI_INCLUDE_DIR="$GNUEFI_ROOT/inc"
    export GNUEFI_LIB_DIR="$GNUEFI_ROOT/$ARCH/gnuefi"
    export LDSCRIPT="$GNUEFI_ROOT/gnuefi/elf_${ARCH}_efi.lds"
    export CRT0="$GNUEFI_ROOT/$ARCH/gnuefi/crt0-efi-${ARCH}.o"
else
    echo "Bundled GNU-EFI for $ARCH is incomplete or unavailable; falling back to build_shutdown.sh auto-detection."
fi

if [ -n "${GNUEFI_INCLUDE_DIR:-}" ]; then
    for required_file in \
        "$GNUEFI_INCLUDE_DIR/efi.h" \
        "$GNUEFI_LIB_DIR/libefi.a" \
        "$GNUEFI_LIB_DIR/libgnuefi.a" \
        "$LDSCRIPT" \
        "$CRT0"
    do
        [ -f "$required_file" ] || fail "Required GNU-EFI file not found: $required_file"
    done
fi

echo "Building ABZ_Shutdown.efi..."
exec "$SCRIPT_DIR/build_shutdown.sh" "$@"
