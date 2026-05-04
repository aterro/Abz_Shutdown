# ABZ_Shutdown.efi - ACPI Shutdown EFI Application

A **completely standalone UEFI application** that performs system shutdown via ACPI without any dependencies on rEFInd or other boot loaders.

## Overview

**ABZ_Shutdown.efi** is a lightweight UEFI utility extracted from the rEFInd boot loader's shutdown functionality (refind/main.c lines 163-663). It provides a clean, ACPI-based method to shut down systems by:

1. **Locating ACPI tables** - Finds the ACPI Root System Descriptor Pointer (RSDP)
2. **Parsing ACPI structures** - Reads RSDT, FADT, DSDT, and SSDT tables
3. **Extracting sleep state** - Determines the S5 (shutdown) sleep state configuration
4. **Executing shutdown** - Writes appropriate values to the PM control block to initiate system shutdown

## Key Features

✅ **Completely Standalone** - Only depends on GNU-EFI, not on rEFInd or any other boot loader
✅ **Minimal Dependencies** - Just `build-essential` and `gnu-efi` packages
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
```bash
sudo apt-get install build-essential gnu-efi
```

**Optional (for Secure Boot signing):**
- `refind-sbat.csv` - SBAT policy file

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

### Clean Build
```bash
CLEAN_BUILD=1 ./build_shutdown.sh
```
Removes old build artifacts before building

### Custom SBAT CSV
```bash
SHUTDOWN_SBAT_CSV=/path/to/custom-sbat.csv ./build_shutdown.sh
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
├── build_shutdown.sh              # Standalone build script (215 lines)
├── Makefile                       # Optional rEFInd integration
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
- ✅ **Dependency Checking** - Verifies GNU-EFI is installed
- ✅ **Colored Output** - Clear [INFO], [WARN], [ERROR] messages
- ✅ **Error Handling** - Exits gracefully with helpful messages
- ✅ **No External Dependencies** - Pure bash with standard GNU tools
- ✅ **SBAT Support** - Optional Secure Boot AT signing
- ✅ **Clean Builds** - `CLEAN_BUILD=1` option for fresh builds
- ✅ **Environment Variables** - Customizable via environment

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

## Building Independently from rEFInd

To build ABZ_Shutdown.efi completely separate from rEFInd:

```bash
# Create a new directory
mkdir -p ~/abz-shutdown-build
cd ~/abz-shutdown-build

# Copy just these 2 files
cp /path/to/shutdown_efi/shutdown.c .
cp /path/to/shutdown_efi/build_shutdown.sh .

# Make it executable
chmod +x build_shutdown.sh

# Build
./build_shutdown.sh

# Result: ABZ_Shutdown_x64.efi is ready!
```

No rEFInd source needed, no additional configuration required.

## Troubleshooting

### "gnu-efi not found"
```bash
sudo apt-get install gnu-efi
```

### "gcc command not found"
```bash
sudo apt-get install build-essential
```

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
- **Works with Secure Boot** - Can be signed using existing rEFInd SBAT policy

## Performance

- **Binary Size**: ~41 KB (including SBAT section)
- **Memory Usage**: Minimal (~1 KB at runtime)
- **Build Time**: ~1-2 seconds
- **Shutdown Time**: Typically 1-2 seconds from execution to power-off

## License

Extracted from rEFInd which is licensed under the GNU General Public License (GPL) v3.
See rEFInd project for full licensing details.

## Related Documentation

- [ACPI Specification](https://uefi.org/specifications)
- [UEFI Specification](https://uefi.org/specifications)
- [GNU-EFI Documentation](https://sourceforge.net/p/gnu-efi/wiki/Home/)
- [rEFInd Project](http://www.rodsbooks.com/refind/)

## Contributing & Support

This is a standalone utility derived from rEFInd. For issues:

1. Verify GNU-EFI is properly installed
2. Check that ACPI is enabled on your system
3. Try on different hardware if possible
4. Review the shutdown.c source code for implementation details

## Summary

**ABZ_Shutdown.efi** is a powerful, completely standalone UEFI application for ACPI-based system shutdown. With just two files and two system packages, you can build a fully functional EFI shutdown utility that works on any ACPI-capable x86/x86-64 system.

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
