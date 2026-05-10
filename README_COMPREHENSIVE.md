# ABZ_Shutdown.efi - ACPI Shutdown EFI Application

A **completely standalone UEFI application** that performs system shutdown via ACPI and can build on Linux, macOS, or Windows by using any available supported GNU-EFI toolchain path.

## Overview

**ABZ_Shutdown.efi** is a lightweight UEFI utility derived from `grub2fm`'s `halt.c`. It provides a clean, ACPI-based method to shut down systems by:

1. **Locating ACPI tables** - Finds the ACPI Root System Descriptor Pointer (RSDP)
2. **Parsing ACPI structures** - Reads RSDT, FADT, DSDT, and SSDT tables
3. **Extracting sleep state** - Determines the S5 (shutdown) sleep state configuration
4. **Executing shutdown** - Writes appropriate values to the PM control block to initiate system shutdown

## Key Features

✅ **Completely Standalone** - Depends on GNU-EFI plus a suitable toolchain
✅ **Cross-Platform Builder** - `build_shutdown.sh` detects Linux, macOS, and Windows-hosted Bash environments
✅ **Multiple Architectures** - Supports x86_64, ia32 (32-bit x86), and aarch64
✅ **Easy to Build** - One command: `./build_shutdown.sh`
✅ **No Makefile Required** - Bash script handles all compilation and linking
✅ **Standalone Build Script** - Can be used completely independently
✅ **Self-Contained Source** - All ACPI code in a single shutdown.c file

## Quick Start

### Build the Binary

```bash
cd shutdown_efi
./build_shutdown.sh
```

On Windows Command Prompt or PowerShell:

```bat
build_shutdown.bat
```

The batch wrapper tries Git Bash, MSYS2, and other Windows Bash entry points first, then falls back to WSL when needed.

The binary will be created as **ABZ_Shutdown_x64.efi** (on x86-64 systems).

### Install and Use

1. Copy the binary to your EFI System Partition (ESP):
   ```bash
   sudo cp ABZ_Shutdown_x64.efi /boot/efi/EFI/
   ```

2. Execute from:
   - UEFI Shell: `fs0:\EFI\ABZ_Shutdown_x64.efi`
   - UEFI Boot Menu (add as boot entry)
   - Other UEFI applications

3. When executed:
   - Displays ACPI shutdown probe information
   - Initiates system shutdown via ACPI
   - Falls back to error message if ACPI not supported

## System Requirements

### To Build ABZ_Shutdown.efi:

**Minimum (2 files needed):**
- `shutdown.c` - Full source code
- `build_shutdown.sh` - Build script

**System packages:**
Linux:
```bash
sudo apt-get install build-essential gnu-efi
```

macOS:
```bash
brew install binutils x86_64-elf-gcc
```

Windows:
- Git Bash, MSYS2 Bash, or WSL
- GNU-EFI headers and libraries in that environment
- GCC, `ld`, `objcopy`, `ar`, and `ranlib` (mingw32 toolchain), OR
- LLVM/clang with `ld.lld`, `llvm-objcopy`, `llvm-ar`, `llvm-ranlib` (recommended for mingw32)
- `build_shutdown.bat` as the Windows entry point

The build script checks common Windows-hosted Bash prefixes such as `/usr`, `/mingw64`, `/ucrt64`, `/clang64`, `/clangarm64`, and `/c/msys64/*`.

> **Note**: The bundled GNU-EFI libraries are ELF format, but mingw32 GCC produces COFF/PE objects. The build script automatically detects this mismatch and switches to an LLVM/clang toolchain for ELF output if available. Set `LLVM_PREFIX` to point to your LLVM installation directory if it's in a non-standard location.

**Optional (for Secure Boot signing):**
- `abz-shutdown.csv` - SBAT policy file

### To Run ABZ_Shutdown.efi:

- UEFI-capable system
- ACPI support (on x86/x86-64)
- EFI System Partition with FAT32 filesystem

## Build Options

### Standard Build
```bash
./build_shutdown.sh
```
Creates `ABZ_Shutdown_x64.efi` (detects architecture automatically)

### Windows Entry Point
```bat
build_shutdown.bat
```
Finds `bash.exe` from Git for Windows, MSYS2, or `PATH`, and falls back to WSL so Windows can build with any available supported GNU-EFI toolchain.

### Clean Build
```bash
CLEAN_BUILD=1 ./build_shutdown.sh
```
Removes old build artifacts before building

### Custom SBAT CSV
```bash
SHUTDOWN_SBAT_CSV=/path/to/abz-shutdown.csv ./build_shutdown.sh
```
Use custom Secure Boot AT policy file

### Specific Architecture
```bash
./build_shutdown.sh x86_64
./build_shutdown.sh ia32
./build_shutdown.sh aarch64
```

## Build Output

Depending on your architecture:
- **x86_64**: `ABZ_Shutdown_x64.efi`
- **32-bit x86**: `ABZ_Shutdown_ia32.efi`
- **ARM64**: `ABZ_Shutdown_aa64.efi`

Binary size: ~41 KB (stripped, with sections optimized)

## Files in This Directory

```
shutdown_efi/
├── shutdown.c                      # Full source code (528 lines)
├── build_shutdown.sh              # Standalone build script
├── build_shutdown.bat            # Windows wrapper for the build script
├── Makefile                       # Optional legacy external-tree build file
├── README.md                      # This documentation
├── STANDALONE_REQUIREMENTS.txt    # Quick reference
└── ABZ_Shutdown_x64.efi           # Compiled binary (ready to use)
```

## Source Code Structure

### shutdown.c (528 lines)

