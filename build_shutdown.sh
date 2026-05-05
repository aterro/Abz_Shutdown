#!/usr/bin/env bash
#
# build_shutdown.sh - Standalone builder for ABZ_Shutdown.efi
# This script builds ABZ_Shutdown.efi on Linux, macOS, and Windows-hosted Bash environments
# Dependencies: GNU-EFI (headers/libs) and a matching GNU toolchain
#

set -euo pipefail

# Configuration
REQUESTED_ARCH="${1:-auto}"
SBAT_CSV="${SHUTDOWN_SBAT_CSV:-abz-shutdown.csv}"
BUILD_DIR="${BUILD_DIR:-.}"
CLEAN_BUILD="${CLEAN_BUILD:-0}"
BINARY_NAME="ABZ_Shutdown"
HOST_OS="$(uname -s)"
HOST_FAMILY="linux"

ARCH=""
ARCH_SHORT=""
GNUEFI_ARCH=""
CC="${CC:-}"
LD="${LD:-}"
OBJCOPY="${OBJCOPY:-}"
AR="${AR:-}"
RANLIB="${RANLIB:-}"
GNUEFI_INCLUDE_DIR="${GNUEFI_INCLUDE_DIR:-}"
GNUEFI_LIB_DIR="${GNUEFI_LIB_DIR:-}"
GNUEFI_PREFIX="${GNUEFI_PREFIX:-}"
LDSCRIPT="${LDSCRIPT:-}"
CRT0="${CRT0:-}"
FORMAT=""

case "$HOST_OS" in
    Darwin)
        HOST_FAMILY="macos"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        HOST_FAMILY="windows"
        ;;
esac

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

tool_exists() {
    local tool="${1:-}"

    [ -n "$tool" ] && { command -v "$tool" >/dev/null 2>&1 || [ -x "$tool" ]; }
}

show_help() {
    cat <<EOF
Usage: ./build_shutdown.sh [auto|x86_64|ia32|aarch64]

Builds ABZ_Shutdown.efi on Linux, macOS, and Windows-hosted Bash environments.

Environment variables:
  CLEAN_BUILD=1            Remove previous artifacts before building
  BUILD_DIR=path           Write outputs to a custom directory
  SHUTDOWN_SBAT_CSV=file   Optional SBAT CSV to embed
  TOOLCHAIN_PREFIX=prefix  Tool prefix such as x86_64-elf-
  GNUEFI_PREFIX=path       Prefix containing include/efi and lib/
  GNUEFI_INCLUDE_DIR=path  Override the GNU-EFI include directory
  GNUEFI_LIB_DIR=path      Override the GNU-EFI library directory
  CC/LD/OBJCOPY/AR/RANLIB  Override individual tools
EOF
}

show_install_hint() {
    case "$HOST_FAMILY" in
        macos)
            log_info "On macOS, install a GNU cross toolchain plus GNU-EFI, for example:"
            log_info "  brew install binutils"
            log_info "  brew install x86_64-elf-gcc   # or the matching <arch>-elf-gcc toolchain"
            log_info "Then point GNUEFI_PREFIX at the GNU-EFI install root if needed."
            ;;
        windows)
            log_info "On Windows, run this script from Git Bash or MSYS2 Bash."
            log_info "Install a GCC/binutils toolchain plus GNU-EFI in that environment."
            log_info "Common prefixes checked automatically include /usr, /mingw64, /ucrt64,"
            log_info "/clang64, /clangarm64, and /c/msys64/*."
            log_info "Set GNUEFI_PREFIX or TOOLCHAIN_PREFIX if your install lives elsewhere."
            ;;
        *)
            log_info "Install with: sudo apt-get install build-essential gnu-efi"
            ;;
    esac
}

# Detect architecture
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
            ARCH_SHORT="x64"
            GNUEFI_ARCH="x86_64"
            ;;
        i[3456789]86|ia32)
            ARCH="ia32"
            ARCH_SHORT="ia32"
            GNUEFI_ARCH="ia32"
            ;;
        aarch64|arm64)
            ARCH="aarch64"
            ARCH_SHORT="aa64"
            GNUEFI_ARCH="aarch64"
            ;;
        *)
            log_error "Unsupported architecture: $machine"
            exit 1
            ;;
    esac
    
    log_info "Building for architecture: $ARCH"
}

