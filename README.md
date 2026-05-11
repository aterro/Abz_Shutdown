# ABZ_Shutdown.efi - ACPI Shutdown EFI Application

This directory contains the source code and build files for `ABZ_Shutdown.efi`, a **standalone UEFI application** that performs system shutdown via ACPI and can build on Linux, macOS, Windows, and Termux.

It's a fix for buggy firmware that restart instead of shutdown using the "reset -s" command such as the B390 series from Asus and others.

The code inside shutdown.c was borrowed from grub2fm halt.c and can be used to fix shutdown from any efi application or bootloader such as my Refind-for-All and RefindPlus mods.

## 🚀 Quick Start

### Termux (Android)
```bash
cd Abz_Shutdown
./build_shutdown.sh
./Fix-efi-on-termux.sh
```
Bundled GNU-EFI files are included, but Termux still needs an `objcopy` that supports EFI targets such as `efi-app-x86_64` or `efi-app-aarch64`. Start with `pkg install build-essential`, then check `objcopy --help | grep efi-app`. If that still shows no EFI targets, use the Debian/Ubuntu proot flow in [TERMUX_QUICKSTART.md](TERMUX_QUICKSTART.md).

### Linux / macOS and Windows
```bash
./build_shutdown.sh and ./build_shutdown.bat
```
Falls back to system gnu-efi or see [BUILD_GUIDE.md](BUILD_GUIDE.md) for platform-specific setup.

## Overview

`ABZ_Shutdown.efi` is derived from `grub2fm`'s `halt.c`. It provides a minimal UEFI utility to cleanly shut down a system by:

1. Locating the ACPI Root System Descriptor Pointer (RSDP)
2. Parsing the ACPI tables (RSDT, FADT, DSDT, SSDT)
3. Extracting the S5 sleep state configuration
4. Writing the appropriate value to the PM control block to initiate shutdown

## Is It Standalone?

**Yes.** `ABZ_Shutdown.efi` is completely standalone and self-contained:
- ✅ Bundled GNU-EFI libraries for aarch64 (Termux/ARM)
- ✅ Works with system gnu-efi on other platforms
- ✅ No boot-loader-specific libraries required
- ✅ Single command build

## Building

### Quick Build (All Platforms)

```bash
cd Abz_Shutdown
./build_shutdown.sh          # builds for native architecture
./build_shutdown.sh aarch64  # cross-compile for ARM64
./build_shutdown.sh ia32     # cross-compile for 32-bit x86
```

The script automatically:
- Detects your architecture (x86_64, ia32, or aarch64) — or uses the explicit target you pass
- Uses bundled GNU-EFI files (if available for your arch)
- Uses a repo-local `gnu-efi/` or `gnuefi/` checkout when present
- Falls back to system gnu-efi installation
- Verifies that `objcopy` can emit a real EFI binary for the selected target
- Compiles and links the binary
- Outputs: `ABZ_Shutdown_<arch>.efi`

**Cross-compiling for aarch64** from an x86_64 host is fully supported. The script defaults to `TOOLCHAIN_PREFIX=aarch64-linux-gnu-` and will prompt to install `gcc-aarch64-linux-gnu` + `binutils-aarch64-linux-gnu` if the cross-toolchain is missing.

### Platform-Specific

#### Termux
Start with:
```bash
pkg install build-essential
objcopy --help | grep efi-app
./build_shutdown.sh
```
If `objcopy` does not list an `efi-app-*` target, use a Debian/Ubuntu proot environment and install `build-essential gnu-efi binutils`. See [TERMUX_QUICKSTART.md](TERMUX_QUICKSTART.md) for the full flow.
See [TERMUX_QUICKSTART.md](TERMUX_QUICKSTART.md) for details.

#### Linux
```bash
# Install dependencies (if bundled files not available)
sudo apt-get install build-essential gnu-efi

# Build
./build_shutdown.sh
```

#### Windows
```bat
build_shutdown.bat
```
The batch wrapper tries Git Bash, MSYS2, and other Windows Bash entry points first, then falls back to WSL.

#### macOS
Requires cross-compilation toolchain. See [BUILD_GUIDE.md](BUILD_GUIDE.md).

**Requirements on Linux:**
- `build-essential`
- `gnu-efi`

Install on Ubuntu/Debian:
```bash
sudo apt-get install build-essential gnu-efi
```

For aarch64 cross-compilation, also install:
```bash
sudo apt-get install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
```

**Requirements on macOS:**
- GNU-EFI headers and libraries
- GNU binutils
- A matching cross GCC toolchain such as `x86_64-elf-gcc`
- Xcode Command Line Tools / SDK

Example:
```bash
brew install binutils x86_64-elf-gcc
```

