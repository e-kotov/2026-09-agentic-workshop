#!/usr/bin/env bash
set -euo pipefail
S="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"; L="$(cd -- "$S/.." && pwd -P)"; W="$L/work"
[ "$(basename "$L")" = lab-04-skills-memory ] || { echo "FAIL wrong lab basename" >&2; exit 1; }
cd "$L"; Rscript checks/check_lab4.R >/dev/null || { echo "FAIL export requires the exact Lab 4 checker to pass" >&2; exit 1; }
payload=(release/household_wave.csv release/person_static.csv release/person_wave.csv release/questionnaire.csv release/release_manifest.csv release/response.csv release/schema.csv code/repair_release.R code/summarize_income.R outputs/income-summary.csv LOOP.md GOALS.md WORKLOG.md logs/attempt-1.txt DECISIONS.md HANDOFF.md placement.md)
if [ -f "$W/logs/attempt-2.txt" ]; then payload+=(logs/attempt-2.txt); fi
echo "Allowlist (copied, never moved):"; for p in "${payload[@]}"; do echo "  work/$p"; done
dest="$L/../workshop-project/lab-04"; mkdir -p "$dest"
release_dest="$dest/release"
if [ -e "$release_dest" ]; then
  [ -d "$release_dest" ] || { echo "FAIL destination release path is not a directory" >&2; exit 1; }
  extra="$(find "$release_dest" -mindepth 1 -maxdepth 1 ! -name .gitkeep -print -quit)"
  [ -z "$extra" ] || { echo "FAIL destination release contains a real payload; refusing overwrite" >&2; exit 1; }
  marker="$release_dest/.gitkeep"
  if [ -e "$marker" ] || [ -L "$marker" ]; then
    [ -f "$marker" ] && [ ! -L "$marker" ] && [ ! -s "$marker" ] || { echo "FAIL release placeholder is not the expected empty regular file" >&2; exit 1; }
  fi
fi
for p in "${payload[@]}"; do [ -e "$W/$p" ] || { echo "FAIL missing work/$p" >&2; exit 1; }; [ ! -e "$dest/$p" ] || { echo "FAIL destination already contains $dest/$p" >&2; exit 1; }; done
printf '%s' 'Type EXPORT lab-04 to copy this reviewed payload: '; read -r answer; [ "$answer" = "EXPORT lab-04" ] || { echo "FAIL export cancelled" >&2; exit 1; }
if [ -f "$release_dest/.gitkeep" ]; then rm -- "$release_dest/.gitkeep"; echo "Removed only the empty release/.gitkeep starter marker"; fi
for p in "${payload[@]}"; do mkdir -p "$dest/$(dirname "$p")"; cp -- "$W/$p" "$dest/$p"; done
echo "PASS copied reviewed Lab 4 payload to $dest"
