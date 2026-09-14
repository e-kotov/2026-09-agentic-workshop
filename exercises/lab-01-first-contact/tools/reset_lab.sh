#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
lab_root="$(cd -- "$script_dir/.." && pwd -P)"
expected_basename="lab-01-first-contact"
if [[ "$(basename -- "$lab_root")" != "$expected_basename" ]]; then
  printf 'FAIL refusing unexpected lab directory: %s\n' "$lab_root" >&2
  exit 1
fi

if [[ "${1:-}" != "--archive" || "$#" -ne 1 ]]; then
  printf '%s\n' 'Usage: bash tools/reset_lab.sh --archive' 'Archives this lab work/ and recreates an empty work/.' 'A bare invocation makes no changes.'
  exit 0
fi

work="$lab_root/work"
archive_root="$lab_root/.reset-archive"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
archive="$archive_root/$stamp"
if [[ -e "$archive" ]]; then
  suffix=1
  while [[ -e "$archive-$suffix" ]]; do suffix=$((suffix + 1)); done
  archive="$archive-$suffix"
fi
mkdir -p -- "$archive"
if [[ -e "$work" ]]; then
  mv -- "$work" "$archive/work"
  printf 'Archived previous work at: %s\n' "$archive/work"
fi
mkdir -p -- "$work"
: > "$work/.gitkeep"
printf 'Created fresh work directory: %s\n' "$work"
