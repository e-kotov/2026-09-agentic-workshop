#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LAB_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
WORK="$LAB_ROOT/work"
[ "$(basename "$LAB_ROOT")" = "lab-02-engineering" ] || { echo "FAIL wrong lab basename" >&2; exit 1; }
[ -f "$WORK/derived/person_wave.csv" ] || { echo "FAIL build the repaired table first" >&2; exit 1; }
route="${1:-}"
case "$route" in targets|snakemake) ;; *) echo "Usage: bash tools/run_invalidation_demo.sh targets|snakemake" >&2; exit 1 ;; esac
pipeline="$WORK/pipeline"
if [ -e "$pipeline" ]; then
  archive="$LAB_ROOT/.reset-archive/pipeline-$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "$LAB_ROOT/.reset-archive"
  mv -- "$pipeline" "$archive"
  echo "Archived previous pipeline demo at $archive"
fi
mkdir -p "$pipeline/input" "$pipeline/out"
cp -- "$LAB_ROOT/fixture/release/person_wave.csv" "$pipeline/input/person_wave.csv"
cp -- "$pipeline/input/person_wave.csv" "$pipeline/input/original.csv"
cp -- "$LAB_ROOT/pipeline/Snakefile" "$pipeline/Snakefile"
cp -- "$LAB_ROOT/pipeline/snakemake_person_wave.py" "$pipeline/snakemake_person_wave.py"
cp -- "$LAB_ROOT/pipeline/snakemake_wave_qa.py" "$pipeline/snakemake_wave_qa.py"
cp -- "$LAB_ROOT/pipeline/run_snakemake_compat.py" "$pipeline/run_snakemake_compat.py"
if [ "$route" = targets ]; then
  command -v Rscript >/dev/null || { echo "FAIL Rscript is required for targets route" >&2; exit 1; }
  cp -- "$LAB_ROOT/pipeline/targets.R" "$pipeline/_targets.R"
  (cd "$pipeline" && Rscript -e 'targets::tar_make(script="_targets.R")' > first.log 2>&1)
  engine="targets"
else
  if command -v snakemake >/dev/null; then
    (cd "$pipeline" && snakemake --cores 1 --snakefile Snakefile > first.log 2>&1)
    engine="snakemake"
  else
    (cd "$pipeline" && python "$LAB_ROOT/pipeline/run_snakemake_compat.py" input/person_wave.csv out/person_wave.csv out/wave-qa.csv > first.log 2>&1)
    engine="snakemake-compatible-timestamp-runner (snakemake unavailable)"
  fi
fi
hash_person_1="$(shasum -a 256 "$pipeline/out/person_wave.csv" | awk '{print $1}')"
hash_qa_1="$(shasum -a 256 "$pipeline/out/wave-qa.csv" | awk '{print $1}')"
if [ "$route" = targets ]; then
  (cd "$pipeline" && Rscript -e 'targets::tar_make(script="_targets.R")' > unchanged.log 2>&1)
elif command -v snakemake >/dev/null; then
  (cd "$pipeline" && snakemake --cores 1 --snakefile Snakefile > unchanged.log 2>&1)
else
  (cd "$pipeline" && python "$LAB_ROOT/pipeline/run_snakemake_compat.py" input/person_wave.csv out/person_wave.csv out/wave-qa.csv > unchanged.log 2>&1)
fi
hash_person_2="$(shasum -a 256 "$pipeline/out/person_wave.csv" | awk '{print $1}')"
hash_qa_2="$(shasum -a 256 "$pipeline/out/wave-qa.csv" | awk '{print $1}')"
unchanged_rebuilt=0
[ "$hash_person_1" = "$hash_person_2" ] && [ "$hash_qa_1" = "$hash_qa_2" ] || unchanged_rebuilt=2
Rscript -e 'p <- commandArgs(TRUE)[1]; x <- read.csv(p, stringsAsFactors=FALSE, check.names=FALSE); i <- which(x$pid == "P000002" & x$wave == 2019); x$person_xs_weight[i] <- x$person_xs_weight[i] + 1; write.csv(x, p, row.names=FALSE)' "$pipeline/input/person_wave.csv"
if [ "$route" = targets ]; then
  (cd "$pipeline" && Rscript -e 'targets::tar_make(script="_targets.R")' > changed.log 2>&1)
