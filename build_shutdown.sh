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
USE_PROOT=0

# If building for aarch64, delegate to build_aarch64.sh
if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ] || [ "${1:-auto}" = "aarch64" ] || [ "${1:-auto}" = "arm64" ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    exec "$script_dir/build_aarch64.sh" "$@"
fi

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
GNUEFI_LIBEFI_A="${GNUEFI_LIBEFI_A:-}"
GNUEFI_LIBGNUEFI_A="${GNUEFI_LIBGNUEFI_A:-}"
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

    [ -n "$tool" ] && { command -v "$tool" >/dev/null 2>&1 || [ -x "$tool" ] || [ -x "${tool}.exe" ]; }
}

is_termux() {
    [ -n "${TERMUX_VERSION:-}" ] || [ "${PREFIX:-}" = "/data/data/com.termux/files/usr" ]
}

has_proot_distro() {
    command -v proot-distro >/dev/null 2>&1
}

has_proot_debian() {
    [ -d "/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian" ]
}

proot_debian_has_efi_tools() {
    local test_objcopy
    test_objcopy="$(proot-distro login debian -- which objcopy 2>/dev/null || true)"
    [ -n "$test_objcopy" ] && proot-distro login debian -- objcopy --help 2>&1 | grep -q "efi-app"
}

run_tool() {
    if [ "$USE_PROOT" = "1" ]; then
        proot-distro login debian -- sh -c "cd '$PWD' && $(printf '%q ' "$@")"
    else
        "$@"
    fi
}

show_objcopy_hint() {
    local target="${1:-}"

    log_info "Set OBJCOPY to a GNU objcopy that can build $target output."

    if is_termux || [ "$ARCH" = "aarch64" ]; then
        log_info "On Termux, first try: pkg install build-essential"
        log_info "Then verify support with: objcopy --help | grep efi-app"
        log_info "If that still shows no EFI targets, use a Debian/Ubuntu proot and install:"
        log_info "  apt-get update && apt-get install build-essential gnu-efi binutils"
        log_info "Then rebuild there or point OBJCOPY at the proot's GNU objcopy."
    fi
}

first_existing_file() {
    local candidate

    for candidate in "$@"; do
        [ -f "$candidate" ] && {
            printf '%s\n' "$candidate"
            return 0
        }
    done

    return 1
}

set_gnuefi_paths() {
    GNUEFI_INCLUDE_DIR="$1"
    GNUEFI_LIB_DIR="$2"
    LDSCRIPT="$3"
    CRT0="$4"
    GNUEFI_LIBEFI_A="${5:-$2/libefi.a}"
    GNUEFI_LIBGNUEFI_A="${6:-$2/libgnuefi.a}"
}

resolve_objcopy_format() {
    local required_target=""
    local bfd_target=""

    [ -z "$FORMAT" ] && return 0

    case "$ARCH" in
        ia32)    bfd_target="pei-i386" ;;
        x86_64)  bfd_target="pei-x86-64" ;;
        aarch64) bfd_target="pei-aarch64-little" ;;
        *)       return 0 ;;
    esac

    if run_tool "$OBJCOPY" --help 2>&1 | grep "supported targets:" | grep -q "$bfd_target"; then
        return 0
    fi

    log_warn "$OBJCOPY lacks $bfd_target support, searching for alternative objcopy..."
    local alt
    for alt in x86_64-elf-objcopy aarch64-elf-objcopy; do
        if tool_exists "$alt" && "$alt" --help 2>&1 | grep "supported targets:" | grep -q "$bfd_target"; then
            OBJCOPY="$alt"
            log_info "Using alternative objcopy: $OBJCOPY"
            return 0
        fi
    done

    if command -v brew >/dev/null 2>&1; then
        local brew_gobjcopy="$(brew --prefix)/opt/binutils/bin/gobjcopy"
        if [ -x "$brew_gobjcopy" ] && "$brew_gobjcopy" --help 2>&1 | grep "supported targets:" | grep -q "$bfd_target"; then
            OBJCOPY="$brew_gobjcopy"
            log_info "Using alternative objcopy: $OBJCOPY"
            return 0
        fi
    fi

    log_warn "No objcopy with $bfd_target support found. Will attempt section-based conversion."
    FORMAT=""
}

