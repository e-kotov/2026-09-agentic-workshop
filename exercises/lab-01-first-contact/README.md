# Lab 1: First contact

Allow about 70 minutes. Use OpenCode, this disposable Codespace, and the supplied fake data.

<details><summary>Quick start, safety, and reset</summary>

From the repository root, run `cd exercises/lab-01-first-contact` and check `pwd`. Never add credentials, restricted rows, unpublished results, or participant material. Start with ordinary approval prompts. You may use auto mode after you have seen them, but auto mode is not a security control. To reset, delete only files inside `work/` and copy them again from `task/`. Ask the facilitator if you are unsure.
</details>

## What you learn

Watch how the model, agent harness, and tools work together. Notice what enters the context, which instructions load, and when the agent asks permission. Finish with a corrected file, a passing check, and a short observation note.

## Beginner route

1. Launch the agent here. Ask: “List the files you would inspect for this task. Do not edit or run commands.” Record what it observes and what it infers.
2. Ask which project instructions and tools it can see. Let it write `work/session-notes.md`, then inspect the file yourself.
3. Give it `task/brief.md`. It should inspect the small metadata table and repair the marked issue. Keep scratch notes in `work/` and edits inside this lab.
4. Ask it to run `Rscript checks/check_metadata.R`. Inspect the output, the diff, and the corrected file. Keep `project/README.md` and `project/data/metadata.csv` for later labs.
5. After observing approval prompts, relaunch the remaining safe task from this directory with `opencode --auto` if desired. For a non-interactive prompt, use `opencode run --auto "<quoted prompt>"`. Note what changed and what did not; explicit denies remain.
6. Trigger the supplied R binary-package skill with this prompt: “The package `workshopMissing` is reported missing. Dry-diagnose the configured compatible binary route; inspect `R.version$platform` and `getOption('repos')`, run `Rscript task/r-package-diagnostic.R`, and do not install, use `sudo`, or change repositories.” Inspect the skill file and its output.

## Medium route

Compare a vague request with `task/brief.md`, diagnose the issue without dumping all files into context, and ask the agent to self-configure a project-local setting using documentation. Verify the actual setting and revert it if it is not useful.

Copyable medium prompt: “Goal: repair the metadata artefact and leave a handoff for the cumulative project. Allowed paths: this lab's `task/`, `work/`, and `project/`; do not edit inputs. State assumptions, create the expected artefact, run the focused check, and show the diff. Stop if the codebook is ambiguous.”

## Advanced audit

Record unnecessary reads, tool calls, context growth where visible, effort/model choices, and repeated work. Suggest one decomposition or instruction change that would reduce cost without hiding evidence.

## Finish

- **Expected artefact:** `project/data/metadata.csv`, `project/README.md`, `work/corrected-metadata.csv`, and `work/session-notes.md`.
- **Objective check:** `Rscript checks/check_metadata.R` exits successfully and reports the expected invariant.
- **Reflection:** Which action was verified by a tool? Which claim remained an inference? What would you change in the task brief?
