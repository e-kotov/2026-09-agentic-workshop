#!/usr/bin/env bash
set -euo pipefail
S="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"; L="$(cd -- "$S/.." && pwd -P)"; W="$L/work"
[ "$(basename "$L")" = lab-04-skills-memory ] || { echo "FAIL wrong lab basename" >&2; exit 1; }
n="${1:-}"; case "$n" in 1|2) ;; *) echo "Usage: bash tools/run_attempt.sh 1|2" >&2; exit 1 ;; esac
[ -f "$W/LOOP.md" ] || { echo "FAIL declare LOOP.md before attempting" >&2; exit 1; }
[ -f "$W/code/repair_release.R" ] && [ -f "$W/code/summarize_income.R" ] || { echo "FAIL deterministic code is missing" >&2; exit 1; }
log="$W/logs/attempt-$n.txt"; [ ! -e "$log" ] || { echo "FAIL attempt $n already recorded" >&2; exit 1; }
if [ "$n" = 2 ] && [ -f "$W/logs/attempt-1.txt" ] && grep -q '^check_exit=0$' "$W/logs/attempt-1.txt"; then echo "FAIL attempt 1 passed; do not manufacture attempt 2" >&2; exit 1; fi
mkdir -p "$W/logs"; set +e; output="$(Rscript "$L/checks/check_release.R" --base "$W" 2>&1)"; code=$?; set -e
{
  echo "attempt=$n"
  echo "generated_by=tools/run_attempt.sh"
  echo "diagnosis=the component release checker is the bounded evidence gate"
  echo "action=deterministic repair and summary scripts were reviewed before this check"
  echo "check_command=Rscript checks/check_release.R"
  echo "check_exit=$code"
  echo "result=$([ "$code" = 0 ] && echo PASS || echo FAIL)"
  echo "--- checker output ---"
  echo "$output"
} > "$log"
cat "$log"
exit "$code"