try_bundled_gnuefi_root() {
    local root="${1:-}"
    local bundled_inc="$root/inc"
    local bundled_lib="$root/lib/$ARCH"

    if [ -d "$bundled_inc" ] &&
       [ -f "$bundled_lib/libefi.a" ] &&
       [ -f "$bundled_lib/libgnuefi.a" ] &&
       [ -f "$bundled_lib/elf_${ARCH}_efi.lds" ] &&
       [ -f "$bundled_lib/crt0-efi-${ARCH}.o" ]; then
        set_gnuefi_paths \
            "$bundled_inc" \
            "$bundled_lib" \
            "$bundled_lib/elf_${ARCH}_efi.lds" \
            "$bundled_lib/crt0-efi-${ARCH}.o"
        return 0
    fi

    return 1
}

try_source_gnuefi_root() {
    local root="${1:-}"
    local include_dir="$root/inc"
    local libefi_a=""
    local libgnuefi_a=""
    local crt0_a=""
    local ldscript_a=""
    local lib_dir=""

    [ -d "$include_dir" ] || return 1

    libefi_a="$(first_existing_file \
        "$root/$ARCH/gnuefi/libefi.a" \
        "$root/$ARCH/lib/libefi.a")" || return 1
    libgnuefi_a="$(first_existing_file \
        "$root/$ARCH/gnuefi/libgnuefi.a" \
        "$root/$ARCH/lib/libgnuefi.a")" || return 1
    crt0_a="$(first_existing_file \
        "$root/$ARCH/gnuefi/crt0-efi-${ARCH}.o" \
        "$root/$ARCH/lib/crt0-efi-${ARCH}.o")" || return 1
    ldscript_a="$(first_existing_file \
        "$root/gnuefi/elf_${ARCH}_efi.lds" \
        "$root/$ARCH/gnuefi/elf_${ARCH}_efi.lds" \
        "$root/$ARCH/lib/elf_${ARCH}_efi.lds")" || return 1

    lib_dir="$(dirname "$libgnuefi_a")"
    set_gnuefi_paths "$include_dir" "$lib_dir" "$ldscript_a" "$crt0_a" "$libefi_a" "$libgnuefi_a"
    return 0
}

is_gnuefi_source_root() {
    local root="${1:-}"

    [ -d "$root/inc" ] && [ -d "$root/gnuefi" ] && [ -f "$root/Makefile" ]
}

build_local_gnuefi_tree() {
    local root="${1:-}"
    local as_tool=""

    case "$CC" in
        *gcc)
            as_tool="${CC%gcc}as"
            ;;
        *clang)
            as_tool="$CC"
            ;;
        *)
            as_tool="as"
            ;;
    esac

    log_info "Building local GNU-EFI tree in $root"
    make -C "$root" \
        ARCH="$ARCH" \
        CC="$CC" \
        AS="$as_tool" \
        LD="$LD" \
        AR="$AR" \
        RANLIB="$RANLIB" \
        OBJCOPY="$OBJCOPY"
}

show_help() {
    cat <<EOF
Usage: ./build_shutdown.sh [auto|x86_64|ia32|aarch64]

Builds ABZ_Shutdown.efi on Linux, macOS, and Windows-hosted Bash environments.

Environment variables:
  CLEAN_BUILD=1            Remove previous artifacts before building
  BUILD_DIR=path           Write outputs to a custom directory
  SHUTDOWN_SBAT_CSV=file   Optional SBAT CSV to embed
  PROOT_SETUP=1            Enable proot Debian environment on Termux (interactive)
  PROOT_AUTO_INSTALL=1     Auto-answer 'yes' to proot setup prompts (non-interactive)
  TOOLCHAIN_PREFIX=prefix  Tool prefix such as x86_64-elf-
  GNUEFI_PREFIX=path       Prefix containing include/efi and lib/
                           or a local GNU-EFI tree (gnuefi/ or gnu-efi/)
  GNUEFI_INCLUDE_DIR=path  Override the GNU-EFI include directory
  GNUEFI_LIB_DIR=path      Override the GNU-EFI library directory
  CC/LD/OBJCOPY/AR/RANLIB  Override individual tools

Package hints:
  Linux/Debian/Ubuntu      apt-get install build-essential gnu-efi
  Termux                   pkg install build-essential
  Termux/proot             apt-get install build-essential gnu-efi binutils
EOF
}

