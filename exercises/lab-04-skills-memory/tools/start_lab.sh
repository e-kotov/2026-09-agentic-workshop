#!/usr/bin/env bash
set -euo pipefail
S="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"; L="$(cd -- "$S/.." && pwd -P)"
[ "$(basename "$L")" = lab-04-skills-memory ] || { echo "FAIL wrong lab basename" >&2; exit 1; }
W="$L/work"
if [ -e "$W/.started" ]; then
  echo "FAIL work/ is already initialized; review it or run bash tools/reset_lab.sh --archive" >&2
  exit 1
fi
if [ -e "$W" ] && [ -n "$(find "$W" -mindepth 1 -maxdepth 1 ! -name .gitkeep -print -quit)" ]; then echo "FAIL work/ is non-empty; run bash tools/reset_lab.sh --archive" >&2; exit 1; fi
mkdir -p "$W"; touch "$W/.gitkeep" "$W/.started"; echo "PASS started lab-local work directory: $W"
