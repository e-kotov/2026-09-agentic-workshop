#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
lab_root="$(cd -- "$script_dir/.." && pwd -P)"
[[ "$(basename -- "$lab_root")" == "lab-03-security" ]] || { echo "FAIL refusing unexpected lab directory: $lab_root" >&2; exit 1; }
work="$lab_root/work"
if [[ ! -e "$work" ]]; then
  mkdir -p -- "$work"
  : >"$work/.gitkeep"
  echo "Created empty writable directory: $work"
  exit 0
fi
[[ -d "$work" ]] || { echo "FAIL work exists but is not a directory: $work" >&2; exit 1; }
nonstarter="$(find "$work" -mindepth 1 -maxdepth 1 ! -name .gitkeep ! -name README.md -print -quit)"
if [[ -n "$nonstarter" ]]; then
  echo "FAIL refusing to overwrite non-empty work; use tools/reset_lab.sh --archive: $work" >&2
  exit 1
fi
echo "Writable directory is ready: $work"
