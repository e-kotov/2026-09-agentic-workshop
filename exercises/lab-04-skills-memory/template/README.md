# Minimal research-control template

This intentionally small, unpublished template records enough state for a fresh session without importing an instructor repository.

- `GOALS.md` — goal and current state
- `WORKLOG.md` — dated actions, evidence, and next step
- `DECISIONS.md` — decisions, alternatives, and rationale
- `HANDOFF.md` — what a fresh context must read first
- `analysis/data/` — safe inputs only
- `analysis/code/` — clean, reviewable code
- `analysis/tests/` — focused checks
- `analysis/outputs/` — generated artefacts

## How this maps to the full template

| Mapping |
|---|
| `GOALS.md` -> `docs/goals.md` |
| `HANDOFF.md` -> `docs/handoff.md` + `docs/current-state.md` |
| `DECISIONS.md` -> `docs/decisions/` (one file per decision, numbered) |
| `WORKLOG.md` -> `docs/work-log/` (one dated file per session) |
| `LOOP.md` -> Build/Review/Revise/Ready modes in `AGENTS.md` |
| nothing here -> `docs/knowledge/` (facts outlive a task) and `docs/review.md` |

This lab uses single files so the checker stays simple; the [full published template](https://github.com/e-kotov/2026-09-demo-control-repo) splits them so they scale and can be indexed.