resolve_toolchain() {
    local prefixes=()
    local prefix

    if [ -z "$CC" ] || [ -z "$LD" ] || [ -z "$OBJCOPY" ] || [ -z "$AR" ] || [ -z "$RANLIB" ]; then
        if [ -n "${TOOLCHAIN_PREFIX:-}" ]; then
            prefixes+=("$TOOLCHAIN_PREFIX")
        fi

        case "$ARCH" in
            x86_64)
                if [ "$HOST_FAMILY" = "macos" ]; then
                    prefixes+=("x86_64-elf-" "x86_64-linux-gnu-" "")
                elif [ "$HOST_FAMILY" = "windows" ]; then
                    prefixes+=(
                        "/mingw64/bin/" "/ucrt64/bin/" "/clang64/bin/" "/usr/bin/"
                        "/c/msys64/mingw64/bin/" "/c/msys64/ucrt64/bin/" "/c/msys64/clang64/bin/" "/c/msys64/usr/bin/"
                        "" "x86_64-linux-gnu-" "x86_64-elf-"
                    )
                else
                    prefixes+=("" "x86_64-linux-gnu-" "x86_64-elf-")
                fi
                ;;
            ia32)
                if [ "$HOST_FAMILY" = "macos" ]; then
                    prefixes+=("i686-elf-" "i686-linux-gnu-" "")
                elif [ "$HOST_FAMILY" = "windows" ]; then
                    prefixes+=(
                        "/mingw32/bin/" "/usr/bin/" "/c/msys64/mingw32/bin/" "/c/msys64/usr/bin/"
                        "" "i686-linux-gnu-" "i686-elf-"
                    )
                else
                    prefixes+=("" "i686-linux-gnu-" "i686-elf-")
                fi
                ;;
            aarch64)
                if [ "$HOST_FAMILY" = "macos" ]; then
                    prefixes+=("aarch64-elf-" "aarch64-linux-gnu-" "")
                elif [ "$HOST_FAMILY" = "windows" ]; then
                    prefixes+=(
                        "/clangarm64/bin/" "/usr/bin/" "/c/msys64/clangarm64/bin/" "/c/msys64/usr/bin/"
                        "" "aarch64-linux-gnu-" "aarch64-elf-"
                    )
                else
                    prefixes+=("" "aarch64-linux-gnu-" "aarch64-elf-")
                fi
                ;;
        esac

        for prefix in "${prefixes[@]}"; do
            local candidate_cc="${CC:-${prefix}gcc}"
            local candidate_ld="${LD:-${prefix}ld}"
            local candidate_objcopy="${OBJCOPY:-${prefix}objcopy}"
            local candidate_ar="${AR:-${prefix}ar}"
            local candidate_ranlib="${RANLIB:-${prefix}ranlib}"

            if tool_exists "$candidate_cc" &&
               tool_exists "$candidate_ld" &&
               tool_exists "$candidate_objcopy" &&
               tool_exists "$candidate_ar" &&
               tool_exists "$candidate_ranlib"; then
                CC="$candidate_cc"
                LD="$candidate_ld"
                OBJCOPY="$candidate_objcopy"
                AR="$candidate_ar"
                RANLIB="$candidate_ranlib"
                break
            fi
        done
    fi

    local required_tools=("$CC" "$LD" "$OBJCOPY" "$AR" "$RANLIB")
    for tool in "${required_tools[@]}"; do
        if [ -z "$tool" ] || ! tool_exists "$tool"; then
            log_error "Required tool not found: ${tool:-<unset>}"
            show_install_hint
            exit 1
        fi
    done
}