elif command -v snakemake >/dev/null; then
  (cd "$pipeline" && snakemake --cores 1 --snakefile Snakefile > changed.log 2>&1)
else
  (cd "$pipeline" && python "$LAB_ROOT/pipeline/run_snakemake_compat.py" input/person_wave.csv out/person_wave.csv out/wave-qa.csv > changed.log 2>&1)
fi
hash_person_3="$(shasum -a 256 "$pipeline/out/person_wave.csv" | awk '{print $1}')"
hash_qa_3="$(shasum -a 256 "$pipeline/out/wave-qa.csv" | awk '{print $1}')"
changed_rebuilt=""
[ "$hash_person_2" != "$hash_person_3" ] && changed_rebuilt="person_wave" || true
[ "$hash_qa_2" != "$hash_qa_3" ] && changed_rebuilt="${changed_rebuilt:+$changed_rebuilt,}wave_qa" || true
cp -- "$pipeline/input/original.csv" "$pipeline/input/person_wave.csv"
restored=false
[ "$(shasum -a 256 "$pipeline/input/person_wave.csv" | awk '{print $1}')" = "$(shasum -a 256 "$pipeline/input/original.csv" | awk '{print $1}')" ] && restored=true
first_log_sha256="$(shasum -a 256 "$pipeline/first.log" | awk '{print $1}')"
unchanged_log_sha256="$(shasum -a 256 "$pipeline/unchanged.log" | awk '{print $1}')"
changed_log_sha256="$(shasum -a 256 "$pipeline/changed.log" | awk '{print $1}')"
targets_sha256=""
snakefile_sha256=""
person_rule_sha256=""
qa_rule_sha256=""
compat_runner_sha256=""
[ -f "$pipeline/_targets.R" ] && targets_sha256="$(shasum -a 256 "$pipeline/_targets.R" | awk '{print $1}')"
[ -f "$pipeline/Snakefile" ] && snakefile_sha256="$(shasum -a 256 "$pipeline/Snakefile" | awk '{print $1}')"
[ -f "$pipeline/snakemake_person_wave.py" ] && person_rule_sha256="$(shasum -a 256 "$pipeline/snakemake_person_wave.py" | awk '{print $1}')"
[ -f "$pipeline/snakemake_wave_qa.py" ] && qa_rule_sha256="$(shasum -a 256 "$pipeline/snakemake_wave_qa.py" | awk '{print $1}')"
[ -f "$pipeline/run_snakemake_compat.py" ] && compat_runner_sha256="$(shasum -a 256 "$pipeline/run_snakemake_compat.py" | awk '{print $1}')"
{
  echo "route=$route"
  echo "engine=$engine"
  echo "scope=standalone-run"
  echo "pipeline_dir=pipeline"
  echo "first_log=first.log"
  echo "unchanged_log=unchanged.log"
  echo "changed_log=changed.log"
  echo "first_log_sha256=$first_log_sha256"
  echo "unchanged_log_sha256=$unchanged_log_sha256"
  echo "changed_log_sha256=$changed_log_sha256"
  echo "targets_sha256=$targets_sha256"
  echo "snakefile_sha256=$snakefile_sha256"
  echo "person_rule_sha256=$person_rule_sha256"
  echo "qa_rule_sha256=$qa_rule_sha256"
  echo "compat_runner_sha256=$compat_runner_sha256"
  echo "clean_build=person_wave,wave_qa"
  echo "unchanged_rebuilt=$unchanged_rebuilt"
  echo "changed_rebuilt=$changed_rebuilt"
  echo "restored=$restored"
  echo "note=targets uses content hashing; Snakemake uses timestamps and declared dependency edges"
} > "$WORK/invalidation-evidence.txt"
[ "$unchanged_rebuilt" = 0 ] && [ "$changed_rebuilt" = "person_wave,wave_qa" ] && [ "$restored" = true ] || { echo "FAIL invalidation evidence did not show unchanged skip and changed downstream rebuild" >&2; exit 1; }
echo "PASS $route invalidation: unchanged build skipped; changed upstream rebuilt person_wave and wave_qa"