ask_yes_no() {
    local prompt="$1"
    local response
    
    # If running non-interactively or auto-install is enabled, return true
    if [ "${PROOT_AUTO_INSTALL:-0}" = "1" ]; then
        log_info "Auto-install enabled, proceeding..."
        return 0
    fi
    
    # Check if we're running in a non-interactive environment
    if [ ! -t 0 ]; then
        log_warn "Non-interactive mode detected, skipping prompt."
        return 1
    fi
    
    while true; do
        printf "%s [y/n]: " "$prompt"
        read -r response
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "Please answer yes (y) or no (n)."
                ;;
        esac
    done
}

setup_proot_debian() {
    if ! is_termux; then
        return 1
    fi

    if ! has_proot_distro; then
        echo
        log_warn "proot-distro is not installed."
        log_info "To build EFI binaries on Termux, you need proot-distro with a Debian environment."
        echo
        if ! ask_yes_no "Do you want to install proot-distro now?"; then
            log_info "Skipping proot-distro installation."
            return 1
        fi
        
        log_info "Installing proot-distro..."
        pkg install -y proot-distro || {
            log_error "Failed to install proot-distro"
            return 1
        }
    fi

    if ! has_proot_debian; then
        echo
        log_warn "Debian proot distribution is not installed."
        log_info "A Debian environment (~500MB download) is needed for EFI build tools."
        echo
        if ! ask_yes_no "Do you want to install Debian proot distribution now?"; then
            log_info "Skipping Debian installation."
            return 1
        fi
        
        log_info "Installing Debian proot distribution..."
        proot-distro install debian || {
            log_error "Failed to install Debian proot"
            return 1
        }
    fi

    if ! proot_debian_has_efi_tools; then
        echo
        log_warn "Build tools are not installed in Debian proot."
        log_info "Installing build-essential, gnu-efi, and binutils (~300MB)."
        echo
        if ! ask_yes_no "Do you want to install the build tools now?"; then
            log_info "Skipping build tools installation."
            return 1
        fi
        
        log_info "Installing build tools in Debian proot..."
        proot-distro login debian -- apt-get update || true
        proot-distro login debian -- apt-get install -y build-essential gnu-efi binutils || {
            log_error "Failed to install tools in Debian proot"
            return 1
        }
    fi

    log_info "Proot Debian environment ready with EFI build tools"
    return 0
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
            if is_termux || [ "$ARCH" = "aarch64" ]; then
                log_info "On Termux/aarch64, objcopy lacks EFI target support."
                if has_proot_distro && has_proot_debian; then
                    log_info "Detected proot-distro with Debian installed."
                    log_info "Run with interactive setup: PROOT_SETUP=1 ./build_shutdown.sh"
                    log_info "Or auto-install mode: PROOT_SETUP=1 PROOT_AUTO_INSTALL=1 ./build_shutdown.sh"
                else
                    log_info "Solution: Use proot-distro with Debian environment."
                    log_info "Interactive setup: PROOT_SETUP=1 ./build_shutdown.sh"
                    log_info "Auto-install (non-interactive): PROOT_SETUP=1 PROOT_AUTO_INSTALL=1 ./build_shutdown.sh"
                    log_info ""
                    log_info "Or manually setup:"
                    log_info "  pkg install proot-distro"
                    log_info "  proot-distro install debian"
                    log_info "  proot-distro login debian"
                    log_info "  apt-get update && apt-get install build-essential gnu-efi binutils"
                fi
            else
                log_info "Install with: sudo apt-get install build-essential gnu-efi"
            fi
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

    # If the compiler produces COFF/PE objects (e.g. mingw32 GCC on Windows),
    # try to find an LLVM/clang toolchain that can produce ELF output compatible
    # with the bundled GNU-EFI libraries.
    # Detection: mingw32 targets produce COFF; check via gcc -v (Target: *mingw32)
    local compiler_is_mingw=0
    if [ -n "$CC" ]; then
        run_tool "$CC" -v 2>&1 | grep -qi "mingw32" && compiler_is_mingw=1
    fi

    if [ "$compiler_is_mingw" -eq 1 ]; then
        local llvm_found=0

        find_llvm_toolchain() {
            local dir="$1"
            local cc="${LLVM_CC:-$dir/clang}"
            local ld="${LLVM_LD:-$dir/ld.lld}"
            local objcopy="${LLVM_OBJCOPY:-$dir/llvm-objcopy}"
            local ar="${LLVM_AR:-$dir/llvm-ar}"
            local ranlib="${LLVM_RANLIB:-$dir/llvm-ranlib}"

            if tool_exists "$cc" && tool_exists "$ld" &&
               tool_exists "$objcopy" && tool_exists "$ar" &&
               tool_exists "$ranlib"; then
                log_info "Switching to LLVM/LLD toolchain at $dir (produces ELF, compatible with GNU-EFI)"
                CC="$cc"
                LD="$ld"
                OBJCOPY="$objcopy"
                AR="$ar"
                RANLIB="$ranlib"
                return 0
            fi
            return 1
        }

        # Save original tools in case LLVM objcopy doesn't support EFI format
        local orig_objcopy="$OBJCOPY"

        # 1) User override via LLVM_PREFIX
        if [ "$llvm_found" -eq 0 ] && [ -n "${LLVM_PREFIX:-}" ] && [ -d "$LLVM_PREFIX" ]; then
            find_llvm_toolchain "$LLVM_PREFIX" && llvm_found=1
        fi

        # 2) Common installation directories (checked before PATH to avoid MSYS2's own clang/ld.lld
        #    which may not accept GNU-style ELF linker flags like -T)
        if [ "$llvm_found" -eq 0 ]; then
            local common_dirs=()
            case "$HOST_FAMILY" in
                windows)
                    common_dirs=(
                        "/c/LLVM/bin"
                        "/c/Program Files/LLVM/bin"
                        "c:/LLVM/bin"
                        "c:/Program Files/LLVM/bin"
                    )
                    if [ -n "${LOCALAPPDATA:-}" ]; then
                        local appdata_dir
                        appdata_dir="$(cygpath -u "$LOCALAPPDATA" 2>/dev/null || echo "$LOCALAPPDATA")"
                        common_dirs+=("$appdata_dir/Programs/LLVM/bin")
                    fi
                    for msys_root in /c/msys64 /c/msys32; do
                        [ -d "$msys_root" ] && common_dirs+=("$msys_root/clang64/bin" "$msys_root/clangarm64/bin")
                    done
                    for drive_root in /c /d /e; do
                        [ -d "$drive_root/LLVM/bin" ] && common_dirs+=("$drive_root/LLVM/bin")
                    done
                    ;;
                macos)
                    common_dirs=(
                        "/usr/local/opt/llvm/bin"
                        "/opt/homebrew/opt/llvm/bin"
                    )
                    for d in /usr/local/Cellar/llvm/*/bin; do
                        [ -d "$d" ] && common_dirs+=("$d")
                    done
                    ;;
                linux)
                    for d in /usr/lib/llvm-*/bin /usr/lib/llvm/*/bin /usr/local/llvm*/bin; do
                        [ -d "$d" ] && common_dirs+=("$d")
                    done
                    ;;
            esac

            for dir in "${common_dirs[@]}"; do
                find_llvm_toolchain "$dir" && { llvm_found=1; break; }
            done
        fi

        # 3) Fall back to PATH
        if [ "$llvm_found" -eq 0 ] && command -v clang >/dev/null 2>&1; then
            local clang_dir
            clang_dir="$(dirname "$(command -v clang)")"
            find_llvm_toolchain "$clang_dir" && llvm_found=1
        fi

        if [ "$llvm_found" -eq 1 ]; then
            # LLVM objcopy lacks efi-app target support; use original (mingw32) objcopy instead
            if tool_exists "$orig_objcopy"; then
                OBJCOPY="$orig_objcopy"
            fi
        else
            log_warn "mingw32 toolchain detected (produces COFF objects, not ELF)"
            log_warn "GNU-EFI libraries are ELF format. Install LLVM/clang for ELF cross-compilation."
            log_warn "Set LLVM_PREFIX to the directory containing clang, ld.lld, llvm-objcopy, etc."
        fi
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
    local local_roots=()
    local include_dir
    local lib_dir
    local lib_candidates=()
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [ -z "$GNUEFI_INCLUDE_DIR" ] || [ -z "$GNUEFI_LIB_DIR" ] || [ -z "$LDSCRIPT" ] || [ -z "$CRT0" ]; then
        if [ -n "$GNUEFI_PREFIX" ]; then
            local_roots+=("$GNUEFI_PREFIX")
        fi

        local_roots+=(
            "$script_dir/gnuefi"
            "$script_dir/gnu-efi"
            "$script_dir/../gnuefi"
            "$script_dir/../gnu-efi"
        )

        for prefix in "${local_roots[@]}"; do
            [ -d "$prefix" ] || continue

            if try_bundled_gnuefi_root "$prefix"; then
                log_info "Using local bundled GNU-EFI files from $prefix"
                return
            fi

            if try_source_gnuefi_root "$prefix"; then
                log_info "Using local GNU-EFI build tree from $prefix"
                return
            fi

            if is_gnuefi_source_root "$prefix"; then
                if build_local_gnuefi_tree "$prefix" && try_source_gnuefi_root "$prefix"; then
                    log_info "Using freshly built local GNU-EFI tree from $prefix"
                    return
                fi
                log_warn "Found local GNU-EFI source tree at $prefix but could not prepare build artifacts"
            fi
        done

        [ -n "$GNUEFI_PREFIX" ] && prefixes+=("$GNUEFI_PREFIX")
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
                    set_gnuefi_paths \
                        "$include_dir" \
                        "$lib_dir" \
                        "${LDSCRIPT:-$lib_dir/elf_${ARCH}_efi.lds}" \
                        "${CRT0:-$lib_dir/crt0-efi-${ARCH}.o}"
                    return
                fi
            done
        done
    fi

    GNUEFI_LIBEFI_A="${GNUEFI_LIBEFI_A:-$GNUEFI_LIB_DIR/libefi.a}"
    GNUEFI_LIBGNUEFI_A="${GNUEFI_LIBGNUEFI_A:-$GNUEFI_LIB_DIR/libgnuefi.a}"

    if [ ! -d "$GNUEFI_INCLUDE_DIR" ]; then
        log_error "GNU-EFI headers not found"
        show_install_hint
        exit 1
    fi

    if [ ! -f "$GNUEFI_LIBEFI_A" ] || [ ! -f "$GNUEFI_LIBGNUEFI_A" ]; then
        log_error "GNU-EFI libraries not found (libefi=$GNUEFI_LIBEFI_A libgnuefi=$GNUEFI_LIBGNUEFI_A)"
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
    if [ "$USE_PROOT" = "1" ]; then
        log_info "Build mode: Using proot Debian environment for EFI toolchain"
    fi
    log_info "All dependencies found!"
}

