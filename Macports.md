# MacPorts Toolchain Setup for ABZ_Shutdown

This guide covers setting up cross-compiler tools for building ABZ_Shutdown EFI binaries using MacPorts on macOS.

MacPorts is the recommended approach for macOS because it supports **all macOS versions** (including older systems like High Sierra, Mojave, etc.), unlike Homebrew which requires Catalina or newer.

## Quick Start (One Command)

```bash
sudo ./install-macports-dependencies.sh
```

This single command:
1. Runs `port selfupdate`
2. Installs all required cross-compilers and utilities (`mingw-w64`, `x86_64-elf-gcc`, `i386-elf-gcc`, `aarch64-elf-binutils`)
3. Optionally runs `setup-toolchain.sh` and `build_via_macports_on_mac.sh` after installation
4. Safely drops root privileges before running build scripts

## Setup

### Prerequisites

You need MacPorts installed with the following tools:

```bash
# Recommended MacPorts packages (installs compilers and mingw binutils)
sudo port install x86_64-elf-gcc x86_64-w64-mingw32-binutils   i686-w64-mingw32-gcc i686-w64-mingw32-binutils aarch64-elf-binutils

# Note: MacPorts provides aarch64 binutils but not aarch64 GCC.
# The build script auto-detects clang as a fallback for aarch64 compilation.
# For GCC-based aarch64 builds, install ARM GNU Toolchain (see below).
```

### Automatic Setup

From the project root, run the setup script to create all necessary symlinks:

```bash
./setup-toolchain.sh
```

The script interactively:
- Creates symlinks in `./bin/` for all detected cross-compiler tools
- Offers to install missing MacPorts packages automatically
- Offers to download and install ARM GNU Toolchain for aarch64 support
- Detects tools in both `/opt/local/bin` and system PATH

Or manually from the `bin/` directory:

```bash
cd bin/
ln -s /opt/local/bin/x86_64-elf-gcc .
ln -s /opt/local/bin/x86_64-elf-ld .
ln -s /opt/local/bin/x86_64-w64-mingw32-objcopy .
ln -s /opt/local/bin/i686-elf-gcc .
ln -s /opt/local/bin/i686-elf-ld .
ln -s /opt/local/bin/i686-w64-mingw32-objcopy .
```

## Current Tools

### x86_64 (64-bit Intel/AMD)
- `x86_64-elf-gcc` → `/opt/local/bin/x86_64-elf-gcc`
- `x86_64-elf-ld` → `/opt/local/bin/x86_64-elf-ld`
- `x86_64-w64-mingw32-objcopy` → `/opt/local/bin/x86_64-w64-mingw32-objcopy`

**Source:** MacPorts

### ia32 (32-bit Intel)
- `i686-elf-gcc` → `/opt/local/bin/i686-elf-gcc`
- `i686-elf-ld` → `/opt/local/bin/i686-elf-ld`
- `i686-w64-mingw32-objcopy` → `/opt/local/bin/i686-w64-mingw32-objcopy`

**Source:** MacPorts

### aarch64 (ARM 64-bit) - OPTIONAL

aarch64 support requires a C compiler. MacPorts provides `aarch64-elf-binutils` (linker, objcopy, ar, ranlib) but **not** `aarch64-elf-gcc`. To build for aarch64:

**Option 1: Use clang (Automatic — works on all macOS versions)**

The build script automatically falls back to Apple Clang (`clang --target=aarch64-unknown-elf`) with MacPorts `aarch64-elf-*` binutils when no GCC cross-compiler is found. No extra setup needed — just run:

```bash
./build_shutdown.sh aarch64
```

Requires `aarch64-elf-binutils` installed via MacPorts (included in the dependency installer).

**Option 2: Use ARM GNU Toolchain (GCC-based)**

1. Download the ARM GNU Toolchain for your platform from https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads:
   - **macOS (Intel) 10.15 Catalina or later:** `arm-gnu-toolchain-11.3.rel1-darwin-x86_64-aarch64-none-elf.tar.xz`
   https://developer.arm.com/-/media/Files/downloads/gnu/11.3.rel1/binrel/arm-gnu-toolchain-11.3.rel1-darwin-x86_64-aarch64-none-elf.tar.xz
   - **macOS (Intel) 12 Monterey or later:** `arm-gnu-toolchain-12.2.rel1-darwin-x86_64-aarch64-none-elf.tar.xz`
   https://developer.arm.com/-/media/Files/downloads/gnu/12.2.rel1/binrel/arm-gnu-toolchain-12.2.rel1-darwin-x86_64-aarch64-none-elf.tar.xz
   - **macOS (Apple Silicon):** `arm-gnu-toolchain-15.2.rel1-darwin-arm64-aarch64-none-elf.tar.xz`

2. Extract and create symlinks:
   ```bash
   tar xf arm-gnu-toolchain-11.3.rel1-darwin-x86_64-aarch64-none-elf.tar.xz
   cd bin/
   ln -s /path/to/extracted/bin/aarch64-none-elf-gcc .
   ln -s /path/to/extracted/bin/aarch64-none-elf-ld .
   ln -s /path/to/extracted/bin/aarch64-none-elf-objcopy .
   ln -s /path/to/extracted/bin/aarch64-none-elf-ar .
   ln -s /path/to/extracted/bin/aarch64-none-elf-ranlib .
   ```

3. The build script will auto-detect and use these tools.

**Option 2: Use MacPorts Binutils Only (Binutils Only - No Compiler)**

MacPorts provides `aarch64-elf-binutils` which includes `aarch64-elf-objcopy`, `aarch64-elf-ld`, `aarch64-elf-ar`, and `aarch64-elf-ranlib`. Combined with Apple Clang as the compiler, this is sufficient for building aarch64 EFI binaries on any macOS version.

**Note:** The `arm-none-eabi-` toolchain is for 32-bit ARM, not 64-bit ARM (aarch64). ARM's prebuilt GCC toolchains require at least macOS 10.15 Catalina. On older macOS versions, the clang fallback (Option 1) is the recommended approach.

## About mingw32 objcopy

The MinGW binutils (`x86_64-w64-mingw32-objcopy` and `i686-w64-mingw32-objcopy`) are specifically used because they support PE/COFF output format, which is required for EFI binaries. Standard ELF objcopy tools lack this capability.

## Build Usage

Simply run from the project root:

```bash
./build_via_macports_on_mac.sh              # Build all available (x64, ia32, +aa64 if present)
./build_via_macports_on_mac.sh x64          # Build x64 only
./build_via_macports_on_mac.sh ia32         # Build ia32 only
./build_via_macports_on_mac.sh aa64         # Build aarch64 only (if tools available)
```

The build script automatically detects available tools in this directory and uses them.
