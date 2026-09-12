# Tiny workflow demonstration (optional)

From the Lab 2 directory, run `Rscript -e 'targets::tar_make(script="pipeline/_targets.R")'` and inspect `pipeline/out/manifest.csv`. The workflow reads the pipeline-local copy at `pipeline/input/records.csv`, not the immutable known-bad fixture. Its dependency graph is `records_file` (the `format = "file"` input) → `records` → `clean_records` → `manifest`. Change one value in that disposable copy, rerun, and observe those downstream targets rebuild; restore it with Git afterwards. Do not use real data. This is a bounded demonstration, not a required long analysis.

The Python alternative has the same dependency edges. Run `snakemake --cores 1 --snakefile pipeline/Snakefile` from the Lab 2 directory and inspect the same output. Snakemake, Make, or another workflow system is fine if the participant can show the invalidation evidence.