If you keep a local GNU-EFI checkout in `./gnu-efi/` or `./gnuefi/`, `./build_shutdown.sh`
now detects it automatically and will use its built artifacts in preference to a system install.

**Requirements on Windows:**
- Git Bash, MSYS2 Bash, or WSL
- GNU-EFI headers and libraries in that environment
- GCC, `ld`, `objcopy`, `ar`, and `ranlib` (mingw32 toolchain), OR
- LLVM/clang with `ld.lld`, `llvm-objcopy`, `llvm-ar`, `llvm-ranlib`

The build script checks common MSYS2-style prefixes automatically, including `/usr`, `/mingw64`, `/ucrt64`, `/clang64`, `/clangarm64`, and `/c/msys64/*`, and `build_shutdown.bat` can fall through to WSL when that is the usable toolchain.

> **Note for mingw32 environments**: The bundled GNU-EFI libraries are in ELF format, but the mingw32 GCC toolchain produces COFF/PE objects. The build script automatically detects this and switches to an LLVM/clang toolchain (clang, ld.lld, llvm-objcopy) for ELF output if available. Set `LLVM_PREFIX` to the directory containing the LLVM tools if they are in a non-standard location.

### Option 2: Using the Makefile (Legacy external-tree build)

If you're building inside a compatible external tree:

```bash
cd shutdown_efi
make
```

This path is optional and less portable than `build_shutdown.sh`.

## Building Standalone Later

To build `ABZ_Shutdown.efi` independently elsewhere:

1. **Copy only these files** to a new directory:
   - `shutdown.c`
   - `build_shutdown.sh`

2. **Run the build script:**
   ```bash
   ./build_shutdown.sh
   ```

3. **That's it!** The binary will be created.

## Architecture Support

- **x86_64** (default) - Full support
- **ia32** - Full support (32-bit x86)
- **aarch64** - Limited support (returns FALSE from TryAcpiShutdown)

## Standalone Build Script Features

The `build_shutdown.sh` script provides:

- ✅ Automatic architecture detection
- ✅ Host OS detection (Linux/macOS/Windows-hosted Bash)
- ✅ Dependency checking
- ✅ Colored output for easy reading
- ✅ Clean build option (`CLEAN_BUILD=1 ./build_shutdown.sh`)
- ✅ Custom SBAT CSV support
- ✅ No external makefile dependencies
- ✅ Cross-compilation support (all three architectures from any host)
- ✅ Auto-prompt for installing missing aarch64 cross-toolchain packages

**Usage:**
```bash
# Standard build (native architecture)
./build_shutdown.sh

# Windows entry point
build_shutdown.bat

# Force architecture (optional)
./build_shutdown.sh x86_64
./build_shutdown.sh ia32
./build_shutdown.sh aarch64

# Use custom SBAT CSV
SHUTDOWN_SBAT_CSV=abz-shutdown.csv ./build_shutdown.sh

# Clean build
CLEAN_BUILD=1 ./build_shutdown.sh
```

**Cross-compilation notes:**
- **aarch64** from x86_64: install `gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu`, or let the script prompt you automatically.
- **ia32** on x86_64: native `gcc` with `-m32` is used automatically when the target and host are both x86.

## Usage

The resulting EFI binary can be:

- Copied to your EFI System Partition (ESP) boot directory
- Executed from a UEFI shell or boot menu
- Called by other UEFI applications

When executed, it will:
1. Display probe information about ACPI shutdown parameters
2. Attempt to gracefully shut down the system via ACPI
3. If successful, the system will power off
4. If unsuccessful, it will display an error and wait for user input

## Architecture

The application is built using GNU-EFI and includes:

- **shutdown.c**: Self-contained application source containing:
  - ACPI table parsing functions (AcpiDecodeLength, AcpiSkipNameString, etc.)
  - Sleep type detection (AcpiGetSleepType)
  - PM control register access (AcpiWritePmControl)
  - Main shutdown routine (TryAcpiShutdown)
  - Entry point (efi_main)
  - No external dependencies beyond standard EFI headers

## Files in This Directory

- **shutdown.c** - Complete source code (16.7 KB)
- **build_shutdown.sh** - Standalone build script (self-contained, no makefile)
- **Makefile** - Optional legacy makefile for external tree builds
- **README.md** - This documentation

## Notes

- This utility is x86/x86-64 specific (ARM64 returns FALSE from TryAcpiShutdown)
- It requires a functioning ACPI implementation on the system
- Building a real EFI binary requires an `objcopy` that supports the `efi-app-*` target for the selected architecture
- The binary can optionally include SBAT section for Secure Boot signing
- All ACPI parsing is inline with no external library dependencies
