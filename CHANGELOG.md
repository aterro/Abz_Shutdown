# Changelog

All notable changes to this project are documented in this file.

## v3.0 — Improved support for old compilers (2026-05-21)

- Enhanced Windows build wrapper to detect legacy ia32/MSYS2/portable Git Bash environments.
- Added robust fallbacks when GNU objcopy cannot produce PE/COFF images (Python-based ELF→PE converter).
- Ensured Python-based fixer is available inside Windows batch-launched Bash sessions.
- Lowered aarch64 EFI size heuristic to trigger fixes earlier (70KB).
- Improved diagnostics and guidance for users on missing toolchains and objcopy BFD targets.

See README.md and BUILD_GUIDE.md for usage and troubleshooting details.
