#!/usr/bin/env bash
# Fix-efi-on-termux.sh - Convert aarch64 ELF .so to proper PE/COFF EFI on Termux
#
# Usage:
#   ./Fix-efi-on-termux.sh              # converts ABZ_Shutdown_aa64.so -> ABZ_Shutdown_aa64.efi
#   ./Fix-efi-on-termux.sh input.so     # converts input.so -> input.efi
#   ./Fix-efi-on-termux.sh input.so output.efi  # converts input.so -> output.efi
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case $# in
  0) IN="$SCRIPT_DIR/ABZ_Shutdown_aa64.so"
     OUT="$SCRIPT_DIR/ABZ_Shutdown_aa64.efi" ;;
  1) IN="$1"
     OUT="${1%.*}.efi" ;;
  2) IN="$1"
     OUT="$2" ;;
  *) echo "Usage: $0 [input.so] [output.efi]" >&2; exit 1 ;;
esac

if [ ! -f "$IN" ]; then
  echo "[ERROR] Input not found: $IN" >&2
  exit 1
fi

CONVERTER="$SCRIPT_DIR/elf2efi.py"
if [ ! -f "$CONVERTER" ]; then
  echo "[ERROR] Converter not found: $CONVERTER" >&2
  exit 1
fi

python3 "$CONVERTER" "$IN" "$OUT"
