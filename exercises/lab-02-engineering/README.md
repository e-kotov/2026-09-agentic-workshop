```bash
cd "$(git rev-parse --show-toplevel)/exercises/lab-02-engineering"
```

# Lab 2 — Engineering for research

This standalone exercise uses only invented, source-free panel data. The release in `fixture/release/` is immutable: it contains 514 person-wave rows and one byte-identical duplicate, `P000001::2019`. Never put credentials, restricted rows, unpublished results, or personal/participant data into this exercise or an agent.

## Start here

Open a VS Code terminal and paste the first command above. Run `pwd`. It must end in `/exercises/lab-02-engineering`. If it does not, stop and ask for help.

Choose a mode before editing:

- **Standalone — recommended:** work only in this lab. This route is complete by itself.
- **Cumulative — optional:** complete the standalone route first; after the checker passes and you review it, export the allowlisted payload to `exercises/workshop-project/`.

If you do not choose, stay standalone. `fixture/`, `checks/`, and `tools/` are read-only; edit only `work/`. Start a disposable work area:

```bash
bash tools/start_lab.sh
Rscript checks/check_lab2.R
```

The first check is expected to fail. It must report these starting failures:

```text
PASS precondition: fixture fails unique_person_wave, weight_targets, income_consistency
FAIL incomplete: work/derived/person_wave.csv is missing
```

The exact success check is:

```bash
Rscript checks/check_lab2.R
```

## What you learn

Shift trust from plausible code to executable evidence: prove duplicate identity before deleting, assert relational join cardinality, report wave counts and weight totals, use a mutation-sensitive test, recover a deliberate break with Git, and show dependency-aware workflow invalidation. These checks support structural correctness; they do not establish substantive panel meaning. The weights are simplified teaching constructs, not SOEP estimates or production weights.

## Beginner — recommended

Do not complete every route. Finish Beginner — recommended, then choose at most one optional route if time remains.

1. **Start and precheck (5 min).** Run the commands above. Ask the agent to orient itself and diagnose without editing. The named fixture defect is intentional.
2. **Prove before deleting (8 min).** Find duplicated `(pid, wave)` keys and compare every column in each duplicate group. Stop if any duplicate group disagrees; never guess which row is authoritative.
3. **Repair and safe join (12 min).** Run or ask the agent to review `Rscript tools/build_repair.R`. It creates a stable-first 513-row `work/derived/person_wave.csv`, then joins person-static by `pid` and household-wave by `(hid, wave)`. The build asserts right-side key uniqueness and unchanged row count before writing the exact selected columns.
4. **Wave QA and focused test (10 min).** Inspect `work/qa/duplicate-proof.csv`, `join-qa.csv`, and `wave-qa.csv`. Run the participant test and confirm it goes red on the immutable defective input and green on the repaired output:

   ```bash
   Rscript work/tests/test_panel_contract.R fixture/release/person_wave.csv
   Rscript work/tests/test_panel_contract.R work/derived/person_wave.csv
   ```

   This participant test is a learning artefact: inspect that it reads the supplied files and run it on both inputs. The immutable checker owns acceptance and independently checks the defective/repaired data contract, so test messages and call order are not proof.

5. **Verify the data stage (5 min).** Run `Rscript checks/check_data.R` and review the artefacts. A duplicate proof says nothing about unrelated panel semantics.
6. **Git failure/recovery (8 min).** Run `bash tools/run_git_recovery_demo.sh`. Read the generated failed mutation and pass evidence in `work/git-recovery.txt`; inspect the nested commits and confirm its final worktree is clean. The final checker independently replays the canonical repaired table and deliberate weight mutation; nested Git objects and text logs are review artefacts, not correctness proof. The outer repository is untouched.
7. **Workflow invalidation (8 min).** Choose exactly one route (recommended `targets`, or Snakemake), not both:

   ```bash
   bash tools/run_invalidation_demo.sh targets
   # or
   bash tools/run_invalidation_demo.sh snakemake
   ```

   Inspect `work/invalidation-evidence.txt`. `targets` uses content hashing; Snakemake uses file timestamps/dependency edges. The final checker runs the immutable lab-owned workflow harness in a fresh tree with outputs deleted, repeats it unchanged, then changes the canonical upstream input and repeats it; participant logs and copied outputs are review artefacts only. Do not treat an unchanged build as proof that every possible change is detected.
8. **Close (4 min).** Run the main checker, review all artefacts, and reflect: which assertion catches duplicate reintroduction, and what does the workflow know that an undocumented script sequence does not?

## Optional medium route

Do not complete every route. Finish Beginner — recommended, then choose at most one optional route if time remains.

Use the non-selected workflow route from a fresh archived reset and compare its invalidation evidence. This replaces, rather than follows, the other optional workflow exercise.

## Optional advanced route

Do not complete every route. Finish Beginner — recommended, then choose at most one optional route if time remains.

In an archived disposable copy, alter one duplicate so its rows disagree. Verify that repair stops instead of silently choosing a row. Audit which assertions catch row multiplication and which create confidence theatre. Never alter `fixture/release/`.

## Reproducible build and artefacts

The shipped build command is `Rscript tools/build_repair.R`; it reads only `fixture/release/` and writes only `work/`. Required outputs are `derived/person_wave.csv`, `derived/person_household_wave.csv`, `qa/duplicate-proof.csv`, `qa/join-qa.csv`, `qa/wave-qa.csv`, `tests/test_panel_contract.R`, `git-recovery.txt`, and `invalidation-evidence.txt`. The last two are generated by their named helpers for review; immutable checker-owned replays, not participant claims, decide acceptance.

## Stop, reset, or continue

Stop the mandatory task when `Rscript checks/check_lab2.R` exits 0 and prints `PASS lab 2: identical duplicate proved before repair; joins, wave QA, tests, Git recovery, and workflow invalidation verified`. Review the artefacts and confirm the nested recovery worktree is clean. Do not start an optional route merely because the agent suggests one.

- Safe reset: `bash tools/reset_lab.sh --archive` archives this lab's `work/` under `.reset-archive/` and recreates it. It does not touch another lab or the cumulative project.
- Optional cumulative export, only after review: `bash tools/handoff.sh` (type the exact confirmation it requests).
- Optional checker path: `Rscript checks/check_lab2.R --cumulative /absolute/path/to/exercises/workshop-project/lab-02`.
- Next Lab 3: `cd "$(git rev-parse --show-toplevel)/exercises/lab-03-security"`.

## Read next

- [Ten Simple Rules for Reproducible Computational Research](https://doi.org/10.1371/journal.pcbi.1003285) — Connects focused checks, provenance, and inspectable intermediates to durable research practice.
- [Pro Git](https://git-scm.com/book/en/v2) — A reference for the working tree, staging area, commits, and history.
- [Harness engineering](https://openai.com/index/harness-engineering/) — A case study of written intent and mechanical feedback loops; compare its engineering setting with research evidence requirements.
