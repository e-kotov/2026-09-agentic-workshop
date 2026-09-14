#!/usr/bin/env bash
set -euo pipefail
S="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"; L="$(cd -- "$S/.." && pwd -P)"; W="$L/work"; A="$L/.reset-archive"
[ "$(basename "$L")" = lab-04-skills-memory ] || { echo "FAIL wrong lab basename" >&2; exit 1; }
if [ "${1:-}" != --archive ]; then echo "Usage: bash tools/reset_lab.sh --archive"; echo "Targets: this lab's work/ only; archive: .reset-archive/<UTC stamp>/"; exit 0; fi
[ "$#" = 1 ] || { echo "FAIL unexpected arguments" >&2; exit 1; }
if [ -e "$W" ]; then d="$A/$(date -u +%Y%m%dT%H%M%SZ)"; mkdir -p "$A"; while [ -e "$d" ]; do d="$A/$(date -u +%Y%m%dT%H%M%SZ)-$RANDOM"; done; mv -- "$W" "$d"; echo "PASS archived lab work at $d"; fi
mkdir -p "$W"; touch "$W/.gitkeep"; echo "PASS recreated empty lab work at $W"