# Set compiler flags
setup_flags() {
    # Optimization and safety flags
    local libgcc_file
    local sdk_root=""

    OPTIMFLAGS=(-Os -fno-strict-aliasing)
    # Add GCC-specific flag only if using GCC (not clang)
    if run_tool "$CC" --version 2>&1 | grep -q "gcc"; then
        OPTIMFLAGS+=(-fno-tree-loop-distribute-patterns)
    fi
    CFLAGS=("${OPTIMFLAGS[@]}" -ffreestanding -fno-stack-protector -fshort-wchar -Wall -Wno-unused-function -DMDEPKG_NDEBUG)
    
    # GNU-EFI specific flags
    GNUEFI_CFLAGS=(-fpic "-I$GNUEFI_INCLUDE_DIR" "-I$GNUEFI_INCLUDE_DIR/$GNUEFI_ARCH" "-I$GNUEFI_INCLUDE_DIR/protocol")

    if [ "$HOST_FAMILY" = "macos" ]; then
        sdk_root="${SDKROOT:-}"
        if [ -z "$sdk_root" ] && command -v xcrun >/dev/null 2>&1; then
            sdk_root="$(xcrun --sdk macosx --show-sdk-path)"
        fi

        if [ -n "$sdk_root" ] && [ -d "$sdk_root/usr/include" ]; then
            if run_tool "$CC" --version 2>&1 | grep -qi "apple clang"; then
                GNUEFI_CFLAGS+=("-isystem" "$sdk_root/usr/include")
            fi
        fi
    fi
    
    # Architecture specific flags
    case "$ARCH" in
        x86_64)
            CFLAGS+=(-DEFIX64 -DEFI_FUNCTION_WRAPPER -m64 -mno-red-zone)
            FORMAT="-O efi-app-x86_64"
            ;;
        ia32)
            CFLAGS+=(-DEFI32 -DEFI_FUNCTION_WRAPPER -m32)
            FORMAT="-O efi-app-ia32"
            ;;
        aarch64)
            CFLAGS+=(-DEFIAARCH64)
            FORMAT="-O pei-aarch64-little --subsystem efi-app"
            ;;
    esac

    # Detect objcopy type - llvm-objcopy doesn't support --target for EFI
    if run_tool "$OBJCOPY" --version 2>&1 | grep -iq "llvm-objcopy"; then
        log_info "Detected llvm-objcopy (will use default binary conversion without EFI target flag)"
        FORMAT=""
    fi

    # Verify objcopy supports the required EFI target format
    resolve_objcopy_format

    # When using clang as a cross-compiler, add the target triple.
    # Skip when building natively (host machine matches target arch).
    local host_machine
    host_machine="$(uname -m)"
    if run_tool "$CC" --version 2>&1 | grep -iq "clang"; then
        case "$ARCH" in
            x86_64)  { [ "$host_machine" != "x86_64" ] || [ "$HOST_FAMILY" = "windows" ]; } && CFLAGS+=(--target=x86_64-unknown-elf)   ;;
            ia32)    { [ "$host_machine" != "i686" ]   || [ "$HOST_FAMILY" = "windows" ]; } && CFLAGS+=(--target=i686-unknown-elf)      ;;
            aarch64) { { [ "$host_machine" != "aarch64" ] && [ "$host_machine" != "arm64" ]; } || [ "$HOST_FAMILY" = "windows" ]; } && CFLAGS+=(--target=aarch64-unknown-elf)  ;;
        esac
    fi
    
    CFLAGS+=(-D__MAKEWITH_GNUEFI)
    ALL_CFLAGS=("${CFLAGS[@]}" "${GNUEFI_CFLAGS[@]}")

    # libgcc is only needed for GCC (ELF cross-compilers provide it; clang ELF targets do not)
    LIBGCC_FILE=""
    if run_tool "$CC" --version 2>&1 | grep -qi "gcc"; then
        libgcc_file="$(run_tool "$CC" --print-libgcc-file-name)"
        if [ -z "$libgcc_file" ]; then
            log_error "Unable to locate libgcc via $CC"
            exit 1
        fi
        if [ "$USE_PROOT" != "1" ] && [ ! -f "$libgcc_file" ]; then
            log_error "Unable to locate libgcc file: $libgcc_file"
            exit 1
        fi
        LIBGCC_FILE="$libgcc_file"
    fi
    
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
    run_tool "$CC" "${ALL_CFLAGS[@]}" -c "$source" -o "$object" 2>&1 | grep -v "warning:" || true
    if [ ! -f "$object" ]; then
        log_error "Compilation failed"
        exit 1
    fi
    
    # Link (shared object)
    log_info "Linking $shared..."
    
    # Detect linker type and set appropriate flags
    local ld_flags=(-T "$LDSCRIPT" -shared -Bsymbolic -nostdlib)
    local z_flags=(-z noexecstack -znocombreloc)
    
    # LLD (LLVM linker) needs -z norelro to avoid relro section issues
    if run_tool "$LD" --version 2>&1 | grep -q "LLD"; then
        z_flags=(-z norelro -z noexecstack -znocombreloc)
    fi
    
    local ld_libs=("$GNUEFI_LIBEFI_A" "$GNUEFI_LIBGNUEFI_A")
    if [ -n "$LIBGCC_FILE" ]; then
        ld_libs+=("$LIBGCC_FILE")
    fi
    run_tool "$LD" "${ld_flags[@]}" "${z_flags[@]}" "$CRT0" "$object" -o "$shared" \
        "${ld_libs[@]}" 2>&1 | grep -v "warning:" || true
    
    if [ ! -f "$shared" ]; then
        log_error "Linking failed"
        echo
        if [ "$ARCH" = "aarch64" ] && [ "$(uname -m)" != "aarch64" ] && [ "$(uname -m)" != "arm64" ]; then
            log_info "Cross-compiling for aarch64 from $(uname -m) requires:"
            log_info "  sudo apt-get install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu"
            log_info ""
            log_info "Also ensure aarch64 GNU-EFI libraries are available (bundled or system)."
            echo
        fi
        show_install_hint
        exit 1
    fi
    
    # Convert to EFI binary using objcopy
    log_info "Converting to EFI binary: $binary..."
    local objcopy_output=""
    local objcopy_rc=0

    set +e
    if [ -z "$FORMAT" ]; then
        # llvm-objcopy: include .dynstr since it's referenced by .dynamic
        objcopy_output=$(run_tool "$OBJCOPY" -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .dynstr -j .rodata \
                         -j .rel -j .rela -j .rel.* -j .rela.* -j .rel* -j .rela* \
                         -j .reloc --strip-unneeded "$shared" "$binary" 2>&1)
    else
        # GNU objcopy with EFI target format
        objcopy_output=$(run_tool "$OBJCOPY" -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rodata \
                         -j .rel -j .rela -j .rel.* -j .rela.* -j .rel* -j .rela* \
                         -j .reloc --strip-unneeded $FORMAT "$shared" "$binary" 2>&1)
    fi
    objcopy_rc=$?
    set -e

    printf '%s\n' "$objcopy_output" | grep -v "warning:" || true

    if [ "$objcopy_rc" -ne 0 ] || [ ! -f "$binary" ]; then
        log_error "Binary conversion failed"
        show_objcopy_hint "$FORMAT"
        exit 1
    fi

    if ! head -c 2 "$binary" | grep -q "^MZ"; then
        log_error "Binary conversion produced a non-EFI output (missing MZ header). Check the selected objcopy tool."
        show_objcopy_hint "$FORMAT"
        exit 1
    fi
    
    # Add SBAT section if file exists
    if [ -f "$SBAT_CSV" ]; then
        log_info "Adding SBAT section..."
        if [ -z "$FORMAT" ]; then
            # llvm-objcopy doesn't support --adjust-section-vma on non-relocatable files
            run_tool "$OBJCOPY" --add-section .sbat="$SBAT_CSV" "$binary" 2>/dev/null || \
                log_warn "SBAT section addition failed with llvm-objcopy (this is usually safe to ignore)"
        else
            run_tool "$OBJCOPY" --add-section .sbat="$SBAT_CSV" \
                       --adjust-section-vma .sbat+10000000 "$binary"
        fi
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
