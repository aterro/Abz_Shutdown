# Building on Termux - Quick Start

## Overview

ABZ_Shutdown now includes **bundled GNU-EFI files** for aarch64, making it incredibly easy to build on Termux without any external dependencies!

## Super Quick Build (3 Steps)

```bash
# 1. Navigate to the project
cd ~/Abz_Shutdown

# 2. Build (that's it!)
./build_shutdown.sh

# 3. Your binary is ready!
ls -lh ABZ_Shutdown_aa64.efi
```

That's all! No installing packages, no building dependencies, no environment variables needed.

## What Changed?

Previously on Termux, you needed to:
1. Clone gnu-efi sources separately
2. Build gnu-efi from source
3. Set environment variables pointing to gnu-efi
4. Follow a separate local-GNU-EFI build flow

**Now on Termux:**
1. Just run `./build_shutdown.sh` ✅

The project now includes pre-built gnu-efi libraries in the `gnuefi/` directory specifically for aarch64 (ARM 64-bit), which is what Termux uses.

## How It Works

The build script (`build_shutdown.sh`) automatically:
1. Detects your architecture (aarch64)
2. Finds the bundled gnu-efi files in `gnuefi/lib/aarch64/`
3. Uses your system's Clang/LLVM toolchain
4. Builds ABZ_Shutdown_aa64.efi

No configuration needed!

## Build Output

```
================================
  ABZ_Shutdown.efi Build Script
================================

[INFO] Host OS detected: Linux
[INFO] Building for architecture: aarch64
[INFO] Checking dependencies...
[INFO] Using bundled GNU-EFI files for aarch64
[INFO] Using toolchain: CC=gcc LD=ld OBJCOPY=objcopy
[INFO] Using GNU-EFI: include=.../gnuefi/inc lib=.../gnuefi/lib/aarch64
[INFO] All dependencies found!
[INFO] Detected llvm-objcopy (will use default binary conversion)
[INFO] Compilation flags configured
[INFO] Compiling shutdown.c...
[INFO] Linking ./ABZ_Shutdown_aa64.so...
[INFO] Converting to EFI binary: ./ABZ_Shutdown_aa64.efi...
[INFO] Adding SBAT section...
[INFO] Build complete: ./ABZ_Shutdown_aa64.efi

[INFO] Build successful!
Binary: ./ABZ_Shutdown_aa64.efi
```

## File Structure

```
Abz_Shutdown/
├── shutdown.c                    # Source code
├── build_shutdown.sh             # Build script (just run this!)
├── gnuefi/                       # Bundled GNU-EFI files
│   ├── inc/                      # Headers (82 files)
│   └── lib/
│       └── aarch64/              # ARM64 libraries
│           ├── libefi.a
│           ├── libgnuefi.a
│           ├── crt0-efi-aarch64.o
│           └── elf_aarch64_efi.lds
└── ABZ_Shutdown_aa64.efi         # Your built binary!
```

## Requirements

Termux comes with everything you need:
- ✅ Clang compiler (pre-installed)
- ✅ LLD linker (pre-installed)
- ✅ llvm-objcopy (pre-installed)
- ✅ GNU-EFI files (bundled in project!)

## Advanced Usage

### Clean Build
```bash
CLEAN_BUILD=1 ./build_shutdown.sh
```

### Using External GNU-EFI (Optional)
If you prefer to use your own gnu-efi installation:
```bash
export GNUEFI_INCLUDE_DIR=/path/to/gnu-efi/inc
export GNUEFI_LIB_DIR=/path/to/gnu-efi/lib
./build_shutdown.sh
```

The build script will prioritize bundled files unless you explicitly set these variables.

## Other Platforms

### Linux with Installed GNU-EFI
The build script automatically falls back to system gnu-efi:
```bash
# Install gnu-efi (if bundled arch not available)
sudo apt-get install gnu-efi

# Build
./build_shutdown.sh
```

### macOS and Windows
See BUILD_GUIDE.md for platform-specific instructions.

## Bundled Files Info

- **Version**: GNU-EFI 4.0.3
- **License**: BSD (same as GNU-EFI)
- **Architecture**: aarch64 (ARM 64-bit)
- **Built with**: Clang 21.1.8 on Termux
- **Size**: ~1.1 MB total (630 KB libraries + 500 KB headers)
- **Location**: `gnuefi/` directory

## Why Bundle GNU-EFI?

1. **Termux-friendly**: No package installation needed
2. **Portable**: Works on any Termux installation
3. **Fast**: No need to build gnu-efi from source
4. **Reliable**: Guaranteed compatible versions
5. **Self-contained**: One repo has everything

## Troubleshooting

### Build fails with "GNU-EFI headers not found"
This shouldn't happen if you're using the bundled files. Check:
```bash
ls -la gnuefi/lib/aarch64/
```
You should see: libefi.a, libgnuefi.a, crt0-efi-aarch64.o, elf_aarch64_efi.lds

### Build fails with compiler errors
Make sure you have the basic Termux tools:
```bash
pkg install clang
```

### Binary doesn't work
The binary built here is for UEFI systems. It won't run on Android/Termux directly - it's meant to be copied to a UEFI boot partition on a PC.

## Next Steps

After building:
1. Transfer `ABZ_Shutdown_aa64.efi` to a UEFI system
2. Copy to EFI system partition
3. Add to boot menu
4. Use to shut down via UEFI

See README_COMPREHENSIVE.md for usage details.

## Questions?

- **General building**: See BUILD_GUIDE.md
- **Technical details**: See GNU_EFI_INTEGRATION.md
- **Bundled files**: See gnuefi/README.md

---

**Happy Building on Termux! 🚀**
