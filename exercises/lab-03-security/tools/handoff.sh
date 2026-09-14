#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
lab_root="$(cd -- "$script_dir/.." && pwd -P)"
[[ "$(basename -- "$lab_root")" == "lab-03-security" ]] || { echo "FAIL refusing unexpected lab directory: $lab_root" >&2; exit 1; }
if ! python "$lab_root/checks/check_lab3.py" >/dev/null; then
  echo "FAIL export unavailable until the standalone checker passes." >&2
  exit 1
fi
destination="$lab_root/../workshop-project/lab-03"
payload=(threat-control.md BOUNDARY.md evidence/manifest.txt evidence/permission.md evidence/injection.md evidence/redaction.txt)
echo 'Allowlist (copied, sanitized, never moved):'
printf '  %s\n' "${payload[@]}"
echo 'Excluded: fixture/, checks/, tools/, raw fake token values, .git/, caches, and reset archives.'
overwrite=false
if [[ "${1:-}" == "--overwrite-reviewed" ]]; then
  overwrite=true
elif [[ "$#" -gt 0 ]]; then
  echo 'FAIL unknown argument' >&2
  exit 1
fi
for file in "${payload[@]}"; do
  [[ -f "$lab_root/work/$file" ]] || { echo "FAIL missing work/$file" >&2; exit 1; }
done
for file in "${payload[@]}"; do
  if [[ -e "$destination/$file" && "$overwrite" != true ]]; then
    echo "FAIL refusing to overwrite existing payload: $destination/$file" >&2
    exit 1
  fi
done
if [[ "$overwrite" == true ]]; then
  printf 'Type exactly "EXPORT lab-03 OVERWRITE" to continue: '
  read -r confirmation
  [[ "$confirmation" == 'EXPORT lab-03 OVERWRITE' ]] || { echo 'FAIL export cancelled'; exit 1; }
else
  printf 'Type exactly "EXPORT lab-03" to continue: '
  read -r confirmation
  [[ "$confirmation" == 'EXPORT lab-03' ]] || { echo 'FAIL export cancelled'; exit 1; }
fi
mkdir -p -- "$destination/evidence"
sanitize() {
  sed -e 's/FAKE_TOKEN_1234/[FAKE-TOKEN-REDACTED]/g' \
      -e 's/FAKE_TOKEN=[^[:space:]]*/FAKE_TOKEN=[REDACTED]/g' \
      -e 's/FAKE_PERSON_ID=[^[:space:]]*/FAKE_PERSON_ID=[REDACTED]/g' \
      -e 's/not-real@example\.invalid/[EMAIL-REDACTED]/g' "$1"
}
for file in "${payload[@]}"; do
  mkdir -p -- "$destination/$(dirname -- "$file")"
  sanitize "$lab_root/work/$file" >"$destination/$file"
done
echo "PASS copied reviewed sanitized Lab 3 payload to $destination"
