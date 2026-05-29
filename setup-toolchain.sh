#!/bin/bash
# setup-toolchain.sh - Set up cross-compiler toolchain symlinks for ABZ_Shutdown
# Creates symlinks to MacPorts or local toolchains in ./bin and can offer to
# install missing packages via MacPorts when running interactively.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$PROJECT_DIR/bin"
MACPORTS_BIN="/opt/local/bin"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error(){ echo -e "${RED}[✗]${NC} $1"; }

cat <<'HDR'
==========================================
  ABZ_Shutdown Toolchain Setup
==========================================
HDR

# If MacPorts isn't installed at all, offer a helper to open the install page
if [ ! -d "$MACPORTS_BIN" ]; then
    log_warn "MacPorts not found at $MACPORTS_BIN — will still look for tools in PATH."
    if [ -t 0 ]; then
        read -r -p "MacPorts not detected. Open MacPorts install page in your browser? [y/N]: " mp_ans
        case "$mp_ans" in
            [Yy]* )
                if command -v open >/dev/null 2>&1; then
                    open "https://www.macports.org/install.php"
                else
                    echo "Please visit: https://www.macports.org/install.php"
                fi
                ;;
            *)
                log_warn "Skipping opening MacPorts page. You can install MacPorts manually: https://www.macports.org/install.php"
                ;;
        esac
    else
        log_warn "Non-interactive session; see https://www.macports.org/install.php to install MacPorts."
    fi
fi

# Ensure bin directory exists
mkdir -p "$BIN_DIR"

# Helper function to find files with wildcard support safely
find_executable() {
    local pattern="$1"
    # Try literal path first
    if [ -x "$MACPORTS_BIN/$pattern" ]; then
        echo "$MACPORTS_BIN/$pattern"
        return 0
    fi
    # Use standard shell expansion to check for wildcards in MacPorts folder
    # Disable exit on error temporarily in case no expansion matches
    set +e
    local matches=( $MACPORTS_BIN/$pattern )
    set -e
    if [ -x "${matches[0]}" ]; then
        echo "${matches[0]}"
        return 0
    fi
    # Search system PATH natively via command -v
    if command -v "$pattern" >/dev/null 2>&1; then
        command -v "$pattern"
        return 0
    fi
    return 1
}

# Expected targets and candidate names (mapped systematically)
TARGETS=(
  "x86_64-elf-gcc"
  "x86_64-elf-ld"
  "x86_64-w64-mingw32-objcopy"
  "i386-elf-gcc"
  "i386-elf-ld"
  "i386-w64-mingw32-objcopy"
  "aarch64-none-elf-gcc"
  "aarch64-none-elf-ld"
  "aarch64-none-elf-objcopy"
  "aarch64-none-elf-ar"
  "aarch64-none-elf-ranlib"
  "aarch64-none-elf-as"
  "aarch64-none-elf-nm"
  "aarch64-none-elf-size"
  "aarch64-none-elf-strip"
)
CANDIDATES=(
  "x86_64-elf-gcc x86_64-elf-gcc-* x86_64-w64-mingw32-gcc"
  "x86_64-elf-ld x86_64-elf-ld.bfd x86_64-w64-mingw32-ld"
  "x86_64-w64-mingw32-objcopy x86_64-elf-objcopy"
  "i386-elf-gcc i386-elf-gcc-* i686-w64-mingw32-gcc"
  "i386-elf-ld i386-elf-ld.bfd i686-w64-mingw32-ld"
  "i386-w64-mingw32-objcopy i386-elf-objcopy"
  "aarch64-none-elf-gcc aarch64-elf-gcc clang"
  "aarch64-none-elf-ld aarch64-elf-ld ld.lld"
  "aarch64-none-elf-objcopy aarch64-elf-objcopy llvm-objcopy"
  "aarch64-none-elf-ar aarch64-elf-ar llvm-ar"
  "aarch64-none-elf-ranlib aarch64-elf-ranlib llvm-ranlib"
  "aarch64-none-elf-as aarch64-elf-as"
  "aarch64-none-elf-nm aarch64-elf-nm"
  "aarch64-none-elf-size aarch64-elf-size"
  "aarch64-none-elf-strip aarch64-elf-strip"
)

missing=0
for i in "${!TARGETS[@]}"; do
  target="${TARGETS[$i]}"

  # Check if valid executable target link is set up
  if [ -L "$BIN_DIR/$target" ] && [ -x "$BIN_DIR/$target" ]; then
    log_info "Already symlinked: $target"
    continue
  fi

  found=""
  for cand in ${CANDIDATES[$i]}; do
    found_path=$(find_executable "$cand" || true)
    if [ -n "$found_path" ]; then
      found="$found_path"
      break
    fi
  done

  if [ -z "$found" ]; then
    log_error "Missing: $target (no candidate found in $MACPORTS_BIN or PATH)"
    missing=$((missing+1))
  else
    if [ -e "$BIN_DIR/$target" ]; then
      if [ -L "$BIN_DIR/$target" ]; then
         # Overwrite broken/stale symlinks seamlessly
         rm "$BIN_DIR/$target"
         ln -s "$found" "$BIN_DIR/$target"
         log_info "Updated symlink $target -> $found"
      else
        log_warn "File exists and is not a symlink: $BIN_DIR/$target — leaving it in place"
      fi
    else
      ln -s "$found" "$BIN_DIR/$target"
      log_info "Symlinked $target -> $found"
    fi
  fi
done

echo
if [ $missing -eq 0 ]; then
  log_info "All required tools are available!"
  echo
  echo "You can now build with:"
  echo "  ./build_via_macports_on_mac.sh"
  echo
  exit 0
fi

