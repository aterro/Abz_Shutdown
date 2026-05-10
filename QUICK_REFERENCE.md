# Quick Reference - ABZ_Shutdown with GNU-EFI

## Build Commands

### Standard Build
```bash
cd ~/Abz_Shutdown
./build_shutdown.sh
```

The main build script now prefers bundled GNU-EFI files in `./gnuefi/` and falls
back to an external `../gnu-efi/` source tree only when needed.

### Clean Build
```bash
cd ~/Abz_Shutdown
CLEAN_BUILD=1 ./build_shutdown.sh
```

### Manual Build (Advanced)
```bash
cd ~/Abz_Shutdown
export GNUEFI_INCLUDE_DIR=~/gnu-efi/inc
export GNUEFI_LIB_DIR=~/gnu-efi/aarch64/gnuefi
export LDSCRIPT=~/gnu-efi/gnuefi/elf_aarch64_efi.lds
export CRT0=~/gnu-efi/aarch64/gnuefi/crt0-efi-aarch64.o
./build_shutdown.sh
```

## Rebuild GNU-EFI

```bash
cd ~/gnu-efi
make clean
make
ln -sf ../lib/libefi.a aarch64/gnuefi/libefi.a
```

## File Locations

| File | Location |
|------|----------|
| Built binary | `~/Abz_Shutdown/ABZ_Shutdown_aa64.efi` |
| Source code | `~/Abz_Shutdown/shutdown.c` |
| Build script | `~/Abz_Shutdown/build_shutdown.sh` |
| Bundled GNU-EFI | `~/Abz_Shutdown/gnuefi/` |
| External GNU-EFI sources | `~/gnu-efi/` |

## Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `GNUEFI_INCLUDE_DIR` | GNU-EFI headers | `~/gnu-efi/inc` |
| `GNUEFI_LIB_DIR` | GNU-EFI libraries | `~/gnu-efi/aarch64/gnuefi` |
| `LDSCRIPT` | Linker script | `~/gnu-efi/gnuefi/elf_aarch64_efi.lds` |
| `CRT0` | Startup object | `~/gnu-efi/aarch64/gnuefi/crt0-efi-aarch64.o` |
| `CLEAN_BUILD` | Clean before build | `1` |
| `BUILD_DIR` | Output directory | `.` (default) |
| `LLVM_PREFIX` | LLVM/clang installation directory | auto-detected |

## Toolchain Detection

The build script automatically detects and adapts to:
- **Compiler**: GCC vs Clang
- **Linker**: GNU ld vs LLD (LLVM)
- **objcopy**: GNU objcopy vs llvm-objcopy
- **Object format**: ELF vs COFF/PE (switches to LLVM/clang on mingw32)

No manual configuration needed!

## Platform Support

| Platform | Toolchain | Status |
|----------|-----------|--------|
| Termux (this) | Clang/LLVM | ✅ Working |
| Linux | GCC/GNU | ✅ Compatible |
| macOS | Cross | ✅ Compatible |
| Windows (WSL) | Linux GCC/GNU | ✅ Working |
| Windows (MSYS2/mingw32) | GCC (auto-switches to LLVM/clang for ELF) | ✅ Working |
| Windows (LLVM/clang) | Clang/LLD | ✅ Working |

## Output

- **File**: `ABZ_Shutdown_aa64.efi`
- **Size**: ~158 KB
- **Type**: UEFI application
- **Conversion**: GNU objcopy (`-O efi-app-*`) or llvm-objcopy (section-based)

## Documentation

- `INTEGRATION_COMPLETE.md` - Integration summary
- `GNU_EFI_INTEGRATION.md` - Technical details
- `BUILD_GUIDE.md` - General build guide
- `README_COMPREHENSIVE.md` - Usage documentation

## Troubleshooting

### Libraries not found
```bash
cd ~/gnu-efi && make
ln -sf ../lib/libefi.a aarch64/gnuefi/libefi.a
```

### Build fails
Check you're in the right directory:
```bash
cd ~/Abz_Shutdown
pwd  # Should show .../Abz_Shutdown
```

### Different architecture
The build script auto-detects, but you can override:
```bash
./build_shutdown.sh x86_64
```
