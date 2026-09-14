#!/usr/bin/env bash
set -euo pipefail

# Regression test for the two evidence forgeries reviewed during Lab 2 QA.
# Everything is made in a disposable copy; the participant work tree is not
# touched. This is deliberately not part of the beginner route.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LAB_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
tmp="$(mktemp -d)"
lab="$tmp/lab-02-engineering"
cp -R "$LAB_ROOT" "$lab"
mkdir -p "$lab/work"

(cd "$lab" && Rscript --vanilla tools/build_repair.R && bash tools/run_git_recovery_demo.sh && bash tools/run_invalidation_demo.sh snakemake)

# A filename/commit-aware participant test can print the expected messages
# without reading its CSV. The participant test is explicitly non-authoritative:
# this exact forgery must not alter the immutable checker result.
cp "$lab/work/tests/test_panel_contract.R" "$tmp/valid-participant-test.R"
{
  echo 'args <- commandArgs(trailingOnly = TRUE)'
  echo 'if (grepl("fixture|mutation", args[[1]])) quit(status = 1L)'
  echo 'cat("PASS participant panel contract: unique keys, target weights, and one-to-one joins\\n")'
} > "$lab/work/tests/test_panel_contract.R"
set +e
test_failure="$(cd "$lab" && Rscript --vanilla checks/check_lab2.R 2>&1)"
test_status=$?
set -e
[ "$test_status" -eq 0 ] || { echo "FAIL non-authoritative participant test changed canonical acceptance" >&2; exit 1; }
cp "$tmp/valid-participant-test.R" "$lab/work/tests/test_panel_contract.R"

# Forge a plausible nested history whose mutation changes only the test file,
# then provide internally consistent IDs, hashes, and log files. The
# immutable lab-owned checker replay is independent of this forged history.
cp "$lab/work/git-recovery.txt" "$tmp/valid-git-recovery.txt"
mv "$lab/work/recovery-demo" "$tmp/valid-recovery-demo"
demo="$lab/work/recovery-demo"
mkdir -p "$demo"
cp "$lab/work/derived/person_wave.csv" "$demo/person_wave.csv"
cp "$lab/work/tests/test_panel_contract.R" "$demo/test_panel_contract.R"
git -C "$demo" init -q
git -C "$demo" config user.email "lab2-regression@example.invalid"
git -C "$demo" config user.name "Lab 2 regression"
git -C "$demo" add person_wave.csv test_panel_contract.R
git -C "$demo" commit -q -m "repaired baseline"
baseline="$(git -C "$demo" rev-parse HEAD)"
echo '# irrelevant forged change' >> "$demo/test_panel_contract.R"
git -C "$demo" add test_panel_contract.R
git -C "$demo" commit -q -m "plausible mutation"
mutation="$(git -C "$demo" rev-parse HEAD)"
git -C "$demo" revert --no-edit "$mutation" >/dev/null
revert="$(git -C "$demo" rev-parse HEAD)"
cp "$demo/test_panel_contract.R" "$demo/mutation-test.log"
cp "$demo/test_panel_contract.R" "$demo/recovery-test.log"
git -C "$demo" add mutation-test.log recovery-test.log
git -C "$demo" commit -q -m "forged evidence"
evidence="$(git -C "$demo" rev-parse HEAD)"
mutation_sha="$(shasum -a 256 "$demo/mutation-test.log" | awk '{print $1}')"
recovery_sha="$(shasum -a 256 "$demo/recovery-test.log" | awk '{print $1}')"
{
  echo "scope=standalone-run"
  echo "demo_dir=recovery-demo"
  echo "baseline_commit=$baseline"
  echo "mutation_commit=$mutation"
  echo "revert_commit=$revert"
  echo "evidence_commit=$evidence"
  echo "mutation_log=mutation-test.log"
  echo "recovery_log=recovery-test.log"
  echo "mutation_log_sha256=$mutation_sha"
  echo "recovery_log_sha256=$recovery_sha"
  echo "mutation_exit=1"
  echo "recovery_exit=0"
  echo "clean=true"
} > "$lab/work/git-recovery.txt"
set +e
git_failure="$(cd "$lab" && Rscript --vanilla checks/check_lab2.R 2>&1)"
git_status=$?
set -e
[ "$git_status" -eq 0 ] || { echo "FAIL forged Git artefact changed canonical acceptance" >&2; exit 1; }