resolve_gnuefi_paths() {
    local prefixes=()
    local prefix
    local include_dir
    local lib_dir
    local lib_candidates=()

    if [ -z "$GNUEFI_INCLUDE_DIR" ] || [ -z "$GNUEFI_LIB_DIR" ] || [ -z "$LDSCRIPT" ] || [ -z "$CRT0" ]; then
        if [ -n "$GNUEFI_PREFIX" ]; then
            prefixes+=("$GNUEFI_PREFIX")
        fi

        if [ "$HOST_FAMILY" = "windows" ]; then
            [ -n "${MSYSTEM_PREFIX:-}" ] && prefixes+=("$MSYSTEM_PREFIX")
            [ -n "${MINGW_PREFIX:-}" ] && prefixes+=("$MINGW_PREFIX")
            prefixes+=("/usr" "/mingw64" "/ucrt64" "/clang64" "/clangarm64" "/mingw32")
            prefixes+=("/c/msys64/usr" "/c/msys64/mingw64" "/c/msys64/ucrt64" "/c/msys64/clang64" "/c/msys64/clangarm64" "/c/msys64/mingw32")
        fi

        if [ "$HOST_FAMILY" = "macos" ] && command -v brew >/dev/null 2>&1; then
            prefixes+=("$(brew --prefix)")
        fi

        prefixes+=("/usr/local" "/opt/homebrew" "/opt/local" "/usr")

        for prefix in "${prefixes[@]}"; do
            [ -n "$prefix" ] || continue

            include_dir="${GNUEFI_INCLUDE_DIR:-$prefix/include/efi}"
            lib_candidates=(
                "${GNUEFI_LIB_DIR:-$prefix/lib}"
                "$prefix/lib64"
                "$prefix/lib/gnu-efi"
            )

            if [ ! -d "$include_dir" ]; then
                continue
            fi

            for lib_dir in "${lib_candidates[@]}"; do
                if [ -f "$lib_dir/libefi.a" ] &&
                   [ -f "$lib_dir/libgnuefi.a" ] &&
                   [ -f "${LDSCRIPT:-$lib_dir/elf_${ARCH}_efi.lds}" ] &&
                   [ -f "${CRT0:-$lib_dir/crt0-efi-${ARCH}.o}" ]; then
                    GNUEFI_INCLUDE_DIR="$include_dir"
                    GNUEFI_LIB_DIR="$lib_dir"
                    LDSCRIPT="${LDSCRIPT:-$lib_dir/elf_${ARCH}_efi.lds}"
                    CRT0="${CRT0:-$lib_dir/crt0-efi-${ARCH}.o}"
                    return
                fi
            done
        done
    fi

    if [ ! -d "$GNUEFI_INCLUDE_DIR" ]; then
        log_error "GNU-EFI headers not found"
        show_install_hint
        exit 1
    fi

    if [ ! -f "$GNUEFI_LIB_DIR/libefi.a" ] || [ ! -f "$GNUEFI_LIB_DIR/libgnuefi.a" ]; then
        log_error "GNU-EFI libraries not found in $GNUEFI_LIB_DIR"
        show_install_hint
        exit 1
    fi

    if [ ! -f "$LDSCRIPT" ] || [ ! -f "$CRT0" ]; then
        log_error "GNU-EFI linker support files not found"
        show_install_hint
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    resolve_toolchain
    resolve_gnuefi_paths
    log_info "Using toolchain: CC=$CC LD=$LD OBJCOPY=$OBJCOPY"
    log_info "Using GNU-EFI: include=$GNUEFI_INCLUDE_DIR lib=$GNUEFI_LIB_DIR"
    log_info "All dependencies found!"
}

