#!/usr/bin/env bash
set -eu
before=$(sha256sum fixture/fake-output.txt)
masked=$(python tools/redact_output.py fixture/fake-output.txt)
printf '%s' "$masked" | grep -F 'token=[REDACTED]' >/dev/null
printf '%s' "$masked" | grep -F '[EMAIL-REDACTED]' >/dev/null
after=$(sha256sum fixture/fake-output.txt)
test "$before" = "$after"
echo "baseline masked; source unchanged"
echo "split bypass (expected unmasked):"
python tools/redact_output.py fixture/fake-output-split.txt
echo "encoded bypass (expected opaque):"
python tools/redact_output.py fixture/fake-output-encoded.txt
