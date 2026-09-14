#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
lab_root="$(cd -- "$script_dir/.." && pwd -P)"
expected_basename="lab-01-first-contact"
if [[ "$(basename -- "$lab_root")" != "$expected_basename" ]]; then
  printf 'FAIL refusing unexpected lab directory: %s\n' "$lab_root" >&2
  exit 1
fi

work="$lab_root/work"
if [[ ! -e "$work" ]]; then
  mkdir -p -- "$work"
  : > "$work/.gitkeep"
  printf 'Created empty writable directory: %s\n' "$work"
  exit 0
fi
if [[ ! -d "$work" ]]; then
  printf 'FAIL work exists but is not a directory: %s\n' "$work" >&2
  exit 1
fi

nonstarter="$(find "$work" -mindepth 1 -maxdepth 1 ! -name .gitkeep -print -quit)"
if [[ -n "$nonstarter" ]]; then
  printf 'FAIL refusing to overwrite non-empty work; use tools/reset_lab.sh --archive: %s\n' "$work" >&2
  exit 1
fi
printf 'Writable directory is ready: %s\n' "$work"
