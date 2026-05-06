# Building on Termux - Quick Start

## Overview

The repository includes bundled GNU-EFI files, but Termux still needs an `objcopy` that can emit a real EFI target such as `efi-app-x86_64` or `efi-app-aarch64`.

`llvm-objcopy` without EFI target support is **not enough**. The build script now stops instead of producing an ELF file with a `.efi` extension.

## Quick Check

```bash
cd ~/Abz_Shutdown
pkg install build-essential
objcopy --help | grep efi-app
```

If that command shows the EFI target you need, build normally:

```bash
./build_shutdown.sh
```

## If Termux Has No EFI-Capable objcopy

Use a Debian or Ubuntu proot environment:

```bash
pkg install proot-distro
proot-distro install debian
proot-distro login debian
apt-get update
apt-get install build-essential gnu-efi binutils
```

Then build inside the proot shell:

```bash
cd /path/to/Abz_Shutdown
objcopy --help | grep efi-app
./build_shutdown.sh
```

If the EFI-capable `objcopy` lives outside your default `PATH`, point the script at it explicitly:

```bash
OBJCOPY=/path/to/objcopy ./build_shutdown.sh
```

## Architecture Notes

- `x86_64`: the useful target for a normal PC UEFI shell
- `ia32`: for 32-bit x86 firmware
- `aarch64`: builds are possible only with an EFI-capable `objcopy`, but this repo currently returns `FALSE` on ARM64 at runtime instead of performing ACPI shutdown

## Troubleshooting

### "No objcopy with EFI target support"

Your current Termux environment cannot emit a real EFI binary yet.

Try:

```bash
pkg install build-essential
objcopy --help | grep efi-app
```

If there is still no `efi-app-*` target, switch to the proot flow above.

### The file builds but does not start in UEFI

Check that the output is really a PE/COFF EFI application, not ELF renamed to `.efi`.

### ARM64 output does not shut the machine down

That is expected in this repo for now. The `aarch64` path is intentionally disabled in `shutdown.c`.