# Build suggested MacPorts package list using exact registry naming strings
suggested=()
# x86_64
if ! [ -x "$MACPORTS_BIN/x86_64-elf-gcc" ] && ! command -v x86_64-elf-gcc >/dev/null 2>&1; then
  suggested+=("x86_64-elf-gcc" "mingw-w64")
fi
# ia32 / i686 / i386
if ! [ -x "$MACPORTS_BIN/i386-elf-gcc" ] && ! command -v i386-elf-gcc >/dev/null 2>&1; then
  suggested+=("i386-elf-gcc" "mingw-w64")
fi
# aarch64 binutils
if ! [ -x "$MACPORTS_BIN/aarch64-elf-objcopy" ] && ! command -v aarch64-none-elf-objcopy >/dev/null 2>&1; then
  suggested+=("aarch64-elf-binutils")
fi
# llvm tools (needed for clang aarch64 fallback: ld.lld, llvm-objcopy, llvm-ar, llvm-ranlib)
if ! command -v ld.lld >/dev/null 2>&1 && ! command -v ld.lld-mp-17 >/dev/null 2>&1; then
  suggested+=("llvm-17")
fi

# Deduplicate
unique_pkgs=()
for p in "${suggested[@]}"; do
  found=0
  for q in "${unique_pkgs[@]:-}"; do [ "$q" = "$p" ] && { found=1; break; } done
  [ $found -eq 0 ] && unique_pkgs+=("$p")
done

if [ ${#unique_pkgs[@]} -gt 0 ]; then
  log_warn "Suggested MacPorts install command for missing tools:"
  echo "  sudo port install ${unique_pkgs[*]}"
  if [ -t 0 ]; then
    read -r -p "Run the above command now? [y/N]: " ans
    case "$ans" in
      [Yy]* )
        if ! command -v port >/dev/null 2>&1; then
            log_error "MacPorts 'port' command not found. Install MacPorts first: https://www.macports.org/install.php"
            if [ -t 0 ]; then
                read -r -p "Open MacPorts install page now? [y/N]: " open_ans
                case "$open_ans" in
                    [Yy]* )
                        if command -v open >/dev/null 2>&1; then
                            open "https://www.macports.org/install.php"
                        else
                            echo "Please visit: https://www.macports.org/install.php"
                        fi
                        ;;
                    *)
                        log_warn "Skipping. Install MacPorts and re-run this script."
                        ;;
                esac
            fi
        else
            log_info "Running: sudo port selfupdate && sudo port install ${unique_pkgs[*]}"
            sudo port selfupdate
            sudo port install "${unique_pkgs[@]}"
            log_info "Re-running setup to create symlinks..."
            exec "$0"
        fi
        ;;
      *)
        log_warn "Skipped automatic install. Install the suggested packages and re-run ./setup-toolchain.sh"
        ;;
    esac
  else
    log_warn "Non-interactive session; run the suggested command and re-run setup-toolchain.sh"
  fi
else
  log_warn "Missing tools detected but no suggested MacPorts packages. See Macports.md for manual instructions."
fi

# Offer to download and install ARM GNU Toolchain for full aarch64 support
if ! command -v aarch64-none-elf-gcc >/dev/null 2>&1; then
  if [ -t 0 ]; then
    read -r -p "Download and install ARM GNU Toolchain to /opt for full aarch64 support? [y/N]: " dl_ans
    case "$dl_ans" in
      [Yy]* )
        HOST_ARCH=$(uname -m)
        if [ "$HOST_ARCH" = "arm64" ] || [ "$HOST_ARCH" = "aarch64" ]; then
          TOOL_VER="14.2.rel1"
          ARCHIVE_NAME="arm-gnu-toolchain-14.2.rel1-darwin-arm64-aarch64-none-elf.tar.xz"
          URL="https://arm.com{ARCHIVE_NAME}"
        else
          TOOL_VER="14.2.rel1"
          ARCHIVE_NAME="arm-gnu-toolchain-14.2.rel1-darwin-x86_64-aarch64-none-elf.tar.xz"
          URL="https://arm.com{ARCHIVE_NAME}"
        fi
        TMPDIR="/tmp/abz-arm-toolchain"
        mkdir -p "$TMPDIR"
        log_info "Downloading $ARCHIVE_NAME to $TMPDIR..."
        curl -L -o "$TMPDIR/$ARCHIVE_NAME" "$URL"
        log_info "Extracting..."
        tar -C "$TMPDIR" -xf "$TMPDIR/$ARCHIVE_NAME"
        EXDIR=$(tar -tf "$TMPDIR/$ARCHIVE_NAME" | head -1 | cut -f1 -d'/')
        sudo mkdir -p /opt
        sudo rm -rf "/opt/arm-gnu-toolchain-${TOOL_VER}" # prevent nested directory copies
        sudo mv "$TMPDIR/$EXDIR" "/opt/arm-gnu-toolchain-${TOOL_VER}"
        log_info "Installed to /opt/arm-gnu-toolchain-${TOOL_VER}"
        log_info "Creating symlinks for aarch64-* into $BIN_DIR"
        for f in /opt/arm-gnu-toolchain-${TOOL_VER}/bin/aarch64-none-elf-*; do
          [ -e "$f" ] || continue
          ln -sf "$f" "$BIN_DIR/$(basename "$f")"
        done
        log_info "ARM GNU Toolchain installed and symlinked. Re-running setup to make remaining links."
        exec "$0"
        ;;
      *)
        log_warn "Skipping ARM toolchain download. You can install it later (see Macports.md)."
        ;;
    esac
  else
    log_warn "Non-interactive session; to enable full aarch64 support, download the ARM GNU Toolchain and symlink its aarch64-* tools into ./bin/. See Macports.md."
  fi
fi

exit 1
