# Bundled GNU-EFI Files

## Overview

This directory contains pre-built GNU-EFI libraries and headers to make building ABZ_Shutdown.efi easier, especially on Termux and other environments where installing gnu-efi system-wide is difficult.

## Contents

### Headers (`inc/`)
Complete set of GNU-EFI header files (version 4.0.3):
- Core EFI headers (efi.h, efilib.h, etc.)
- Protocol definitions
- Architecture-specific headers for aarch64, x86_64, ia32

### Libraries (`lib/`)

#### `lib/aarch64/` (ARM 64-bit)
- `libefi.a` - Main EFI library (599 KB)
- `libgnuefi.a` - GNU-EFI glue code (22 KB)
- `crt0-efi-aarch64.o` - Startup object file
- `elf_aarch64_efi.lds` - Linker script

#### `lib/x86_64/` (Intel/AMD 64-bit)
- `libefi.a` - Main EFI library
- `libgnuefi.a` - GNU-EFI glue code
- `crt0-efi-x86_64.o` - Startup object file
- Linker script: `elf_x86_64_efi.lds`

#### `lib/ia32/` (Intel/AMD 32-bit)
- Pre-built libraries for ia32 (when available)
- Linker script: `elf_ia32_efi.lds`

## How It Works

The `build_shutdown.sh` script automatically detects and uses these bundled files:

1. **First**: Checks `gnuefi/` directory in the project
2. **Second**: Falls back to system-wide gnu-efi installation
3. **Third**: Falls back to custom paths via environment variables

## Building

With bundled files, building is now as simple as:

```bash
cd /path/to/Abz_Shutdown
./build_shutdown.sh
```

No environment variables or external dependencies needed!

## Architecture Support

The bundled files currently include:
- ✅ **aarch64** (ARM 64-bit) - Full support, pre-built
- ✅ **x86_64** (Intel/AMD 64-bit) - Full support, pre-built
- ⏳ **ia32** (Intel/AMD 32-bit) - Linker script included, libraries TBD

## Benefits

### For Termux Users
- No need to install gnu-efi package
- No need to build gnu-efi from source
- Just clone and build!

### For All Users
- Faster setup
- Guaranteed compatible versions
- Portable across systems
- No root/admin access needed

## Source

These files are built from **GNU-EFI version 4.0.3**:
- Source: https://sourceforge.net/projects/gnu-efi/
- License: BSD (see ../LICENSE or gnu-efi source)
- Build date: 2025-01-05
- Built on: Termux proot Debian (aarch64)
- Toolchain: Clang 21.1.8

## Updating

To update the bundled libraries:

1. Build gnu-efi from source for your architecture
2. Copy files to appropriate `lib/<arch>/` directory:
   ```bash
   cp path/to/gnu-efi/<arch>/lib/libefi.a gnuefi/lib/<arch>/
   cp path/to/gnu-efi/<arch>/gnuefi/libgnuefi.a gnuefi/lib/<arch>/
   cp path/to/gnu-efi/<arch>/gnuefi/crt0-efi-<arch>.o gnuefi/lib/<arch>/
   cp path/to/gnu-efi/gnuefi/elf_<arch>_efi.lds gnuefi/lib/<arch>/
   ```

## Size

Total bundled size:
- Headers: ~500 KB (82 files)
- aarch64 libraries: ~630 KB (4 files)
- Total: ~1.1 MB

This is small enough to commit to git and makes the project completely self-contained.

## Compatibility

The bundled files work with:
- ✅ Clang/LLVM toolchain
- ✅ GCC/GNU toolchain
- ✅ Cross-compilation toolchains

The build script automatically adapts based on detected toolchain.

## License

GNU-EFI is licensed under BSD license. See the main project LICENSE file for details.
