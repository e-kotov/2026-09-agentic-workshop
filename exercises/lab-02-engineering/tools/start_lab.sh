#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LAB_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
[ "$(basename "$LAB_ROOT")" = "lab-02-engineering" ] || { echo "FAIL wrong lab basename: $LAB_ROOT" >&2; exit 1; }
WORK="$LAB_ROOT/work"
if [ -e "$WORK/.started" ]; then
  echo "FAIL work/ is already initialized; review it or run bash tools/reset_lab.sh --archive" >&2
  exit 1
fi
if [ -e "$WORK" ]; then
  if [ -n "$(find "$WORK" -mindepth 1 -maxdepth 1 ! -name .gitkeep -print -quit)" ]; then
    echo "FAIL work/ is non-empty; review it or run bash tools/reset_lab.sh --archive" >&2
    exit 1
  fi
else
  mkdir -p "$WORK"
fi
touch "$WORK/.gitkeep"
touch "$WORK/.started"
echo "PASS started lab-local work directory: $WORK"
echo "Edit only work/; fixture/, checks/, and tools/ are read-only."