**ACPI Parsing Functions:**
- `AcpiDecodeLength()` - Decodes ACPI length values
- `AcpiSkipNameString()` - Skips ACPI name strings
- `AcpiSkipDataRefObject()` - Skips data reference objects
- `AcpiSkipTerm()` - Skips ACPI terms
- `AcpiSkipExtOp()` - Skips extended operations

**Sleep Type Detection:**
- `AcpiGetSleepType()` - Extracts S5 sleep state from DSDT/SSDT tables

**Hardware Control:**
- `AcpiWritePmControl()` - Writes to PM control register
- `FindAcpiRootPointer()` - Locates ACPI RSDP in system tables

**Main Shutdown Logic:**
- `TryAcpiShutdown()` - Orchestrates the shutdown sequence
- `efi_main()` - UEFI application entry point

**Helper Functions:**
- `GuidsAreEqual()` - GUID comparison utility

## Build Script Features

The `build_shutdown.sh` script provides:

- ✅ **Automatic Architecture Detection** - Detects x86_64, ia32, or aarch64
- ✅ **Host OS Detection** - Adjusts for Linux, macOS, and Windows-hosted Bash toolchains
- ✅ **Dependency Checking** - Verifies GNU-EFI is installed
- ✅ **Colored Output** - Clear [INFO], [WARN], [ERROR] messages
- ✅ **Error Handling** - Exits gracefully with helpful messages
- ✅ **No External Dependencies** - Pure bash with standard GNU tools
- ✅ **SBAT Support** - Optional Secure Boot AT signing
- ✅ **Clean Builds** - `CLEAN_BUILD=1` option for fresh builds
- ✅ **Environment Variables** - Customizable via environment (CC, LD, OBJCOPY, LLVM_PREFIX, etc.)
- ✅ **Automatic LLVM/Clang Fallback** - Detects mingw32 COFF/PE toolchain and switches to LLVM/clang for ELF output on Windows
- ✅ **llvm-objcopy Detection** - Adjusts EFI conversion flags for llvm-objcopy vs GNU objcopy
- ✅ **aarch64 Support** - Uses `pei-aarch64-little` format for ARM64 EFI binaries

## Architecture-Specific Notes

### x86_64 (Full Support)
- Full ACPI shutdown support
- All features enabled
- Recommended for modern systems

### ia32 (32-bit x86, Full Support)
- Full ACPI shutdown support
- For older or 32-bit only systems
- Auto-detected if running on 32-bit system

### aarch64 (ARM64, Limited Support)
- `TryAcpiShutdown()` returns FALSE
- ARM systems don't use ACPI for shutdown
- Can still be compiled; just won't perform shutdown
- Consider alternative shutdown methods for ARM systems

## Building Independently

To build ABZ_Shutdown.efi completely standalone:

```bash
# Create a new directory
mkdir -p ~/abz-shutdown-build
cd ~/abz-shutdown-build

# Copy the standalone build files
cp /path/to/shutdown_efi/shutdown.c .
cp /path/to/shutdown_efi/build_shutdown.sh .
cp /path/to/shutdown_efi/build_shutdown.bat .

# Make it executable
chmod +x build_shutdown.sh

# Build
./build_shutdown.sh

# Result: ABZ_Shutdown_x64.efi is ready!
```

No external boot-loader source tree is required.

## Troubleshooting

### "gnu-efi not found"
```bash
sudo apt-get install gnu-efi
```

### "gcc command not found"
```bash
sudo apt-get install build-essential
```

On Windows, verify that `build_shutdown.bat` can find Git Bash, MSYS2, or WSL and that the selected environment has GCC/binutils plus GNU-EFI installed.

### Build fails with "permission denied"
```bash
chmod +x build_shutdown.sh
```

### Can't find ACPI tables at runtime
- Ensure ACPI is enabled in BIOS/UEFI
- System must have valid ACPI tables
- Try on a different system if available

### EFI binary doesn't execute
- Ensure ESP is mounted
- Verify EFI firmware can find the binary
- Check if Secure Boot is blocking unsigned binaries

## Security Considerations

- **No Secure Boot Signing by Default** - Binary is unsigned unless SBAT CSV is provided
- **ACPI Access** - Directly accesses PM control registers (requires UEFI firmware cooperation)
- **No Authentication** - Executes immediately without prompting
- **Works with Secure Boot** - Can include an optional SBAT section

## Performance

- **Binary Size**: ~41 KB (including SBAT section)
- **Memory Usage**: Minimal (~1 KB at runtime)
- **Build Time**: ~1-2 seconds
- **Shutdown Time**: Typically 1-2 seconds from execution to power-off

## License

Derived from grub2fm code. Keep the upstream license terms that apply to the imported source.

## Related Documentation

- [ACPI Specification](https://uefi.org/specifications)
- [UEFI Specification](https://uefi.org/specifications)
- [GNU-EFI Documentation](https://sourceforge.net/p/gnu-efi/wiki/Home/)
- [grub2fm Project](https://github.com/a1ive/grub2-filemanager)

## Contributing & Support

This is a standalone utility derived from grub2fm `halt.c`. For issues:

1. Verify GNU-EFI is properly installed
2. Check that ACPI is enabled on your system
3. Try on different hardware if possible
4. Review the shutdown.c source code for implementation details

## Summary

**ABZ_Shutdown.efi** is a powerful, completely standalone UEFI application for ACPI-based system shutdown. With just two files and a supported GNU-EFI toolchain, you can build a fully functional EFI shutdown utility that works on any ACPI-capable x86/x86-64 system.

Perfect for:
- Custom UEFI applications
- Boot loader alternatives
- System utilities
- UEFI shell scripts
- Embedded systems development

---

**Build Status**: ✅ Ready to Use
**Last Updated**: 2026-05-04
**Architecture Support**: x86_64, ia32, aarch64
