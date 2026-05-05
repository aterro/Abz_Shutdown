# Quick Reference - ABZ_Shutdown with GNU-EFI

## Build Commands

### Standard Build
```bash
cd ~/Abz_Shutdown
./build_with_local_gnuefi.sh
```

### Clean Build
```bash
cd ~/Abz_Shutdown
CLEAN_BUILD=1 ./build_with_local_gnuefi.sh
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
| Convenience wrapper | `~/Abz_Shutdown/build_with_local_gnuefi.sh` |
| GNU-EFI sources | `~/gnu-efi/` |
| GNU-EFI libraries | `~/gnu-efi/aarch64/lib/` & `~/gnu-efi/aarch64/gnuefi/` |

## Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `GNUEFI_INCLUDE_DIR` | GNU-EFI headers | `~/gnu-efi/inc` |
| `GNUEFI_LIB_DIR` | GNU-EFI libraries | `~/gnu-efi/aarch64/gnuefi` |
| `LDSCRIPT` | Linker script | `~/gnu-efi/gnuefi/elf_aarch64_efi.lds` |
| `CRT0` | Startup object | `~/gnu-efi/aarch64/gnuefi/crt0-efi-aarch64.o` |
| `CLEAN_BUILD` | Clean before build | `1` |
| `BUILD_DIR` | Output directory | `.` (default) |

## Toolchain Detection

The build script automatically detects and adapts to:
- **Compiler**: GCC vs Clang
- **Linker**: GNU ld vs LLD (LLVM)
- **objcopy**: GNU objcopy vs llvm-objcopy

No manual configuration needed!

## Platform Support

| Platform | Toolchain | Status |
|----------|-----------|--------|
| Termux (this) | Clang/LLVM | ✅ Working |
| Linux | GCC/GNU | ✅ Compatible |
| macOS | Cross | ✅ Compatible |
| Windows | Various | ✅ Compatible |

## Output

- **File**: `ABZ_Shutdown_aa64.efi`
- **Size**: ~158 KB
- **Type**: UEFI application for ARM64
- **Format**: ELF 64-bit LSB shared object

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
The wrapper auto-detects, but you can override:
```bash
ARCH=x86_64 ./build_with_local_gnuefi.sh
```
