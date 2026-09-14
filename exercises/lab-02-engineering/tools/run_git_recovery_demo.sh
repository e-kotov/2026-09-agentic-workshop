#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LAB_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
WORK="$LAB_ROOT/work"
[ "$(basename "$LAB_ROOT")" = "lab-02-engineering" ] || { echo "FAIL wrong lab basename" >&2; exit 1; }
[ -f "$WORK/derived/person_wave.csv" ] || { echo "FAIL build the repaired table first" >&2; exit 1; }
[ -f "$WORK/tests/test_panel_contract.R" ] || { echo "FAIL participant test is missing" >&2; exit 1; }

demo="$WORK/recovery-demo"
if [ -e "$demo" ]; then
  archive="$LAB_ROOT/.reset-archive/recovery-$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "$LAB_ROOT/.reset-archive"
  mv -- "$demo" "$archive"
  echo "Archived previous recovery demo at $archive"
fi
mkdir -p "$demo"
cp -- "$WORK/derived/person_wave.csv" "$demo/person_wave.csv"
cp -- "$WORK/tests/test_panel_contract.R" "$demo/test_panel_contract.R"
git -C "$demo" init -q
git -C "$demo" add person_wave.csv test_panel_contract.R
git -C "$demo" commit -q -m "repaired baseline"
baseline_commit="$(git -C "$demo" rev-parse HEAD)"
Rscript -e 'p <- commandArgs(TRUE)[1]; x <- read.csv(p, stringsAsFactors=FALSE, check.names=FALSE); i <- which(x$pid == "P000002" & x$wave == 2019); x$person_xs_weight[i] <- x$person_xs_weight[i] + 1; write.csv(x, p, row.names=FALSE)' "$demo/person_wave.csv"
git -C "$demo" add person_wave.csv
git -C "$demo" commit -q -m "deliberately break one weight"
mutation_commit="$(git -C "$demo" rev-parse HEAD)"
set +e
Rscript "$demo/test_panel_contract.R" "$demo/person_wave.csv" "$LAB_ROOT/fixture/release/person_static.csv" "$LAB_ROOT/fixture/release/household_wave.csv" >"$demo/mutation-test.log" 2>&1
mutation_exit=$?
set -e
git -C "$demo" revert --no-edit "$mutation_commit" >/dev/null
set +e
Rscript "$demo/test_panel_contract.R" "$demo/person_wave.csv" "$LAB_ROOT/fixture/release/person_static.csv" "$LAB_ROOT/fixture/release/household_wave.csv" >"$demo/recovery-test.log" 2>&1
recovery_exit=$?
set -e
revert_commit="$(git -C "$demo" rev-parse HEAD)"
mutation_failure="$(head -n 1 "$demo/mutation-test.log")"
recovery_pass="$(tail -n 1 "$demo/recovery-test.log")"
# Keep the exact participant-test output inside the nested repository for
# review. The outer checker independently replays its canonical mutation; these
# logs are not an acceptance claim.
git -C "$demo" add mutation-test.log recovery-test.log
git -C "$demo" commit -q -m "record recovery test output"
evidence_commit="$(git -C "$demo" rev-parse HEAD)"
mutation_log_sha256="$(shasum -a 256 "$demo/mutation-test.log" | awk '{print $1}')"
recovery_log_sha256="$(shasum -a 256 "$demo/recovery-test.log" | awk '{print $1}')"
clean=true
[ -z "$(git -C "$demo" status --porcelain)" ] || clean=false
{
  echo "route=git-nested-recovery"
  echo "scope=standalone-run"
  echo "demo_dir=recovery-demo"
  echo "baseline_commit=$baseline_commit"
  echo "mutation_commit=$mutation_commit"
  echo "revert_commit=$revert_commit"
  echo "evidence_commit=$evidence_commit"
  echo "mutation_log=mutation-test.log"
  echo "recovery_log=recovery-test.log"
  echo "mutation_log_sha256=$mutation_log_sha256"
  echo "recovery_log_sha256=$recovery_log_sha256"
  echo "mutation_exit=$mutation_exit"
  echo "recovery_exit=$recovery_exit"
  echo "clean=$clean"
  echo "mutation_failure=$mutation_failure"
  echo "recovery_pass=$recovery_pass"
} > "$WORK/git-recovery.txt"
[ "$mutation_exit" -ne 0 ] && [ "$recovery_exit" -eq 0 ] && [ "$clean" = true ] || { echo "FAIL Git recovery evidence did not show fail/revert/pass/clean" >&2; exit 1; }
echo "PASS Git recovery: deliberate mutation failed, revert passed, nested worktree is clean"
