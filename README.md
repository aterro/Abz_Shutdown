# ABZ_Shutdown.efi - ACPI Shutdown EFI Application

This directory contains the source code and build files for `Shutdown.efi`, a **standalone UEFI application** that performs system shutdown via ACPI.

## Overview

`ABZ_Shutdown.efi` is derived from `grub2fm`'s `halt.c`. It provides a minimal UEFI utility to cleanly shut down a system by:

1. Locating the ACPI Root System Descriptor Pointer (RSDP)
2. Parsing the ACPI tables (RSDT, FADT, DSDT, SSDT)
3. Extracting the S5 sleep state configuration
4. Writing the appropriate value to the PM control block to initiate shutdown

## Is It Standalone?

**Yes.** `ABZ_Shutdown.efi` is standalone. It only depends on:
- GNU-EFI libraries (`libefi`, `libgnuefi`)
- Standard C library
- No boot-loader-specific libraries

## Building

### Option 1: Using the Standalone Build Script (Recommended)

The easiest way to build is using the provided bash script:

```bash
cd shutdown_efi
./build_shutdown.sh
```

The script will:
- Detect your architecture automatically (x86_64, ia32, or aarch64)
- Check for required dependencies (GNU-EFI)
- Compile and link the binary
- Convert to EFI format
- Output: `Shutdown_x64.efi` (or architecture variant)

**Requirements on Linux:**
- `build-essential`
- `gnu-efi`

Install on Ubuntu/Debian:
```bash
sudo apt-get install build-essential gnu-efi
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
- ✅ Host OS detection (Linux/macOS)
- ✅ Dependency checking
- ✅ Colored output for easy reading
- ✅ Clean build option (`CLEAN_BUILD=1 ./build_shutdown.sh`)
- ✅ Custom SBAT CSV support
- ✅ No external makefile dependencies

**Usage:**
```bash
# Standard build
./build_shutdown.sh

# Force architecture (optional)
./build_shutdown.sh x86_64

# Use custom SBAT CSV
SHUTDOWN_SBAT_CSV=abz-shutdown.csv ./build_shutdown.sh

# Clean build
CLEAN_BUILD=1 ./build_shutdown.sh
```

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
- It does not require any external tools or scripts beyond the compiler
- The binary can optionally include SBAT section for Secure Boot signing
- All ACPI parsing is inline with no external library dependencies
