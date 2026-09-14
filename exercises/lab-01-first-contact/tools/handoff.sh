#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
lab_root="$(cd -- "$script_dir/.." && pwd -P)"
if [[ "$(basename -- "$lab_root")" != "lab-01-first-contact" ]]; then
  printf 'FAIL refusing unexpected lab directory: %s\n' "$lab_root" >&2
  exit 1
fi

if ! check_output="$(Rscript "$lab_root/checks/check_lab1.R" 2>&1)"; then
  printf '%s\n' "$check_output" | sed -n '1,120p' >&2
  printf '%s\n' 'FAIL export unavailable until the standalone checker passes.' >&2
  exit 1
fi

destination="$lab_root/../workshop-project/lab-01"
if [[ ! -d "$destination" ]]; then
  printf 'FAIL cumulative starter is missing; initialize exercises/workshop-project first.\n' >&2
  exit 1
fi
printf '%s\n' 'Allowlist (copied, never moved):' '  corrected-questionnaire.csv' '  provenance.md' '  session-observations.md' 'Excluded: fixture/, checks/, tools/, .git/, caches, and reset archives.'
printf 'Type exactly "EXPORT lab-01" to continue: '
read -r confirmation
if [[ "$confirmation" != "EXPORT lab-01" ]]; then
  printf '%s\n' 'Export cancelled; no files were copied.'
  exit 1
fi

for filename in corrected-questionnaire.csv provenance.md session-observations.md; do
  if [[ -e "$destination/$filename" ]]; then
    printf 'FAIL refusing to overwrite existing payload: %s\n' "$destination/$filename" >&2
    exit 1
  fi
done
for filename in corrected-questionnaire.csv provenance.md session-observations.md; do
  cp -- "$lab_root/work/$filename" "$destination/$filename"
done
printf 'PASS exported reviewed Lab 1 payload to %s\n' "$destination"
