#!/usr/bin/env bash
#
# build_via_macports_on_mac.sh - Build ABZ_Shutdown for all architectures
# Usage: ./build_via_macports_on_mac.sh [x64|ia32|aa64|all]
#
# ================================================================================
# TOOLS (Bundled in ./bin/)
# ================================================================================
#
# This script uses pre-compiled cross-compiler tools bundled in the ./bin/
# directory. No external installation required!
#
# Bundled tools:
#   x86_64:   x86_64-elf-gcc, x86_64-elf-ld, x86_64-w64-mingw32-objcopy
#   ia32:     i386-elf-gcc, i386-elf-ld, i386-w64-mingw32-objcopy  
#   aarch64:  aarch64-none-elf-gcc, aarch64-none-elf-ld, aarch64-none-elf-objcopy
#
# Tool source:
#   - x86_64/ia32: MacPorts
#   - aarch64: ARM GNU Toolchain 15.2.rel1
#
# Note on mingw objcopy:
#   The mingw binutils provide PE/COFF format support needed for converting
#   ELF shared objects to PE EFI executables. The native ELF objcopy tools
#   lack PE format support.
#
# ================================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_LOG="$PROJECT_DIR/build.log"
TOOLCHAIN_BIN="$PROJECT_DIR/bin"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$BUILD_LOG"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$BUILD_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$BUILD_LOG"
}

log_section() {
    echo -e "\n${BLUE}================================${NC}" | tee -a "$BUILD_LOG"
    echo -e "${BLUE}  $1${NC}" | tee -a "$BUILD_LOG"
    echo -e "${BLUE}================================${NC}\n" | tee -a "$BUILD_LOG"
}

