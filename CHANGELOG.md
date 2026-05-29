# Changelog

All notable changes to this project are documented in this file.

## v5.0 — macOS aarch64 clang fallback & toolchain fixes (2026-05-29)

- **macOS aarch64 builds now work with clang**: when no aarch64 GCC cross-compiler is found, the build script auto-detects `clang --target=aarch64-unknown-elf` with MacPorts `aarch64-elf-*` binutils as a complete fallback toolchain
- **Fixed x86_64/ia32 macOS builds**: `resolve_objcopy_format()` now searches for `x86_64-w64-mingw32-objcopy` and `i686-w64-mingw32-objcopy` which support PEI targets, matching the behavior of `build_via_macports_on_mac.sh`
- **Removed invalid `arm-none-eabi-` prefix** from aarch64 candidate lists in both `build_shutdown.sh` and `build_aarch64.sh` — this 32-bit ARM toolchain cannot handle aarch64 and caused incorrect toolchain selection
- **Fixed empty array expansion crash**: `${_libgcc_arg[@]}` and `${z_flags[@]}` now use `${var[@]+"${var[@]}"}` pattern to avoid `unbound variable` errors under `set -u`
- **Added `llvm-17`** to `install-macports-dependencies.sh` for LLVM tools (llvm-ar, llvm-objcopy, llvm-ranlib)
- **Updated `setup-toolchain.sh`**: aarch64 tool candidates now include `clang`/`ld.lld`/`llvm-*` as fallbacks, plus `llvm-17` suggestion when LLVM tools are missing

See Macports.md for the full macOS setup guide.

## v3.5 — MacPorts dependency management & toolchain automation (2026-05-25)

- **New `install-macports-dependencies.sh`**: one-command MacPorts dependency installer with:
  - Automatic `port selfupdate` and `port install` of all required cross-compilers and utilities
  - Interactive prompt to optionally run `setup-toolchain.sh` + `build_via_macports_on_mac.sh` after install
  - Safe sudo-user detection — drops root privileges before running build scripts
  - Non-interactive session handling (CI-friendly)
- **Enhanced `setup-toolchain.sh`**: fully interactive setup with:
  - Automatic detection and symlinking of all cross-compiler tools from MacPorts and PATH
  - Optional auto-install of missing MacPorts packages when run interactively
  - Optional download & install of ARM GNU Toolchain for aarch64 support
  - Updated symlinks for ARM GNU Toolchain 11.3.rel1 (requires macOS 10.15+)
  - Support for aarch64-none-elf-* tool variants (as, nm, size, strip)
- **Renamed** `build_all_with_ports.sh` → `build_via_macports_on_mac.sh` for clarity
- **Documentation**: migrated `bin/README.md` → `Macports.md` with full aarch64 toolchain notes
- Updated README.md, BUILDSETUP.md, and related docs to reflect the new scripts

See Macports.md for the full macOS setup guide.

## v3.0 — Improved support for old compilers (2026-05-21)

- Enhanced Windows build wrapper to detect legacy ia32/MSYS2/portable Git Bash environments.
- Added robust fallbacks when GNU objcopy cannot produce PE/COFF images (Python-based ELF→PE converter).
- Ensured Python-based fixer is available inside Windows batch-launched Bash sessions.
- Lowered aarch64 EFI size heuristic to trigger fixes earlier (70KB).
- Improved diagnostics and guidance for users on missing toolchains and objcopy BFD targets.

See README.md and BUILD_GUIDE.md for usage and troubleshooting details.
