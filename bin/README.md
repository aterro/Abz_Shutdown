# Cross-Compiler Toolchain for ABZ_Shutdown

This directory contains **symlinks** to the cross-compiler tools needed to build ABZ_Shutdown EFI binaries for multiple architectures.

## Setup

### Prerequisites

You need MacPorts installed with the following tools:

```bash
sudo port install x86_64-elf-gcc i686-elf-gcc \
  x86_64-w64-mingw32-binutils i686-w64-mingw32-binutils
```

### Automatic Setup

From the project root, run the setup script to create all necessary symlinks:

```bash
./setup-toolchain.sh
```

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

aarch64 support is **not available** through MacPorts as of now. To build for aarch64:

1. Download the ARM GNU Toolchain for your platform from https://developer.arm.com/downloads/-/gnu-a:
   - **macOS (Intel):** `arm-gnu-toolchain-15.2.rel1-darwin-x86_64-aarch64-none-elf.tar.xz`
   - **macOS (Apple Silicon):** `arm-gnu-toolchain-15.2.rel1-darwin-arm64-aarch64-none-elf.tar.xz`

2. Extract and create symlinks:
   ```bash
   tar xf arm-gnu-toolchain-15.2.rel1-darwin-*-aarch64-none-elf.tar.xz
   cd bin/
   ln -s /path/to/extracted/bin/aarch64-none-elf-gcc .
   ln -s /path/to/extracted/bin/aarch64-none-elf-ld .
   ln -s /path/to/extracted/bin/aarch64-none-elf-objcopy .
   ln -s /path/to/extracted/bin/aarch64-none-elf-ar .
   ln -s /path/to/extracted/bin/aarch64-none-elf-ranlib .
   ```

3. The build script will auto-detect and use these tools.

**Note:** MacPorts provides `aarch64-elf-binutils` but not `aarch64-elf-gcc`. The `arm-none-eabi-` toolchain is for 32-bit ARM, not 64-bit ARM (aarch64).

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
