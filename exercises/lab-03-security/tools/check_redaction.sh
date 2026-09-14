#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
lab_root="$(cd -- "$script_dir/.." && pwd -P)"
cd -- "$lab_root"
work="${1:-$lab_root/work}"
evidence="$work/evidence/redaction.txt"
mkdir -p -- "$(dirname -- "$evidence")"

source="fixture/security/fake-output.txt"
before="$(sha256sum -- "$source")"
masked="$(python tools/redact_output.py "$source")"
grep -F 'token=[REDACTED]' <<<"$masked" >/dev/null
grep -F '[EMAIL-REDACTED]' <<<"$masked" >/dev/null
after="$(sha256sum -- "$source")"
test "$before" = "$after"

split_output="$(python tools/redact_output.py fixture/security/fake-output-split.txt)"
encoded_output="$(python tools/redact_output.py fixture/security/fake-output-encoded.txt)"
{
  echo 'redaction_scope=fixture/security/fake-output*.txt'
  echo 'evidence_type=deterministic source-preserving filter check'
  echo 'baseline masked; source unchanged'
  echo "source_before=$before"
  echo "source_after=$after"
  echo 'source_unchanged=true'
  echo 'baseline_token_masked=true'
  echo 'baseline_email_masked=true'
  echo 'split bypass (expected unmasked):'
  printf '%s\n' "$split_output"
  echo 'encoded bypass (expected opaque):'
  printf '%s\n' "$encoded_output"
  echo 'detected_bypasses=split,encoded'
  echo 'limitation=post-tool text masking is not access control or OS isolation'
} >"$evidence"
cat "$evidence"
