#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LAB_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
[ "$(basename "$LAB_ROOT")" = "lab-02-engineering" ] || { echo "FAIL wrong lab basename: $LAB_ROOT" >&2; exit 1; }
WORK="$LAB_ROOT/work"
ARCHIVE_ROOT="$LAB_ROOT/.reset-archive"
if [ "${1:-}" != "--archive" ]; then
  echo "Usage: bash tools/reset_lab.sh --archive"
  echo "Targets: this lab's work/ only; archive: .reset-archive/<UTC stamp>/"
  exit 0
fi
if [ "$#" -ne 1 ]; then echo "FAIL unexpected arguments" >&2; exit 1; fi
if [ -e "$WORK" ]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  destination="$ARCHIVE_ROOT/$stamp"
  mkdir -p "$ARCHIVE_ROOT"
  while [ -e "$destination" ]; do stamp="$(date -u +%Y%m%dT%H%M%SZ)-$RANDOM"; destination="$ARCHIVE_ROOT/$stamp"; done
  mv -- "$WORK" "$destination"
  echo "PASS archived lab work at $destination"
fi
mkdir -p "$WORK"
touch "$WORK/.gitkeep"
echo "PASS recreated empty lab work at $WORK"
