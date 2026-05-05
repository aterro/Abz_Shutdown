# ABZ_Shutdown Copilot Instructions

## Build, test, and lint commands

### Canonical build flow
- Use `./build_shutdown.sh` from the repository root. This is the supported standalone build entry point.
- On Windows, use `build_shutdown.bat`, which tries Git Bash/MSYS2 first and falls back to WSL when needed.
- `./build_shutdown.sh --help` shows the supported architectures and environment variables.
- `CLEAN_BUILD=1 ./build_shutdown.sh` removes previous build artifacts before compiling.
- `./build_shutdown.sh x86_64`, `./build_shutdown.sh ia32`, and `./build_shutdown.sh aarch64` force a target architecture.
- `BUILD_DIR=out ./build_shutdown.sh` writes `shutdown.o`, the intermediate `.so`, and the final `.efi` into a custom directory.
- `SHUTDOWN_SBAT_CSV=abz-shutdown.csv ./build_shutdown.sh` embeds an SBAT section when the CSV exists.
- The script auto-checks common Windows-hosted Bash prefixes such as `/usr`, `/mingw64`, `/ucrt64`, `/clang64`, `/clangarm64`, and `/c/msys64/*` for toolchains and GNU-EFI.

### Legacy build path
- `make` is only for an external GNU-EFI tree that provides `../Make.common`. Do not treat the Makefile as the default local build.

### Tests and lint
- There is no automated test suite or lint target in this repository.
- Runtime verification is manual: build the EFI binary, copy it to an EFI System Partition, and execute it from a UEFI shell, for example `fs0:\EFI\ABZ_Shutdown_x64.efi`.
- There is no single automated test command because no automated tests exist.

## High-level architecture

- This repository is essentially a single-file UEFI application plus build/docs. `shutdown.c` contains the full shutdown implementation.
- Control flow is:
  1. `efi_main()` initializes GNU-EFI and prints user-facing status.
  2. `TryAcpiShutdown()` locates the ACPI root pointer from the EFI configuration table.
  3. It walks the RSDT entries, finds the FADT, reads the PM1a control block address, and searches DSDT/SSDT AML for the `_S5_` sleep package.
  4. `AcpiGetSleepType()` and the AML helper parsers (`AcpiDecodeLength`, `AcpiSkipNameString`, `AcpiSkipDataRefObject`, `AcpiSkipTerm`, `AcpiSkipExtOp`) extract the S5 sleep type.
  5. `AcpiWritePmControl()` writes `SLP_TYP` plus `SLP_EN` to the PM control register to trigger power-off.
- On `aarch64`, `TryAcpiShutdown()` is compiled to return `FALSE`, so ARM64 builds are expected to succeed but not perform ACPI shutdown at runtime.

## Key conventions

- Keep the shutdown logic self-contained in `shutdown.c`. The project intentionally does not split ACPI parsing across multiple source files.
- Prefer updating `build_shutdown.sh` over the Makefile when changing the normal developer workflow; the script is the documented, portable build interface.
- The build script auto-detects toolchains and GNU-EFI paths, but supports overrides through `TOOLCHAIN_PREFIX`, `GNUEFI_PREFIX`, `GNUEFI_INCLUDE_DIR`, `GNUEFI_LIB_DIR`, `CC`, `LD`, `OBJCOPY`, `AR`, `RANLIB`, `LDSCRIPT`, and `CRT0`.
- SBAT embedding is optional. `build_shutdown.sh` warns when the CSV is missing instead of failing the build.
- Output names are architecture-specific and consistent with the docs and script: `ABZ_Shutdown_x64.efi`, `ABZ_Shutdown_ia32.efi`, and `ABZ_Shutdown_aa64.efi`.
- The repository includes a prebuilt `.efi` artifact, but source changes should be reasoned against `shutdown.c` and the build script rather than assuming the checked-in binary is current.