# Restore the genuine Git evidence, then replace the workflow with validly
# shaped but fabricated logs and no outputs. The immutable checker-owned
# workflow replay remains the sole acceptance oracle.
cp "$tmp/valid-git-recovery.txt" "$lab/work/git-recovery.txt"
mv "$lab/work/recovery-demo" "$tmp/forged-recovery-demo"
mv "$tmp/valid-recovery-demo" "$lab/work/recovery-demo"
mv "$lab/work/pipeline" "$tmp/valid-pipeline"
pipe="$lab/work/pipeline"
mkdir -p "$pipe/input"
cp "$lab/fixture/release/person_wave.csv" "$pipe/input/person_wave.csv"
cp "$pipe/input/person_wave.csv" "$pipe/input/original.csv"
mkdir -p "$pipe/out"
cp "$tmp/valid-pipeline/out/person_wave.csv" "$pipe/out/person_wave.csv"
cp "$tmp/valid-pipeline/out/wave-qa.csv" "$pipe/out/wave-qa.csv"
printf 'rebuild person_wave\nrebuild wave_qa\n' > "$pipe/first.log"
printf 'skip: dependencies unchanged\n' > "$pipe/unchanged.log"
printf 'rebuild person_wave\nrebuild wave_qa\n' > "$pipe/changed.log"
first_sha="$(shasum -a 256 "$pipe/first.log" | awk '{print $1}')"
unchanged_sha="$(shasum -a 256 "$pipe/unchanged.log" | awk '{print $1}')"
changed_sha="$(shasum -a 256 "$pipe/changed.log" | awk '{print $1}')"
{
  echo "route=snakemake"
  echo "scope=standalone-run"
  echo "pipeline_dir=pipeline"
  echo "first_log=first.log"
  echo "unchanged_log=unchanged.log"
  echo "changed_log=changed.log"
  echo "first_log_sha256=$first_sha"
  echo "unchanged_log_sha256=$unchanged_sha"
  echo "changed_log_sha256=$changed_sha"
  echo "unchanged_rebuilt=0"
  echo "changed_rebuilt=person_wave,wave_qa"
  echo "restored=true"
} > "$lab/work/invalidation-evidence.txt"
set +e
workflow_failure="$(cd "$lab" && Rscript --vanilla checks/check_lab2.R 2>&1)"
workflow_status=$?
set -e
[ "$workflow_status" -eq 0 ] || { echo "FAIL forged workflow artefact changed canonical acceptance" >&2; exit 1; }

# Repeat the exact reviewed target forgery: canonical _targets.R, copied
# outputs, and fabricated logs, with no target state or submitted execution.
# The immutable target oracle makes the copied artefacts irrelevant as well.
cp "$lab/pipeline/targets.R" "$pipe/_targets.R"
sed 's/^route=snakemake$/route=targets/' "$lab/work/invalidation-evidence.txt" > "$lab/work/invalidation-evidence.txt.target"
mv "$lab/work/invalidation-evidence.txt.target" "$lab/work/invalidation-evidence.txt"
set +e
target_failure="$(cd "$lab" && Rscript --vanilla checks/check_lab2.R 2>&1)"
target_status=$?
set -e
[ "$target_status" -eq 0 ] || { echo "FAIL copied-output target artefact changed canonical acceptance" >&2; exit 1; }

echo "PASS adversarial evidence regression: dormant test, Git, and fake workflow artefacts are non-authoritative"