check_bundled_tools() {
    local required_tools=("x86_64-elf-gcc" "x86_64-elf-ld" "x86_64-w64-mingw32-objcopy" \
                         "i386-elf-gcc" "i386-elf-ld" "i386-w64-mingw32-objcopy")
    local missing=()
    local has_aarch64=0

    for tool in "${required_tools[@]}"; do
        if [ ! -x "$TOOLCHAIN_BIN/$tool" ]; then
            missing+=("$tool")
        fi
    done

    # Check for aarch64 tools (optional)
    if [ -x "$TOOLCHAIN_BIN/aarch64-none-elf-gcc" ]; then
        has_aarch64=1
        export AARCH64_PREFIX="aarch64-none-elf"
    elif [ -x "$TOOLCHAIN_BIN/aarch64-elf-gcc" ]; then
        has_aarch64=1
        export AARCH64_PREFIX="aarch64-elf"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required tools in $TOOLCHAIN_BIN: ${missing[*]}"

        # Suggest MacPorts packages to install (aggregate by architecture/toolset)
        local pkgs=()
        if printf '%s\n' "${missing[@]}" | grep -q 'x86_64-elf'; then
            pkgs+=("x86_64-elf-gcc")
        fi
        if printf '%s\n' "${missing[@]}" | grep -q 'i386-elf'; then
            pkgs+=("i386-elf-gcc")
        fi
        if printf '%s\n' "${missing[@]}" | grep -q 'x86_64-w64-mingw32'; then
            pkgs+=("x86_64-w64-mingw32-binutils")
        fi
        if printf '%s\n' "${missing[@]}" | grep -q 'i386-w64-mingw32'; then
            pkgs+=("i686-w64-mingw32-binutils")
        fi

        # aarch64: MacPorts provides binutils but not gcc. Suggest binutils and recommend ARM GNU Toolchain
        if [ $has_aarch64 -eq 0 ]; then
            pkgs+=("aarch64-elf-binutils")
            suggest_arm_toolchain=1
        fi

        # Deduplicate package list
        unique_pkgs=()
        for p in "${pkgs[@]}"; do
            found=0
            for q in "${unique_pkgs[@]:-}"; do
                if [ "$q" = "$p" ]; then
                    found=1
                    break
                fi
            done
            if [ $found -eq 0 ]; then
                unique_pkgs+=("$p")
            fi
        done

        if [ ${#unique_pkgs[@]} -gt 0 ]; then
            log_info "Install missing tools via MacPorts (run as root):"
            echo "  sudo port install ${unique_pkgs[*]}" | tee -a "$BUILD_LOG"
            log_info "Then run: ./setup-toolchain.sh && ./build_via_macports_on_mac.sh"

            if [ "${suggest_arm_toolchain:-0}" -eq 1 ]; then
                log_info "Note on aarch64: MacPorts provides aarch64 binutils but not aarch64 GCC."
                log_info "Recommended: download ARM GNU Toolchain and symlink its aarch64-* tools into ./bin/:"
                echo "  https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads" | tee -a "$BUILD_LOG"
                echo "Examples:" | tee -a "$BUILD_LOG"
                echo "  macOS (Intel): arm-gnu-toolchain-11.3.rel1-darwin-x86_64-aarch64-none-elf.tar.xz" | tee -a "$BUILD_LOG"
                echo "  macOS (Intel newer): arm-gnu-toolchain-12.2.rel1-darwin-x86_64-aarch64-none-elf.tar.xz" | tee -a "$BUILD_LOG"
                echo "  macOS (Apple Silicon): arm-gnu-toolchain-15.2.rel1-darwin-arm64-aarch64-none-elf.tar.xz" | tee -a "$BUILD_LOG"
                echo "After extracting, cd into the extracted 'bin/' and ln -sf <tool> $TOOLCHAIN_BIN/ to make tools available." | tee -a "$BUILD_LOG"
            fi
        else
            log_info "No obvious MacPorts package mapping for the missing tools. See Macports.md for manual instructions."
        fi

        log_error "Bundled toolchain is incomplete."
        return 1
    fi

    export SKIP_AARCH64=$((1 - has_aarch64))
    [ $has_aarch64 -eq 1 ] && log_info "aarch64 tools found: using ${AARCH64_PREFIX}"

    # Add toolchain bin to PATH
    export PATH="$TOOLCHAIN_BIN:$PATH"
    log_info "Using bundled cross-compiler tools from ./bin/"
    return 0
}

build_x64() {
    log_section "Building x86_64"

    cd "$PROJECT_DIR"
    if OBJCOPY=x86_64-w64-mingw32-objcopy ./build_shutdown.sh x86_64 2>&1 | tee -a "$BUILD_LOG"; then
        log_info "✓ x86_64 build successful"
        [ -f "ABZ_Shutdown_x64.efi" ] && log_info "Output: ABZ_Shutdown_x64.efi ($(stat -f%z 'ABZ_Shutdown_x64.efi' 2>/dev/null))"
        return 0
    else
        log_error "✗ x86_64 build failed"
        return 1
    fi
}

build_ia32() {
    log_section "Building ia32 (i386)"

    cd "$PROJECT_DIR"
    if OBJCOPY=i386-w64-mingw32-objcopy ./build_shutdown.sh ia32 2>&1 | tee -a "$BUILD_LOG"; then
        log_info "✓ ia32 build successful"
        [ -f "ABZ_Shutdown_ia32.efi" ] && log_info "Output: ABZ_Shutdown_ia32.efi ($(stat -f%z 'ABZ_Shutdown_ia32.efi' 2>/dev/null))"
        return 0
    else
        log_error "✗ ia32 build failed"
        return 1
    fi
}

build_aa64() {
    log_section "Building aarch64"

    if [ "${SKIP_AARCH64:-1}" = "1" ]; then
        log_warn "aarch64 tools not found in ./bin/"
        log_info "To build for aarch64, download ARM GNU Toolchain for macOS:"
        log_info "  https://developer.arm.com/downloads/-/gnu-a"
        log_info "  Look for: arm-gnu-toolchain-15.2.rel1-darwin-*-aarch64-none-elf"
        return 0
    fi

    cd "$PROJECT_DIR"
    if CC="${AARCH64_PREFIX}-gcc" \
       LD="${AARCH64_PREFIX}-ld" \
       OBJCOPY="${AARCH64_PREFIX}-objcopy" \
       AR="${AARCH64_PREFIX}-ar" \
       RANLIB="${AARCH64_PREFIX}-ranlib" \
       ./build_aarch64.sh aarch64 2>&1 | tee -a "$BUILD_LOG"; then
        log_info "✓ aarch64 build successful"
        [ -f "ABZ_Shutdown_aa64.efi" ] && log_info "Output: ABZ_Shutdown_aa64.efi ($(stat -f%z 'ABZ_Shutdown_aa64.efi' 2>/dev/null) bytes)"
        return 0
    else
        log_error "✗ aarch64 build failed"
        return 1
    fi
}

show_usage() {
    cat << EOF
Usage: $0 [ARCH]

Architectures:
  x64, x86_64     Build x86_64 only
  ia32, i386      Build ia32 only
  aa64, aarch64   Build aarch64 only
  all             Build all three architectures (default)

Examples:
  $0              # Build all architectures
  $0 all          # Build all architectures
  $0 x64          # Build x86_64 only
  $0 ia32         # Build ia32 only
  $0 aa64         # Build aarch64 only

================================================================================
ABOUT THIS BUILD SYSTEM
================================================================================

This project includes bundled cross-compiler toolchains in ./bin/ for all
three architectures. No external tools or package managers needed!

Included toolchains:
  • x86_64 (x86_64-elf-gcc): 64-bit x86 EFI
  • ia32 (i386-elf-gcc): 32-bit x86 EFI
  • aarch64 (aarch64-none-elf-gcc): ARM 64-bit EFI

The build produces three PE/COFF EFI binaries:
  • ABZ_Shutdown_x64.efi   (x86_64 architecture)
  • ABZ_Shutdown_ia32.efi  (32-bit x86 architecture)
  • ABZ_Shutdown_aa64.efi  (ARM 64-bit architecture)

Note on objcopy:
  The mingw binutils (x86_64-w64-mingw32-objcopy, i386-w64-mingw32-objcopy)
  are used for PE/COFF format conversion to EFI. These provide the PE format
  support that standard ELF objcopy tools lack.

================================================================================

EOF
}

main() {
    local arch="${1:-all}"

    # Initialize log
    > "$BUILD_LOG"
    log_info "ABZ_Shutdown build script with bundled toolchain"
    log_info "Project directory: $PROJECT_DIR"
    log_info "Toolchain directory: $TOOLCHAIN_BIN"
    log_info "Log file: $BUILD_LOG"

    # Check tools
    if ! check_bundled_tools; then
        exit 1
    fi

    local failed=0

    case "$arch" in
        x64|x86_64)
            build_x64 || failed=1
            ;;
        ia32|i386)
            build_ia32 || failed=1
            ;;
        aa64|aarch64)
            build_aa64 || failed=1
            ;;
        all)
            build_x64 || failed=1
            build_ia32 || failed=1
            if [ "${SKIP_AARCH64:-1}" = "0" ]; then
                build_aa64 || failed=1
            else
                build_aa64  # Show info message about aarch64
            fi
            ;;
        help|-h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown architecture: $arch"
            show_usage
            exit 1
            ;;
    esac

    log_section "Build Summary"
    if [ $failed -eq 0 ]; then
        log_info "✓ All requested builds completed successfully!"
        echo -e "\n${GREEN}Output files:${NC}"
        cd "$PROJECT_DIR"
        [ -f "ABZ_Shutdown_x64.efi" ] && echo "  • ABZ_Shutdown_x64.efi ($(stat -f%z 'ABZ_Shutdown_x64.efi' 2>/dev/null) bytes)"
        [ -f "ABZ_Shutdown_ia32.efi" ] && echo "  • ABZ_Shutdown_ia32.efi ($(stat -f%z 'ABZ_Shutdown_ia32.efi' 2>/dev/null) bytes)"
        [ -f "ABZ_Shutdown_aa64.efi" ] && echo "  • ABZ_Shutdown_aa64.efi ($(stat -f%z 'ABZ_Shutdown_aa64.efi' 2>/dev/null) bytes)"
        exit 0
    else
        log_error "✗ One or more builds failed. Check $BUILD_LOG for details."
        exit 1
    fi
}

main "$@"
