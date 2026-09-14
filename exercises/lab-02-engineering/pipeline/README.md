# Tiny workflow demonstration

The participant helper is the bounded, reproducible route:

```bash
bash tools/run_invalidation_demo.sh targets
```

It uses a disposable copy under `work/pipeline/`, performs a clean build, an unchanged build, then changes the declared upstream copy and performs a third build. The evidence must show no rebuild for the unchanged run and rebuilds of `person_wave` and `wave_qa` after the content change. It restores the disposable input. `targets` detects content changes through hashing.

The checker runs the immutable lab-owned source in another empty temporary tree and performs the same three calls itself, comparing parsed outputs and hashes. Participant source copies and evidence logs are review artefacts, not a substitute for that executable oracle.

The alternative is:

```bash
bash tools/run_invalidation_demo.sh snakemake
```

`pipeline/Snakefile` declares the same `input/person_wave.csv` → `out/person_wave.csv` → `out/wave-qa.csv` dependency edges. Snakemake normally uses file timestamps and declared edges; in a minimal image without Snakemake, the helper uses its small timestamp-compatible runner and records that fact. Do not conflate this with `targets` content hashing. Participants choose one route, not both.
