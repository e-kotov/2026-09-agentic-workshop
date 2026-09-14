#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
lab_root="$(cd -- "$script_dir/.." && pwd -P)"
cd -- "$lab_root"
python - <<'PY'
import json
from pathlib import Path

permission = json.loads(Path("opencode.json").read_text(encoding="utf-8"))["permission"]
bash = permission["bash"]
if permission.get("read") != "deny" or bash.get("*") != "allow" or bash.get("cat *") != "deny":
    raise SystemExit("expected lab-local read deny, Bash '*' allow, and 'cat *' deny")
print("static evidence: lab-local permission has read=deny, Bash '*': allow, and 'cat *': deny")
PY
echo "runtime procedure: native read fixture/security/fake-sensitive.txt should be denied"
echo "runtime procedure: cat fixture/security/fake-sensitive.txt should be denied by the specific command pattern"
echo "runtime procedure: python tools/equivalent_read.py may be allowed by broad Bash permission"
echo "This helper is static configuration evidence, not a runtime test or OS-boundary claim."
