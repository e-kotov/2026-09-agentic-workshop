#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
lab_root="$(cd -- "$script_dir/.." && pwd -P)"
[[ "$(basename -- "$lab_root")" == "lab-03-security" ]] || { echo "FAIL refusing unexpected lab directory: $lab_root" >&2; exit 1; }
if [[ "${1:-}" != "--archive" || "$#" -ne 1 ]]; then
  printf '%s\n' 'Usage: bash tools/reset_lab.sh --archive' 'Archives this lab work/ and recreates an empty work/.' 'A bare invocation makes no changes.'
  exit 0
fi
work="$lab_root/work"
archive_root="$lab_root/.reset-archive"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
archive="$archive_root/$stamp"
suffix=1
while [[ -e "$archive" ]]; do archive="$archive_root/${stamp}-${suffix}"; suffix=$((suffix + 1)); done
mkdir -p -- "$archive"
if [[ -e "$work" ]]; then
  mv -- "$work" "$archive/work"
  echo "Archived previous work at: $archive/work"
fi
mkdir -p -- "$work"
if [[ -f "$archive/work/README.md" ]]; then
  cp -- "$archive/work/README.md" "$work/README.md"
fi
: >"$work/.gitkeep"
echo "Created fresh work directory: $work"
