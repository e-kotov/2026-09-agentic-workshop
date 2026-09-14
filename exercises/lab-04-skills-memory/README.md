```bash
cd "$(git rev-parse --show-toplevel)/exercises/lab-04-skills-memory"
```

# Lab 4 — Skills, bounded loops, and project memory

This lab is independently complete and uses only an invented, source-free release.

## Start here

Open a VS Code terminal and paste the first command above. Run `pwd`. It must end in `/exercises/lab-04-skills-memory`. If it does not, stop and ask for help.

Choose a route before editing:

- **Standalone — recommended:** work only in this lab. The supplied release and checker are sufficient.
- **Cumulative — optional:** after the standalone checker passes and a human reviews the payload, copy the allowlisted artefacts to `exercises/workshop-project/lab-04/` with `bash tools/handoff.sh`.

If you do not choose, stay standalone. Never provide credentials, restricted rows, unpublished results, or personal/participant data. `fixture/`, `checks/`, `tools/`, and the shipped skill are read-only; edit only `work/`.

Start the disposable area and run the exact checker:

```bash
bash tools/start_lab.sh
Rscript checks/check_lab4.R
```

The first check is expected to fail without consuming an attempt:

```text
PASS precondition: fixture fails only income_consistency at P000040::2019
FAIL incomplete: repaired release, summary, loop log, and handoff are required
```

Copyable starting prompt (adapt it after orientation, before acting):

```text
Goal: repair the named imputation inconsistency and publish a checked weighted and unweighted income summary.
Allowed paths: read immutable fixture/release/ and task/; create or edit only work/.
Use the task scripts as templates, adapt the four control notes from template/, and keep the attempt budget at two.
Run the exact checks: Rscript checks/check_release.R, then Rscript checks/check_lab4.R.
Stop after a passing attempt for human review, or after failed attempt 2; never start attempt 3 or use external data.
```

## What you learn

Put durable knowledge in the smallest correct place: classify a repeated task, keep deterministic repair and summaries in code, record decisions without duplicating stale history, and leave a handoff that a fresh context can resume under human supervision. The simplified weights and incomes are teaching constructs, not SOEP estimates or substantive findings.

## Beginner — recommended

Do not complete every route. Finish Beginner — recommended, then choose at most one optional route if time remains.

1. **Start and place the work (5 min).** Inspect `.agents/skills/r-binary-packages/SKILL.md` briefly. Classify release validation/manifest regeneration in `work/placement.md`. Initialize `work/` and write the two-attempt rule in `work/LOOP.md` before editing.
2. **Precheck and diagnosis (6 min).** Read the named failure and inspect only the relevant record, response, schema, and manifest fields. The pre-task checker is orientation evidence and does not consume an attempt.
3. **Repair and rebuild manifest (10 min).** Copy or adapt `task/repair_release_template.R` to `work/code/repair_release.R`, then run it. It must copy the immutable release, change only `income_imp` for `P000040::2019` from 0 to 1, and recompute every declared row count and SHA-256 in deterministic code. Never hand-edit a checksum or copy the clean manifest blindly.
4. **Produce the summary (8 min).** Copy or adapt `task/summarize_income_template.R` to `work/code/summarize_income.R`, run it against `work/release`, and inspect `work/outputs/income-summary.csv`. Adapt `template/GOALS.md`, `template/WORKLOG.md`, `template/DECISIONS.md`, and `template/HANDOFF.md` into `work/` before the attempt. The summary counts interviewed employed person-wave records and reports arithmetic and `person_xs_weight`-weighted means of `income_final`, including imputed values.
5. **Check/revise within budget (6 min).** Run `bash tools/run_attempt.sh 1`. If it fails, make one evidence-based revision and run `bash tools/run_attempt.sh 2`; if it passes, stop. Never start attempt 3.
6. **Decisions and handoff (7 min).** Review `GOALS.md`, the generated attempt log(s), `DECISIONS.md`, `WORKLOG.md`, `HANDOFF.md`, and the placement rationale. After the final checker result, update `WORKLOG.md` and `HANDOFF.md` so they record the actual PASS (or failed attempt 2), the current state, and human-review/stop next action. A fresh context should know the source, current state, exact check, uncertainty, next action, stop, and human-review point without private context.
7. **Human review and close (3 min).** Inspect the repaired row, manifest, summary, and exact checker result. Stop at the named human-review point.

## Optional medium route

Do not complete every route. Finish Beginner — recommended, then choose at most one optional route if time remains.

Reset safely, start a fresh agent context, and test whether `HANDOFF.md` alone is sufficient to resume. Record missing information and revise the handoff once. This is not part of the deterministic release gate.

## Optional advanced route

Do not complete every route. Finish Beginner — recommended, then choose at most one optional route if time remains.

Skill creation is optional. First use `work/placement.md` to classify the repeated task. Keep a one-off request in a prompt, project-wide rules in `AGENTS.md`, durable task-specific judgement in a skill, session state in the handoff/logs, and fixed transformations or assertions in deterministic code. Continue only if a reusable skill is a better fit than those alternatives.

