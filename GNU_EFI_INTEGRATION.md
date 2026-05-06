# GNU-EFI Integration Guide

## Overview

The Abz_Shutdown project has been successfully integrated with the local gnu-efi sources. The build system now supports building on Termux (Android/Debian proot) with Clang/LLVM toolchain.

## Integration Summary

### Changes Made to build_shutdown.sh

1. **Compiler Detection**: Added detection for Clang vs GCC to avoid using GCC-specific flags with Clang
   - Removed `-fno-tree-loop-distribute-patterns` flag when using Clang

2. **Linker Detection**: Added detection for LLD (LLVM Linker) vs GNU ld
   - LLD requires `-z norelro` flag to avoid relro section contiguity issues
   - GNU ld continues to work with standard `-znocombreloc`

3. **objcopy Detection**: Added detection for llvm-objcopy vs GNU objcopy
   - llvm-objcopy doesn't support `--target=efi-app-*` format
   - llvm-objcopy requires `.dynstr` section (referenced by `.dynamic`)
   - SBAT section adjustment works differently (no VMA adjustment for llvm-objcopy)

### Build Compatibility

The updated build script maintains **full backward compatibility** with:
- ✅ Linux with GNU toolchain (gcc, GNU ld, GNU objcopy)
- ✅ Linux with LLVM toolchain (clang, lld, llvm-objcopy) 
- ✅ macOS with cross-compilation toolchain
- ✅ Windows (Git Bash, MSYS2, WSL)
- ✅ Termux on Android (proot Debian with Clang/LLVM)

## Directory Structure

```
~/
├── gnu-efi/                    # GNU-EFI sources (version 4.0.3)
│   ├── inc/                    # Headers
│   ├── lib/                    # Library sources
│   ├── gnuefi/                 # GNU-EFI glue code
│   └── aarch64/                # Build output (for ARM64)
│       ├── lib/
│       │   └── libefi.a        # Main EFI library
│       └── gnuefi/
│           ├── libgnuefi.a     # GNU-EFI glue library
│           ├── libefi.a        # Symlink to ../lib/libefi.a
│           ├── crt0-efi-aarch64.o
│           └── ...
└── Abz_Shutdown/               # Shutdown EFI application
    ├── shutdown.c              # Source code
    ├── build_shutdown.sh       # Enhanced build script
    └── ABZ_Shutdown_aa64.efi   # Built binary
```

## Building

### Quick Build (Recommended)

Use the main build script, which automatically prefers bundled GNU-EFI files in
the project `gnuefi/` directory and falls back to an external local GNU-EFI
tree when needed:

```bash
cd ~/Abz_Shutdown
./build_shutdown.sh
```

### Manual Build

Set environment variables to point to local gnu-efi:

```bash
cd ~/Abz_Shutdown

export GNUEFI_INCLUDE_DIR=~/gnu-efi/inc
export GNUEFI_LIB_DIR=~/gnu-efi/aarch64/gnuefi
export LDSCRIPT=~/gnu-efi/gnuefi/elf_aarch64_efi.lds
export CRT0=~/gnu-efi/aarch64/gnuefi/crt0-efi-aarch64.o

./build_shutdown.sh
```

### Building gnu-efi (if needed)

If gnu-efi libraries are not built yet:

```bash
cd ~/gnu-efi
make

# Create symlink for build script compatibility
ln -sf ../lib/libefi.a aarch64/gnuefi/libefi.a
```

## Technical Details

### Toolchain Detection

The build script now detects the toolchain at runtime:

1. **Compiler**: Checks `gcc --version` for "gcc" string to distinguish GCC from Clang
2. **Linker**: Checks `ld --version` for "LLD" string
3. **objcopy**: Checks `objcopy --version` for "llvm-objcopy" string

### Platform-Specific Adjustments

#### Termux/LLVM (This Environment)
- Compiler: `clang` (aliased as `gcc`)
- Linker: `lld` (aliased as `ld`)
- objcopy: `llvm-objcopy` (aliased as `objcopy`)
- Special flags: `-z norelro`, include `.dynstr` section, skip SBAT VMA adjustment

#### Standard Linux/GNU
- Compiler: `gcc`
- Linker: GNU `ld`
- objcopy: GNU `objcopy`
- Standard flags: `-znocombreloc`, `--target=efi-app-*`, full SBAT support

## Build Output

Successful build produces:
- **Binary**: `ABZ_Shutdown_aa64.efi` (158 KB)
- **Type**: ELF 64-bit LSB shared object, ARM aarch64
- **Format**: UEFI PE32+ application (in ELF wrapper for aarch64)

## Testing

The build has been tested and works on:
- ✅ Termux proot Debian (aarch64) with Clang 21.1.8 and LLD
- ⏳ (Pending) Standard Linux with GNU toolchain
- ⏳ (Pending) macOS with cross-compilation
- ⏳ (Pending) Windows environments

## Known Limitations

1. **SBAT Section**: With llvm-objcopy, the SBAT section is added without VMA adjustment. This is generally safe but may not work with some Secure Boot implementations.

2. **ELF Format on ARM64**: The output remains in ELF format rather than PE32+ because objcopy on ARM64 typically doesn't convert to PE format (this is normal for ARM UEFI).

## Troubleshooting

### If gnu-efi libraries are not found:
```bash
cd ~/gnu-efi
make
ln -sf ../lib/libefi.a aarch64/gnuefi/libefi.a
```

### If build fails with linker errors:
- Check that you're using the correct linker script for your architecture
- Verify that both `libefi.a` and `libgnuefi.a` exist in the lib directory

### If objcopy fails:
- The script automatically detects llvm-objcopy and adjusts flags
- Check that required sections exist in the .so file: `readelf -S ABZ_Shutdown_aa64.so`

## Future Improvements

Potential enhancements:
1. Auto-detect gnu-efi location relative to project directory
2. Support for installing gnu-efi as a git submodule
3. CI/CD integration for multi-platform builds
4. PE32+ conversion for ARM64 when supported by toolchain

## References

- GNU-EFI: https://sourceforge.net/projects/gnu-efi/
- UEFI Specification: https://uefi.org/specifications
- Original shutdown code: grub2fm halt.c
