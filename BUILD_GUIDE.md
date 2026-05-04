# ABZ_Shutdown.efi - Quick Start & Build Guide

## What is ABZ_Shutdown.efi?

**ABZ_Shutdown.efi** is a standalone UEFI application that shuts down your computer using ACPI tables. It's completely independent from rEFInd and only requires GNU-EFI to build.

## Quick Start (5 Minutes)

### 1. Install Dependencies
```bash
sudo apt-get update
sudo apt-get install build-essential gnu-efi
```

### 2. Build the Binary
```bash
cd shutdown_efi
./build_shutdown.sh
```

### 3. Use the Binary
```bash
# The binary is now ready: ABZ_Shutdown_x64.efi
ls -lh ABZ_Shutdown_x64.efi

# Copy to your EFI partition (optional)
sudo cp ABZ_Shutdown_x64.efi /boot/efi/EFI/
```

## Files Explained

| File | Purpose | Required? |
|------|---------|-----------|
| `shutdown.c` | Full source code | ✅ Yes |
| `build_shutdown.sh` | Build script | ✅ Yes |
| `ABZ_Shutdown_x64.efi` | Compiled binary | ⏱️ Generated |
| `README_COMPREHENSIVE.md` | Detailed documentation | 📖 Reference |
| `README.md` | Overview | 📖 Reference |
| `Makefile` | rEFInd integration (optional) | ❌ No |

## Building Methods

### Method 1: Standalone Build Script (Recommended)
```bash
./build_shutdown.sh
```
✅ Works anywhere
✅ Auto-detects architecture
✅ Checks dependencies
✅ No external makefiles

### Method 2: Using Makefile
```bash
make
```
⚠️ Requires rEFInd directory structure
⚠️ Less portable

## Common Commands

```bash
# Standard build
./build_shutdown.sh

# Clean build (remove old artifacts)
CLEAN_BUILD=1 ./build_shutdown.sh

# Force specific architecture
./build_shutdown.sh x86_64

# Build with custom SBAT signing
SHUTDOWN_SBAT_CSV=/path/to/sbat.csv ./build_shutdown.sh

# View build help (check dependencies)
./build_shutdown.sh --help  # (shows checks)
```

## Build Output

```
Depending on your architecture:
✓ ABZ_Shutdown_x64.efi     (64-bit Intel/AMD systems)
✓ ABZ_Shutdown_ia32.efi    (32-bit Intel/AMD systems)
✓ ABZ_Shutdown_aa64.efi    (ARM 64-bit systems)
```

Size: ~41 KB

## Usage

### From UEFI Shell
```bash
fs0:\EFI\ABZ_Shutdown_x64.efi
```

### From UEFI Boot Menu
1. Add as EFI boot entry
2. Select from boot menu
3. System shuts down via ACPI

### Programmatically
```c
// Can be called from other UEFI applications
EFI_STATUS status = ShellExecuteEx(..., L"ABZ_Shutdown_x64.efi", ...);
```

## System Requirements

### To Build
- Ubuntu/Debian: `build-essential`, `gnu-efi`
- Fedora: `gcc`, `make`, `gnu-efi-devel`
- Arch: `base-devel`, `gnu-efi`

### To Run
- UEFI-capable system
- x86/x86-64 with ACPI (or ACPI-capable architecture)
- EFI System Partition (ESP)

## Troubleshooting

### "Command not found: gcc"
```bash
sudo apt-get install build-essential
```

### "No /usr/include/efi directory"
```bash
sudo apt-get install gnu-efi
```

### "Permission denied"
```bash
chmod +x build_shutdown.sh
```

### Build succeeds but binary doesn't work on actual system
- Ensure ACPI is enabled in BIOS/UEFI settings
- Try on a different system
- Check if Secure Boot blocks unsigned binaries

## Independent Use

To use ABZ_Shutdown.efi completely separate from rEFInd:

```bash
# Create new project directory
mkdir -p ~/my-abz-shutdown
cd ~/my-abz-shutdown

# Copy just 2 files from shutdown_efi/
cp /path/to/shutdown_efi/shutdown.c .
cp /path/to/shutdown_efi/build_shutdown.sh .

# Build
chmod +x build_shutdown.sh
./build_shutdown.sh

# Done! ABZ_Shutdown_x64.efi is ready to use
```

## Documentation

- **README_COMPREHENSIVE.md** - Full documentation with all details
- **README.md** - Quick overview
- **STANDALONE_REQUIREMENTS.txt** - System requirements
- **BUILD_GUIDE.md** - This file

## Architecture Support

| Architecture | Support | Notes |
|-------------|---------|-------|
| x86_64 | ✅ Full | Default, recommended |
| ia32 | ✅ Full | 32-bit Intel/AMD |
| aarch64 | ⚠️ Limited | Compiles but ACPI not used on ARM |

## Performance

- Binary size: 41 KB
- Build time: 1-2 seconds
- Startup time: < 1 second
- Shutdown time: 1-2 seconds

## Version Info

```
ABZ_Shutdown.efi
Version: 1.0
Based on: rEFInd shutdown functionality
Build Date: 2026-05-04
Status: Ready to use
```

## Next Steps

1. ✅ Build: `./build_shutdown.sh`
2. ✅ Test: Boot from the binary
3. ✅ Deploy: Copy to your ESP
4. ✅ Integrate: Add as UEFI boot option

For detailed information, see **README_COMPREHENSIVE.md**.

---

**Questions?** Check README_COMPREHENSIVE.md for in-depth documentation.

**Found an issue?** Verify:
1. GNU-EFI is installed correctly
2. ACPI is enabled on your system
3. UEFI firmware supports the binary