- **Keep it project-local and disposable.** Create `work/.agents/skills/release-review/SKILL.md`; do not alter the shipped skill. Use lowercase `release-review` for both the directory and frontmatter `name`. Give it a precise description such as `Use after a deterministic release check passes to review the invented Lab 4 manifest, summary, and handoff without editing them.` In the body, name the allowed files, require read-only review, and require the checker result as evidence. Add no credentials, network calls, installation steps, or claims that the skill provides isolation.
- **Make a fresh harmless case.** After the mandatory checker passes, run `cp -R work/release work/skill-test-release` from this lab directory. The copy contains only invented data. Keep repair and validation in the existing R scripts; the skill should guide review rather than replace a deterministic check.
- **Verify discovery in a fresh session.** Start OpenCode from `work/`, ask it to list the skills it can see without loading them, and confirm that `release-review` appears. If it does not, check the exact `.agents/skills/release-review/SKILL.md` path, YAML frontmatter, and current directory, then start another fresh session.
- **Invoke and observe.** Prompt: `Use the release-review skill to inspect skill-test-release and the existing summary and handoff. Do not edit files.` Confirm that OpenCode makes a skill-tool call, follows the read-only scope, and cites the deterministic checker result. Then try one unrelated prompt; the skill should not activate. Agent narration alone is not proof that it loaded the skill.
- **Review the trade-off.** Record whether project scope reduced irrelevant guidance compared with a global skill, and whether the skill added context bloat, maintenance burden, stale duplication, or inappropriate automation. Test behavior is evidence; model reasoning traces are not faithful audit logs.
- **Remove or archive the experiment.** Close the test session. To retain it without keeping the skill discoverable, run `mkdir -p work/skill-experiment-archive && mv work/.agents/skills/release-review work/skill-test-release work/skill-experiment-archive/`. To reset the whole lab instead, use the existing `bash tools/reset_lab.sh --archive` procedure.

### Optional advanced comparison: published control project

Only after the mandatory route and a human choice, inspect the public [demo-control-project](https://github.com/e-kotov/2026-09-demo-control-repo) template. Start with: `Read AGENTS.md and follow its Initial setup section`. Compare its Build → Review → Revise → Ready protocol and OKF-style `docs/` structure with this lab's minimal handoff. Assess the added oversight and cataloguing against maintenance, duplication, and staleness; do not copy or freeze its contents. Keep this comparison optional, use only invented or otherwise approved safe data, and do not treat the online repository as a prerequisite or as proof that the local sibling matches its current HEAD.

## Bounded loop and artefacts

Declare this before the first edit:

```text
Attempt budget: at most 2.
Each attempt: diagnose one failing invariant -> make one bounded change -> regenerate affected derived artefacts and manifest -> run Rscript checks/check_release.R -> record exact output.
Stop immediately when the checker passes. If attempt 2 fails, stop without further edits and request human review. Never start attempt 3.
```

Required work artefacts are `release/`, `code/repair_release.R`, `code/summarize_income.R`, `outputs/income-summary.csv`, `LOOP.md`, `GOALS.md`, `WORKLOG.md`, `logs/attempt-1.txt` and optional `attempt-2.txt`, `DECISIONS.md`, `HANDOFF.md`, and `placement.md`. `bash tools/run_attempt.sh N` generates the attempt evidence and refuses attempt 3 or an unnecessary attempt 2.

## Stop, reset, or continue

Stop the mandatory task when `Rscript checks/check_lab4.R` exits 0 and prints `PASS lab 4: imputation flag, release manifest, income summary, bounded loop, logs, and handoff verified`. Review the repaired row, manifest, summary, and logs yourself; do not continue because an agent suggests more automation.

- Safe reset: `bash tools/reset_lab.sh --archive` archives this lab's `work/` under `.reset-archive/` and recreates it. It does not touch another lab or the cumulative project.
- Optional cumulative export, only after review: `bash tools/handoff.sh` (type its explicit confirmation). It copies the allowlisted payload into `exercises/workshop-project/lab-04/`.
- To check that exported payload explicitly, run from this lab: `Rscript checks/check_lab4.R --cumulative "$(git rev-parse --show-toplevel)/exercises/workshop-project/lab-04"`.
- After standalone completion, optional project navigation: `cd "$(git rev-parse --show-toplevel)/exercises/workshop-project"`. If it has not been initialized, stop; this lab does not create it implicitly.

## Read next

- [Lost in the Middle](https://doi.org/10.1162/tacl_a_00638) — Why a maintained handoff can beat carrying an ever-growing conversation into a next task.
- [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — Compare structured notes and just-in-time retrieval with this minimal project memory.
- [Ten Simple Rules for Reproducible Computational Research](https://doi.org/10.1371/journal.pcbi.1003285) — Keeps the exercise tied to provenance and reproducibility rather than memory-system feature count.

The ecosystem contains hundreds of memory and automation systems. Experience and evaluation must determine what helps a particular workflow. Full automation of research decisions is often premature; logs and memory should make human responsibility clearer, not obscure it.