# Set compiler flags
setup_flags() {
    # Optimization and safety flags
    local libgcc_file
    local sdk_root=""

    OPTIMFLAGS=(-Os -fno-strict-aliasing -fno-tree-loop-distribute-patterns)
    CFLAGS=("${OPTIMFLAGS[@]}" -fno-stack-protector -fshort-wchar -Wall -DMDEPKG_NDEBUG)
    
    # GNU-EFI specific flags
    GNUEFI_CFLAGS=(-fpic "-I$GNUEFI_INCLUDE_DIR" "-I$GNUEFI_INCLUDE_DIR/$GNUEFI_ARCH" "-I$GNUEFI_INCLUDE_DIR/protocol")

    if [ "$HOST_FAMILY" = "macos" ]; then
        sdk_root="${SDKROOT:-}"
        if [ -z "$sdk_root" ] && command -v xcrun >/dev/null 2>&1; then
            sdk_root="$(xcrun --sdk macosx --show-sdk-path)"
        fi

        if [ -n "$sdk_root" ] && [ -d "$sdk_root/usr/include" ]; then
            GNUEFI_CFLAGS+=("-isystem" "$sdk_root/usr/include")
        fi
    fi
    
    # Architecture specific flags
    case "$ARCH" in
        x86_64)
            CFLAGS+=(-DEFIX64 -DEFI_FUNCTION_WRAPPER -m64 -mno-red-zone)
            FORMAT="--target=efi-app-x86_64"
            ;;
        ia32)
            CFLAGS+=(-DEFI32 -DEFI_FUNCTION_WRAPPER -m32)
            FORMAT="--target=efi-app-ia32"
            ;;
        aarch64)
            CFLAGS+=(-DEFIAARCH64)
            FORMAT="--target=efi-app-aarch64"
            ;;
    esac
    
    CFLAGS+=(-D__MAKEWITH_GNUEFI)
    ALL_CFLAGS=("${CFLAGS[@]}" "${GNUEFI_CFLAGS[@]}")
    libgcc_file="$("$CC" --print-libgcc-file-name)"

    if [ ! -f "$libgcc_file" ]; then
        log_error "Unable to locate libgcc via $CC"
        exit 1
    fi

    LIBGCC_FILE="$libgcc_file"
    
    log_info "Compilation flags configured"
}

# Build the binary
build_binary() {
    local source="shutdown.c"
    local object="$BUILD_DIR/shutdown.o"
    local shared="$BUILD_DIR/${BINARY_NAME}_${ARCH_SHORT}.so"
    local binary="$BUILD_DIR/${BINARY_NAME}_${ARCH_SHORT}.efi"
    
    if [ ! -f "$source" ]; then
        log_error "Source file $source not found"
        exit 1
    fi

    mkdir -p "$BUILD_DIR"
    
    if [ "$CLEAN_BUILD" = "1" ]; then
        log_info "Cleaning previous build artifacts..."
        rm -f "$object" "$shared" "$binary" "$BUILD_DIR"/ABZ_Shutdown_*.efi "$BUILD_DIR"/ABZ_Shutdown_*.so
    fi
    
    # Compile
    log_info "Compiling $source..."
    "$CC" "${ALL_CFLAGS[@]}" -c "$source" -o "$object"
    if [ ! -f "$object" ]; then
        log_error "Compilation failed"
        exit 1
    fi
    
    # Link (shared object)
    log_info "Linking $shared..."
    "$LD" -T "$LDSCRIPT" -shared -Bsymbolic -nostdlib -L"$GNUEFI_LIB_DIR" "$CRT0" \
        -znocombreloc -zdefs "$object" -o "$shared" -lefi -lgnuefi "$LIBGCC_FILE"
    
    if [ ! -f "$shared" ]; then
        log_error "Linking failed"
        exit 1
    fi
    
    # Convert to EFI binary
    log_info "Converting to EFI binary: $binary..."
    "$OBJCOPY" -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rodata \
               -j .rel -j .rela -j .rel.* -j .rela.* -j .rel* -j .rela* \
               -j .reloc --strip-unneeded $FORMAT "$shared" "$binary"
    
    if [ ! -f "$binary" ]; then
        log_error "Binary conversion failed"
        exit 1
    fi
    
    # Add SBAT section if file exists
    if [ -f "$SBAT_CSV" ]; then
        log_info "Adding SBAT section..."
        "$OBJCOPY" --add-section .sbat="$SBAT_CSV" \
                   --adjust-section-vma .sbat+10000000 "$binary"
    else
        log_warn "SBAT CSV file not found at $SBAT_CSV (optional)"
    fi
    
    chmod a-x "$binary"
    log_info "Build complete: $binary"
}

# Main
main() {
    if [ "$REQUESTED_ARCH" = "--help" ] || [ "$REQUESTED_ARCH" = "-h" ]; then
        show_help
        exit 0
    fi

    echo "================================"
    echo "  ABZ_Shutdown.efi Build Script"
    echo "================================"
    echo
    log_info "Host OS detected: $HOST_OS"

    detect_arch
    check_dependencies
    setup_flags
    build_binary
    
    echo
    log_info "Build successful!"
    echo "Binary: $BUILD_DIR/${BINARY_NAME}_${ARCH_SHORT}.efi"
}

main "$@"
