# Source-free synthetic linked panel

This directory contains a small, invented household/person panel for teaching
data engineering and release QA. It was generated from explicit probability
rules and **no respondent records, SOEP data, restricted documentation, fitted
empirical distributions, names, addresses, or free text**. Its table roles are
recognizable survey-infrastructure patterns, but its values and mechanisms are
not SOEP estimates or a statistically calibrated replica of SOEP. This source
code establishes only that no source records are generator inputs; it does not
establish provider approval, anonymization or disclosure certification, or
proof that the conceptual choices have no historical influence from survey
documentation.

The canonical release has four annual waves (2019--2022), stable opaque person
and household IDs, refreshment entry, monotone attrition, household splits,
cross-sectional weights, a baseline-cohort longitudinal weight, questionnaire
metadata, item responses, and mechanically linked income imputations. The
weights are normalized, invented inverse-selection teaching constructs scaled
to invented totals. They contain no nonresponse or attrition adjustment and are
not valid SOEP weights. Imputations are deterministic
within-wave teaching substitutions, not a production imputation method.

## Files and regeneration

- `generate.R` builds an output root (default `fixtures/`) containing the clean
  release and six named one-change releases from seed `20260912`. Pass
  `--output-dir=/tmp/panel-output` for isolated generation.
- `defect_profiles.csv` declares each injected physical change and the checks
  expected to fail.
- `validate.R RELEASE_DIR` evaluates the checks in `invariants.csv` and exits
  nonzero on any failure.
- `validate_all.R` confirms that the clean release passes and every defect
  release has the exact failure set declared in `defect_profiles.csv`.
- `schema.csv` is the data dictionary. `questionnaire.csv` is wave-specific
  item metadata. Each release's `release_manifest.csv` records row counts,
  SHA-256 hashes, generator/package/lock/input fingerprints, provenance, expected status,
  and structured invented target totals. The validator's report is the actual
  validation evidence.

The checked-in fixture was built with the complete direct/transitive closure in
`renv.lock` and summarized in `dependencies.csv`. `renv-bootstrap.csv` and the
official CRAN source archive `renv_1.2.4.tar.gz` provide the verified SHA-256
bootstrap archive; the checker rejects compiled archive members.
For a manual restore, use a disposable library and the exact `renv` version declared in the lock; the
generator does not activate a project `.Rprofile` or library for ordinary
participant sessions:

```sh
SYNTH_PANEL_R_LIB="$(mktemp -d)"
export SYNTH_PANEL_R_LIB
Rscript --vanilla -e \
  'renv::restore(lockfile="data/synthetic-panel/renv.lock", library=Sys.getenv("SYNTH_PANEL_R_LIB"), clean=TRUE, prompt=FALSE)'
```

The G2 checker is the authoritative isolated restore: it explicitly copies (or
installs) the exact locked `renv` version into the empty disposable library,
starts a fresh child R process, disables non-base site-library resolution, and
performs one `renv::restore(..., rebuild=TRUE, transactional=FALSE)` for all 21
lock records. It asserts a local `DESCRIPTION` and exact version for every
record, including `renv`; there is no post-restore install fallback. It does
not modify the repository or activate `.Rprofile`.

Then make that same library visible when running the scripts. Exact generated
bytes are supported for the recorded R/package/platform versions; later
compatible package versions should preserve the documented schema and
invariants but may draw different random values.

```sh
R_LIBS_USER="$SYNTH_PANEL_R_LIB" Rscript data/synthetic-panel/generate.R
R_LIBS_USER="$SYNTH_PANEL_R_LIB" Rscript data/synthetic-panel/validate_all.R
```

The complete local gate sequence is:

```sh
Rscript --vanilla data/synthetic-panel/check_restore.R
Rscript --vanilla data/synthetic-panel/check_reproducibility.R
Rscript --vanilla data/synthetic-panel/validate_all.R
R_LIBS_USER=data/synthetic-panel/_r-lib Rscript --vanilla data/synthetic-panel/check_adversarial.R
```

The `r_platform` manifest field records the historical canonical build target
(`aarch64-apple-darwin23`); validators compare it to that declared target, not
to the host running validation. Therefore tracked fixtures validate on Linux,
while byte-identical regeneration remains a pinned-target operation.

The reproducibility check stages the complete generator source/configuration
into two separate temporary roots, generates only there, and compares all 51
canonical artifacts (root metadata plus release files) to each other and the
tracked fixtures.

The generator uses [`fabricatr`](https://declaredesign.org/r/fabricatr/reference/fabricate.html)
only for the transparent nested household-person scaffold. [`simstudy`](https://kgoldfeld.github.io/simstudy/reference/index.html)
supplies AR(1)-correlated person shocks and a documented item-nonresponse draw.
Entry, attrition, moves, membership, weights, income imputation, questionnaire
eligibility, IDs, and checks remain explicit local code so their teaching
semantics can be inspected.

## Tables

- `person_static.csv`: stable identity-free person attributes and observation
  window.
- `household_wave.csv`: participating household by wave, region, size, move
  event, cohort, and cross-sectional weight.
- `person_wave.csv`: linked annual person state, employment, income, missingness
  and imputation flags, and person/longitudinal weights.
- `questionnaire.csv`: item declarations, codes/ranges, eligibility rules, and
  metadata version.
- `response.csv`: long item responses with answer/skip/missing status and mode.
- `schema.csv`: field-level data dictionary.
- `release_manifest.csv`: release provenance, counts, hashes, and expected
  status (actual validation evidence is emitted by `validate.R`).

For byte-stable regeneration, `generated_utc` is a fixed release epoch rather
than the wall-clock time of a rerun.

Defects are synthetic QA fixtures, not examples of real survey-production
errors. A physical defect may make more than one relational check fail (for
example, an orphan membership also changes the linked size count).

## Limitations and future design note

The sample is tiny; categories, transition probabilities, calibration totals,
and response processes are invented and deliberately simpler than production
panel survey practice. There are no replicate weights, sampling strata/PSUs,
formal disclosure-risk certification, calibrated population margins, complex
household relationships, proxy interviews, retrospective spells, or multiple
imputation uncertainty.

TODO (optional future exercise): participants could ask an agent to propose and
critique a new source-free mechanism using `fabricatr` and `simstudy`, then
encode assumptions as invariants and compare the result with this fixture.
That exercise should assess design reasoning and verification, not closeness to
SOEP, and must not introduce real survey rows or fitted private distributions.
