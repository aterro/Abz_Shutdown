# ABZ_Shutdown Build System - Setup Guide

## Quick Start

This project now includes everything needed to build EFI shutdown binaries for multiple architectures.

### One-Command Install & Build

```bash
# Install all MacPorts dependencies (one command, requires sudo)
sudo ./install-macports-dependencies.sh

# Or manually step through:
./setup-toolchain.sh           # Set up toolchain symlinks (one time)
./build_via_macports_on_mac.sh # Build all architectures
```

### Requirements

You need **MacPorts** installed with:

```bash
# Install all dependencies at once (recommended)
sudo ./install-macports-dependencies.sh

# Or manually install the required packages:
sudo port install x86_64-elf-gcc x86_64-w64-mingw32-binutils \
  i686-w64-mingw32-gcc i686-w64-mingw32-binutils aarch64-elf-binutils
```

That's it! No PATH modifications, no complex setup.

## How It Works

### bin/ Directory
The `bin/` directory contains symlinks to MacPorts cross-compiler tools:
- `x86_64-elf-gcc`, `x86_64-elf-ld`, `x86_64-w64-mingw32-objcopy`
- `i686-elf-gcc`, `i686-elf-ld`, `i686-w64-mingw32-objcopy`

The `setup-toolchain.sh` script creates these symlinks automatically.

### build_via_macports_on_mac.sh
The main build script that:
- Auto-detects tools in `./bin/`
- Builds all three EFI binaries in parallel or sequentially
- Generates:
  - `ABZ_Shutdown_x64.efi` (49 KB - x86_64 architecture)
  - `ABZ_Shutdown_ia32.efi` (36 KB - 32-bit x86)
  - `ABZ_Shutdown_aa64.efi` (optional - ARM 64-bit, requires additional toolchain)

## Build Options

```bash
# Build all architectures in sequence (recommended)
./build_all.sh                     # Wrapper that runs all builds for x64, ia32, and aarch64 (if available)

# Build individual architectures
./build_shutdown.sh                # Native architecture (detected automatically)
./build_shutdown.sh x64            # Build x64 only
./build_shutdown.sh ia32           # Build 32-bit x86 only
./build_shutdown.sh aarch64        # Build aarch64 (if toolchain installed)

# Show help for available options
./build_shutdown.sh --help
```

## Testing on Other Units

To test on other macOS machines with MacPorts:

1. **Install MacPorts Tools** (if not already installed):
   ```bash
   sudo port install x86_64-elf-gcc i686-elf-gcc \
     x86_64-w64-mingw32-binutils i686-w64-mingw32-binutils
   ```

2. **Set Up Symlinks**:
   ```bash
   cd /path/to/Abz_Shutdown
   ./setup-toolchain.sh
   ```

3. **Build**:
   ```bash
   ./build_via_macports_on_mac.sh
   ```

That's all! No PATH or environment variable setup needed.

## Architecture Support

| Architecture | Status | Binary | Source |
|---|---|---|---|
| x86_64 | ✅ Ready | ABZ_Shutdown_x64.efi (48 KB) | MacPorts |
| ia32 | ✅ Ready | ABZ_Shutdown_ia32.efi (36 KB) | MacPorts |
| aarch64 | ⏳ Optional | ABZ_Shutdown_aa64.efi | ARM GNU Toolchain |

### Adding aarch64 Support

To enable ARM64 builds, see [Macports.md](./Macports.md) for detailed instructions and version compatibility notes.

## File Formats

All generated EFI files are PE32/PE32+ executables:
- **x64.efi**: PE32+ (64-bit) for x86_64 UEFI
- **ia32.efi**: PE32 (32-bit) for x86 UEFI
- **aa64.efi**: PE32 (ARM) for ARM64 UEFI (when available)

Verified with:
```bash
file ABZ_Shutdown_*.efi
```

## Build Log

Detailed build output is saved to `build.log` after each build.

## Troubleshooting

### "Permission denied" on setup-toolchain.sh
```bash
chmod +x setup-toolchain.sh
```

### "x86_64-elf-gcc not found"
Make sure you ran `setup-toolchain.sh` and it reported success.

### "Unable to locate libgcc file"
This shouldn't happen after `setup-toolchain.sh`. If it does, verify MacPorts installation:
```bash
which x86_64-elf-gcc
# Should return: /opt/local/bin/x86_64-elf-gcc
```

### Build fails on another unit
Follow the "Testing on Other Units" section above - need to:
1. Install MacPorts tools
2. Run `./setup-toolchain.sh`
3. Then `./build_via_macports_on_mac.sh`

## Project Structure

```
Abz_Shutdown/
├── bin/                          # Symlinks to cross-compiler tools
│   ├── x86_64-elf-gcc → /opt/local/bin/...
│   ├── x86_64-elf-ld
│   ├── x86_64-w64-mingw32-objcopy
│   ├── i686-elf-gcc
│   ├── i686-elf-ld
│   ├── i686-w64-mingw32-objcopy
│   └── aarch64-none-elf-* (optional)
├── Macports.md                   # MacPorts toolchain setup guide
├── setup-toolchain.sh                # Auto-create symlinks
├── build_via_macports_on_mac.sh      # Main build script (MacPorts on macOS)
├── build_shutdown.sh                 # Core build logic
├── build_aarch64.sh              # ARM64 specific build
├── shutdown.c                    # Source code
├── gnuefi/                        # Bundled GNU-EFI
├── ABZ_Shutdown_x64.efi          # ✅ Generated (48 KB)
├── ABZ_Shutdown_ia32.efi         # ✅ Generated (36 KB)
├── ABZ_Shutdown_aa64.efi         # Optional (when toolchain added)
└── build.log                     # Build output log
```

---

**Status**: ✅ Fully standalone build system ready for testing on other units!
