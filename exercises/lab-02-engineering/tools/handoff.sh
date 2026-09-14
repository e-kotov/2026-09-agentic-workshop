#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LAB_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
[ "$(basename "$LAB_ROOT")" = "lab-02-engineering" ] || { echo "FAIL wrong lab basename" >&2; exit 1; }
cd "$LAB_ROOT"
if ! Rscript checks/check_lab2.R >/dev/null; then
  echo "FAIL export unavailable: the exact standalone checker must pass first" >&2
  exit 1
fi
payload=(
  derived/person_wave.csv
  derived/person_household_wave.csv
  qa/duplicate-proof.csv
  qa/join-qa.csv
  qa/wave-qa.csv
  tests/test_panel_contract.R
  git-recovery.txt
  invalidation-evidence.txt
)
echo "Allowlist (copied, never moved):"
for file in "${payload[@]}"; do echo "  work/$file"; done
for file in "${payload[@]}"; do [ -f "work/$file" ] || { echo "FAIL missing work/$file" >&2; exit 1; }; done
destination="$LAB_ROOT/../workshop-project/lab-02"
mkdir -p "$destination/derived" "$destination/qa" "$destination/tests"
overwrite=false
if [ "${1:-}" = "--overwrite-reviewed" ]; then overwrite=true; elif [ "$#" -gt 0 ]; then echo "FAIL unknown argument" >&2; exit 1; fi
for file in "${payload[@]}"; do
  if [ -e "$destination/$file" ] && [ "$overwrite" != true ]; then
    echo "FAIL destination already contains $destination/$file; review separately and use --overwrite-reviewed" >&2
    exit 1
  fi
done
if [ "$overwrite" = true ]; then
  printf '%s' 'Type EXPORT lab-02 OVERWRITE to copy reviewed replacements: '
  read -r confirmation
  [ "$confirmation" = "EXPORT lab-02 OVERWRITE" ] || { echo "FAIL export cancelled" >&2; exit 1; }
else
  printf '%s' 'Type EXPORT lab-02 to copy this reviewed payload: '
  read -r confirmation
  [ "$confirmation" = "EXPORT lab-02" ] || { echo "FAIL export cancelled" >&2; exit 1; }
fi
for file in "${payload[@]}"; do
  mkdir -p "$destination/$(dirname "$file")"
  cp -- "work/$file" "$destination/$file"
done
echo "PASS copied reviewed Lab 2 payload to $destination"
