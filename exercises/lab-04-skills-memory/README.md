# Lab 4 — Skills, bounded loops, and project memory

Allow about 45 minutes. Use only this disposable Codespace and source-free files.

<details><summary>Quick start, safety, and reset</summary>

Run `cd exercises/lab-04-skills-memory`. Inspect the supplied skill and template before asking an agent to edit. Do not copy private instructor repositories, endpoints, credentials, or restricted data. Save your notes before resetting `task/` or `template/`. Stop at the human review point.
</details>

## What you learn

Put repeated knowledge in the smallest useful place: a prompt, project rule, skill, log, or deterministic script. Then test whether a fresh agent can resume from your project records.

## Core route

1. Inspect `.agents/skills/r-binary-packages/SKILL.md`. Identify its trigger, Linux/P3M scope, and limits. Do not install arbitrary packages.
2. Find one repeated safe task from the day and classify it as a one-off prompt, project/global instruction, skill, memory, or script. Explain your choice before editing.
3. Skill creation is optional. If you create/adapt one, run it on a fresh harmless case and revise it from observed behaviour.
4. Continue the cumulative project at `../lab-01-first-contact/project/`. Ask an agent to add the minimal control files there, while keeping the generic `template/` as a comparison. Do not copy private/HPC/paper machinery.
5. Perform a bounded plan–act–check–revise loop using `task/` and `checks/check_resume.py`. Set a stop condition and human review point before acting. Record work and decisions as you go, and write the small non-data classification artefact to `../lab-01-first-contact/project/analysis/outputs/placement.md`.
6. Test resumption: at this deliberate task boundary, start a fresh agent context and ask it to continue from the handoff. Compare what it knows with the actual files. A continued session might retain a warm provider cache, while a restart sends less irrelevant context and may begin cold; choose the fresh session here to test the handoff, not to optimize cache use.
7. Score usefulness, maintenance burden, duplication, stale state, context bloat, and inappropriate automation. Conductor-for-all or another system may be a comparison, never a requirement.

The facilitator may show a richer private research-control repository. Do not copy it. Compare systems by evidence and maintenance cost, not by feature count.

The cumulative end state is `../lab-01-first-contact/project/`: retain its Lab 1 input, Lab 2 checks/build note, and Lab 3 `BOUNDARY.md`, then add the reviewed `GOALS.md`, `WORKLOG.md`, `DECISIONS.md`, `HANDOFF.md`, and `analysis/` tree. The generic `template/` here is a safe starting point; copy/adapt only what the participant has reviewed.

## Medium and advanced routes

Medium: adapt the template to a safe personal project and test a fresh-session handoff. Advanced: audit previous sessions for repeated tasks, compare global versus project scope, inspect token/context/tool/skill usage, and determine whether memory reduced or increased bloat.

### Copyable starting prompts

Core: “Goal: classify the repeated task and initialize a minimal handoff. Allowed paths: `task/`, `template/`, `checks/`, and the Lab 1 cumulative project. Artefact: updated goals, work log, decision log, and handoff. Stop at the human review point. Check with `python checks/check_resume.py` and show the output.”

Medium: “Adapt only the minimal control tree for this safe task. Keep `analysis/data/` inputs unchanged, record one decision and one action, run `python checks/check_resume.py`, then start a fresh context and verify it can resume from `HANDOFF.md`. Do not use private project machinery or external data.”

## Finish

- **Expected artefact:** classified placement note at `../lab-01-first-contact/project/analysis/outputs/placement.md`, adapted minimal control tree, substantive work/decision logs, and handoff.
- **Objective check:** `python checks/check_resume.py` targets the cumulative project, rejects untouched placeholders, and confirms the required files, non-data artefact, and bounded stop condition; a fresh context can locate current state without private context.
- **Reflection:** What belongs in code rather than memory? What stale or duplicated state would make a future agent less trustworthy?

Full automation of research decisions is often premature. A good log makes human responsibility clearer.
