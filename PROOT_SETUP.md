# Proot Setup for Termux EFI Building

## Problem

Termux's default `objcopy` (from LLVM) lacks EFI target support, preventing the build of proper PE32+ EFI binaries. Without proper tooling, the build would produce fake ELF files with `.efi` extensions that won't work on UEFI systems.

## Solution

The build script now supports automatic setup of a proot Debian environment with proper GNU binutils that includes EFI-capable `objcopy`.

## Usage

### Interactive Mode (Recommended for First-Time Setup)

```bash
PROOT_SETUP=1 ./build_shutdown.sh
```

The script will ask for confirmation before:
1. Installing proot-distro package
2. Downloading and installing Debian (~500MB)
3. Installing build tools in Debian (~300MB)

You can answer `y` (yes) or `n` (no) to each prompt.

### Non-Interactive Mode (For Automation)

```bash
PROOT_SETUP=1 PROOT_AUTO_INSTALL=1 ./build_shutdown.sh
```

This automatically answers "yes" to all prompts, useful for:
- CI/CD pipelines
- Automated builds
- Non-interactive environments

### Subsequent Builds

Once proot is set up, the script auto-detects it:

```bash
PROOT_SETUP=1 ./build_shutdown.sh
```

Since tools are already installed, it will proceed directly to building.

## What Gets Installed

1. **proot-distro** - Termux package for running Linux distributions
2. **Debian distribution** - Full Debian Trixie environment (~500MB download)
3. **Build tools in Debian**:
   - `build-essential` - GCC, G++, make, etc.
   - `gnu-efi` - GNU EFI development files
   - `binutils` - GNU binary utilities including EFI-capable objcopy

## How It Works

1. **Detection**: Script checks if Termux's objcopy supports EFI targets
2. **Auto-detection**: If proot-distro with Debian is available, script suggests using it
3. **Setup**: When `PROOT_SETUP=1` is set, missing components are installed (with prompts)
4. **Build**: All compilation commands run inside the proot Debian environment
5. **Output**: Produces valid PE32+ EFI binaries instead of fake ELF files

## Environment Variables

- `PROOT_SETUP=1` - Enable proot Debian environment detection and setup
- `PROOT_AUTO_INSTALL=1` - Auto-answer 'yes' to all installation prompts (non-interactive)
- `CLEAN_BUILD=1` - Remove previous build artifacts before building

## Example Session

```bash
$ cd ~/Abz_Shutdown

# First time - interactive setup
$ PROOT_SETUP=1 ./build_shutdown.sh
[INFO] proot-distro is not installed.
Do you want to install proot-distro now? [y/n]: y
[INFO] Installing proot-distro...
...
[INFO] Debian proot distribution is not installed.
Do you want to install Debian proot distribution now? [y/n]: y
[INFO] Installing Debian proot distribution...
...
[INFO] Build complete: ./ABZ_Shutdown_aa64.efi

# Subsequent builds - no prompts needed
$ PROOT_SETUP=1 CLEAN_BUILD=1 ./build_shutdown.sh
[INFO] Proot Debian environment ready with EFI build tools
[INFO] Build complete: ./ABZ_Shutdown_aa64.efi

# Verify output
$ file ABZ_Shutdown_aa64.efi
ABZ_Shutdown_aa64.efi: PE32+ executable for EFI (application), ARM64
```

## Verification

Check if your built file is a real EFI binary:

```bash
# Should show "PE32+" not "ELF"
file ABZ_Shutdown_aa64.efi

# Should show "4d 5a" (MZ header)
head -c 2 ABZ_Shutdown_aa64.efi | od -A n -t x1
```

## Troubleshooting

### "Non-interactive mode detected, skipping prompt"

Your shell input is not a TTY. Use `PROOT_AUTO_INSTALL=1` to proceed:
```bash
PROOT_SETUP=1 PROOT_AUTO_INSTALL=1 ./build_shutdown.sh
```

### "Failed to install proot-distro"

Check your internet connection and Termux package repositories:
```bash
pkg update
pkg install proot-distro
```

### "Compilation failed" inside proot

The working directory should be automatically accessible. If you see path errors, ensure you're running from the repository root:
```bash
cd ~/Abz_Shutdown
PROOT_SETUP=1 ./build_shutdown.sh
```

### Space Issues

Proot Debian requires ~800MB total. Check available space:
```bash
df -h $PREFIX
```

## Manual Cleanup

To remove the proot environment if needed:

```bash
# Remove Debian proot
proot-distro remove debian

# Uninstall proot-distro
pkg uninstall proot-distro
```

## See Also

- [TERMUX_QUICKSTART.md](TERMUX_QUICKSTART.md) - General Termux build instructions
- [BUILD_GUIDE.md](BUILD_GUIDE.md) - Complete build documentation
