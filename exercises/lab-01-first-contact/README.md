```bash
cd "$(git rev-parse --show-toplevel)/exercises/lab-01-first-contact"
```

# Lab 1: First contact

Allow about 70 minutes. This lab uses OpenCode, a disposable Codespace, and a complete source-free synthetic panel release. The staff-like task is to repair one questionnaire-metadata defect without silently changing anything else.

## Start here

Open a VS Code terminal and paste the first command above. Now run `pwd`. It must end in `/exercises/lab-01-first-contact`. If it does not, stop and ask for help.

Initialize the writable folder and run the exact checker once:

```bash
bash tools/start_lab.sh
Rscript checks/check_lab1.R
```

The first check is expected to fail: it should report `PASS precondition: fixture has one duplicate (wave, item_id) key: 2019::EMP`, followed by missing work artefacts. The immutable starting release is `fixture/release/`; edit only `work/`. The defect is an appended, byte-identical second `2019::EMP` declaration in `questionnaire.csv`. These are invented teaching data, not SOEP data or valid production metadata.

Choose one mode before the agent edits anything:

- **Standalone — recommended:** work only in this lab. It is complete by itself.
- **Cumulative — optional:** complete and review the standalone task first; only then export its allowlisted payload to `exercises/workshop-project/lab-01/`.

If you do not choose, stay standalone. Never use credentials, restricted rows, unpublished results, or personal or participant data. Do not edit `fixture/`, `checks/`, or `tools/`.

## What you learn

**Agent-learning goal:** observe orientation, instruction discovery, permissions, selective file inspection, assumptions, tool use, and the difference between an agent claim and a checked edit.

**Plausible staff task:** a questionnaire-metadata release contains a duplicated wave/item declaration. Produce a corrected questionnaire table, record provenance, and distinguish session observations from inferences before metadata goes to downstream processing.

**Expected artefacts:** `work/corrected-questionnaire.csv`, `work/provenance.md`, and `work/session-observations.md`. The provenance must name `fixture/release/questionnaire.csv`, key `2019::EMP`, the exact transformation “removed one exact duplicate; retained one declaration”, and the checker command. The observations file must have non-empty headings `Observed`, `Inferred`, `Permission`, and `Verification`.

## Beginner — recommended

Do not complete every route. Finish Beginner — recommended, then choose at most one optional route if time remains.

Follow this one mandatory linear spine:

1. **Orient without action (5 minutes).** Launch the agent with ordinary approval prompts. Ask it to report the current directory, README, immutable fixture, writable files, project instructions, and checker without editing or running task commands.
2. **Observe context and permissions (8 minutes).** Ask what instructions and tools it can actually observe. Approve two benign, scoped reads individually; do not enable auto mode yet. Record one observation and one inference.
3. **Run the failing check (5 minutes).** Read the precondition/failure output. Ask the agent to inspect only `questionnaire.csv`, `schema.csv`, and relevant release-contract information before proposing a repair.
4. **Improve the task (10 minutes).** Compare “fix the metadata” with a bounded prompt naming goal, allowed paths, artefacts, check, and the ambiguity stop. The agent must prove duplicate identity before removing a row.
5. **Repair and document (15 minutes).** Create the corrected CSV and provenance. Remove exactly one duplicate only after proving all columns match. Preserve questionnaire versions, numeric ranges, and every other field; keep the release fixture unchanged.
6. **Verify and review (10 minutes).** Complete the session observations, run `Rscript checks/check_lab1.R`, inspect the three files, and review the result. A passing check supports structural correctness, not substantive validity of invented questionnaire content.
7. **Dry-run the R skill (10 minutes).** Use the existing `.agents/skills/r-binary-packages/SKILL.md` with: “The package `workshopMissing` is reported missing. Dry-diagnose the configured compatible binary route; inspect `R.version$platform` and `getOption('repos')`, run `Rscript task/r-package-diagnostic.R`, and do not install, use `sudo`, change repositories, or access the network.” Record what the skill added beyond the prompt.
8. **Close (7 minutes).** Stop after the pass and human review. Auto mode is optional only for the remaining bounded disposable task; it is not a security control.

At about 20 minutes, confirm you can name the fixture, writable path, and intended duplicate. At about 45 minutes, confirm the repaired CSV and provenance are ready for the checker.

## Optional medium route

After a standalone pass, reset to an archive and repeat once with a vague prompt. Compare reads, assumptions, corrections, and checker outcome with the bounded prompt. Do not self-configure unrelated settings in the mandatory route.

## Optional advanced route

Audit context growth, tool calls, skill activation, and avoidable reads. Propose one smaller task decomposition. Do not read the entire release merely to locate a duplicate key.

## Stop, reset, or continue

Stop the mandatory task when `Rscript checks/check_lab1.R` exits 0 and prints `PASS lab 1: duplicate questionnaire item repaired; provenance and session observations present`. Review the three artefacts yourself. Do not start an optional route merely because the agent suggests one.

- Safe reset: `bash tools/reset_lab.sh --archive` archives this lab's `work/` and recreates it. It does not touch another lab or the cumulative project; the printed archive path is recoverable.
- Optional cumulative export, only after review: `bash tools/handoff.sh`, then type exactly `EXPORT lab-01`. It copies only the three reviewed artefacts and refuses to overwrite existing payloads.
- Optional cumulative-path check after export: `Rscript checks/check_lab1.R --cumulative ../workshop-project/lab-01`.
- Next lab: `cd "$(git rev-parse --show-toplevel)/exercises/lab-02-engineering"`.

Reflection: Which action was verified by a tool? Which claim remained an inference? What would you change in the task brief?

## Read next

- [ReAct](https://doi.org/10.48550/arXiv.2210.03629) — The research pattern behind the reason–action–observation loop you just watched in the terminal.
- [Language Models Don't Always Say What They Think](https://doi.org/10.52202/075280-3275) — A reminder that a fluent step-by-step explanation is not evidence that the agent used the reason it reports.
