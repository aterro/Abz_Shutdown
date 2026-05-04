#!/bin/bash
#
# build_shutdown.sh - Standalone builder for ABZ_Shutdown.efi
# This script builds ABZ_Shutdown.efi independently from rEFInd
# Dependencies: GNU-EFI (gnuefi, efi headers)
#

set -e

# Configuration
ARCH="${1:-x86_64}"
SBAT_CSV="${SHUTDOWN_SBAT_CSV:-refind-sbat.csv}"
BUILD_DIR="${BUILD_DIR:-.}"
CLEAN_BUILD="${CLEAN_BUILD:-0}"
BINARY_NAME="ABZ_Shutdown"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    local required_tools=("gcc" "objcopy" "ld" "ar" "ranlib")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool not found. Please install build-essential."
            exit 1
        fi
    done
    
    # Check for GNU-EFI headers
    if [ ! -d "/usr/include/efi" ]; then
        log_error "GNU-EFI headers not found at /usr/include/efi"
        log_info "Install with: sudo apt-get install gnu-efi"
        exit 1
    fi
    
    # Check for GNU-EFI libraries
    if [ ! -f "/usr/lib/libefi.so" ] && [ ! -f "/usr/lib/libefi.a" ]; then
        log_error "GNU-EFI library not found at /usr/lib"
        log_info "Install with: sudo apt-get install gnu-efi"
        exit 1
    fi
    
    log_info "All dependencies found!"
}

# Detect architecture
detect_arch() {
    local machine=$(uname -m)
    case "$machine" in
        x86_64)
            ARCH="x86_64"
            ARCH_SHORT="x64"
            EFIARCH="EFIX64"
            GNUEFI_ARCH="x86_64"
            TARGET_TRIPLE="x86_64-linux-gnu"
            ;;
        i[3456789]86)
            ARCH="ia32"
            ARCH_SHORT="ia32"
            EFIARCH="EFI32"
            GNUEFI_ARCH="ia32"
            TARGET_TRIPLE="i686-linux-gnu"
            ;;
        aarch64)
            ARCH="aarch64"
            ARCH_SHORT="aa64"
            EFIARCH="EFIAARCH64"
            GNUEFI_ARCH="aarch64"
            TARGET_TRIPLE="aarch64-linux-gnu"
            ;;
        *)
            log_error "Unsupported architecture: $machine"
            exit 1
            ;;
    esac
    
    log_info "Building for architecture: $ARCH"
}

# Set compiler flags
setup_flags() {
    # Optimization and safety flags
    OPTIMFLAGS="-Os -fno-strict-aliasing -fno-tree-loop-distribute-patterns"
    CFLAGS="$OPTIMFLAGS -fno-stack-protector -fshort-wchar -Wall -DMDEPKG_NDEBUG"
    
    # GNU-EFI specific flags
    GNUEFI_CFLAGS="-fpic -I/usr/include/efi -I/usr/include/efi/$GNUEFI_ARCH -I/usr/include/efi/protocol"
    
    # Architecture specific flags
    case "$ARCH" in
        x86_64)
            CFLAGS="$CFLAGS -DEFIX64 -DEFI_FUNCTION_WRAPPER -m64 -mno-red-zone"
            FORMAT="--target=efi-app-x86_64"
            LDSCRIPT="/usr/lib/elf_x86_64_efi.lds"
            CRT0="/usr/lib/crt0-efi-x86_64.o"
            ;;
        ia32)
            CFLAGS="$CFLAGS -DEFIx32 -DEFI_FUNCTION_WRAPPER -m32"
            FORMAT="--target=efi-app-ia32"
            LDSCRIPT="/usr/lib/elf_i386_efi.lds"
            CRT0="/usr/lib/crt0-efi-ia32.o"
            ;;
        aarch64)
            CFLAGS="$CFLAGS -DEFIAARCH64"
            FORMAT="--target=efi-app-aarch64"
            LDSCRIPT="/usr/lib/elf_aarch64_efi.lds"
            CRT0="/usr/lib/crt0-efi-aarch64.o"
            ;;
    esac
    
    CFLAGS="$CFLAGS -D__MAKEWITH_GNUEFI"
    ALL_CFLAGS="$CFLAGS $GNUEFI_CFLAGS"
    
    log_info "Compilation flags configured"
}

# Build the binary
build_binary() {
    local source="shutdown.c"
    local object="shutdown.o"
    local shared="${BINARY_NAME}_${ARCH_SHORT}.so"
    local binary="${BINARY_NAME}_${ARCH_SHORT}.efi"
    
    if [ ! -f "$source" ]; then
        log_error "Source file $source not found"
        exit 1
    fi
    
    if [ "$CLEAN_BUILD" = "1" ]; then
        log_info "Cleaning previous build artifacts..."
        rm -f "$object" "$shared" "$binary" ABZ_Shutdown_*.efi ABZ_Shutdown_*.so
    fi
    
    # Compile
    log_info "Compiling $source..."
    gcc $ALL_CFLAGS -c "$source" -o "$object"
    if [ ! -f "$object" ]; then
        log_error "Compilation failed"
        exit 1
    fi
    
    # Link (shared object)
    log_info "Linking $shared..."
    ld -T "$LDSCRIPT" -shared -Bsymbolic -nostdlib -L/usr/lib -L/usr/lib "$CRT0" \
        -znocombreloc -zdefs "$object" -o "$shared" -lefi -lgnuefi \
        /usr/lib/gcc/$TARGET_TRIPLE/*/libgcc.a 2>/dev/null || \
    ld -T "$LDSCRIPT" -shared -Bsymbolic -nostdlib -L/usr/lib -L/usr/lib "$CRT0" \
        -znocombreloc -zdefs "$object" -o "$shared" -lefi -lgnuefi \
        $(gcc --print-libgcc-file-name)
    
    if [ ! -f "$shared" ]; then
        log_error "Linking failed"
        exit 1
    fi
    
    # Convert to EFI binary
    log_info "Converting to EFI binary: $binary..."
    objcopy -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rodata \
            -j .rel -j .rela -j .rel.* -j .rela.* -j .rel* -j .rela* \
            -j .reloc --strip-unneeded $FORMAT "$shared" "$binary"
    
    if [ ! -f "$binary" ]; then
        log_error "Binary conversion failed"
        exit 1
    fi
    
    # Add SBAT section if file exists
    if [ -f "$SBAT_CSV" ]; then
        log_info "Adding SBAT section..."
        objcopy --add-section .sbat="$SBAT_CSV" \
                --adjust-section-vma .sbat+10000000 "$binary"
    else
        log_warn "SBAT CSV file not found at $SBAT_CSV (optional)"
    fi
    
    chmod a-x "$binary"
    log_info "Build complete: $binary"
}

# Main
main() {
    echo "================================"
    echo "  ABZ_Shutdown.efi Build Script"
    echo "================================"
    echo
    
    check_dependencies
    detect_arch
    setup_flags
    build_binary
    
    echo
    log_info "Build successful!"
    echo "Binary: ./${BINARY_NAME}_${ARCH_SHORT}.efi"
}

main "$@"
