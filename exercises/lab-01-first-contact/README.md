# Lab 1 — First contact and core mechanics

**Time:** about 70 minutes. **Agent:** OpenCode is the supported path. Use only this disposable Codespace and fake/source-free data.

<details><summary>Quick start, safety, and reset</summary>

From the repository root, run `cd exercises/lab-01-first-contact` and inspect `pwd`. Do not add credentials, restricted rows, unpublished results, or participant material. Begin with ordinary approval prompts; after observing them, auto mode is convenient inside this disposable environment but is not security. Reset by deleting only files inside `work/` and copying from `task/`, or ask the facilitator. Never reset the repository broadly.
</details>

## What you learn

Observe the model–harness–tool loop, context selection, project instructions, skills, permissions, and the difference between an answer and a verified change. You will create a corrected small artefact, a deterministic check, and a short observation note.

## Beginner route

1. Launch an agent here with a read-only orientation prompt: “List the files you would inspect for this task. Do not edit or run commands.” Record what it actually observes versus infers.
2. Ask what project instructions and tools it can observe. It may write an account to `work/session-notes.md`; inspect the file rather than trusting the prose.
3. Give it the bounded task in `task/brief.md`: inspect the tiny metadata table and repair the clearly marked issue. Save the cumulative project at `project/` and keep scratch notes under `work/`. Allow reads and edits only within this lab.
4. Ask it to run `Rscript checks/check_metadata.R` and show the output. Inspect the diff and the generated artefact, then leave `project/README.md` and `project/data/metadata.csv` for Labs 2–4.
5. After observing approval prompts, relaunch the remaining safe task from this directory with `opencode --auto` if desired. For a non-interactive prompt, use `opencode run --auto "<quoted prompt>"`. Note what changed and what did not; explicit denies remain.
6. Trigger the shipped R binary-package skill with this copyable request: “The package `workshopMissing` is reported missing. Dry-diagnose the configured compatible binary route; inspect `R.version$platform` and `getOption('repos')`, run `Rscript task/r-package-diagnostic.R`, and do not install, use `sudo`, or change repositories.” Inspect the skill file and diagnostic output.

## Medium route

Compare a vague request with `task/brief.md`, diagnose the issue without dumping all files into context, and ask the agent to self-configure a project-local setting using documentation. Verify the actual setting and revert it if it is not useful.

Copyable medium prompt: “Goal: repair the metadata artefact and leave a handoff for the cumulative project. Allowed paths: this lab's `task/`, `work/`, and `project/`; do not edit inputs. State assumptions, create the expected artefact, run the focused check, and show the diff. Stop if the codebook is ambiguous.”

## Advanced audit

Record unnecessary reads, tool calls, context growth where visible, effort/model choices, and repeated work. Suggest one decomposition or instruction change that would reduce cost without hiding evidence.

## Exact data-task design TODO (bounded)

**TODO (later data-task design session):** replace the toy metadata repair in `task/metadata.csv` with the approved canonical synthetic-panel task and its named one-defect variant. Specify the exact schema, defect, expected row-level output, and check command only after `data/synthetic-panel/**` and the instructor review are complete. Do not substitute real SOEP data.

## Artefact, check, reflection

- **Expected artefact:** `project/data/metadata.csv`, `project/README.md`, `work/corrected-metadata.csv`, and `work/session-notes.md`.
- **Objective check:** `Rscript checks/check_metadata.R` exits successfully and reports the expected invariant.
- **Reflection:** Which action was verified by a tool? Which claim remained an inference? What would you change in the task brief?
