# Optional cumulative project

This folder is an optional, participant-review-gated integration surface. It is shipped empty: the four lab folders contain only `.gitkeep` files, so no lab is pre-solved and no payload is an answer key. Standalone labs remain complete by themselves.

## Start and check

```bash
cd "$(git rev-parse --show-toplevel)/exercises/workshop-project"
pwd
python checks/check_project.py
```

The working path must end in `/exercises/workshop-project`. The initial no-argument check is expected to fail with missing exported payloads. After each standalone lab passes and a human reviews its artefacts, run that lab's documented handoff from its own directory. Handoffs copy allowlisted files, never fixtures or caches, and refuse accidental overwrite. Export in order: Lab 1, Lab 2, Lab 3, then Lab 4.

Use the checkpoint command after each export:

```bash
python checks/check_project.py --labs lab-01
python checks/check_project.py --labs lab-01 lab-02
python checks/check_project.py --labs lab-01 lab-02 lab-03
python checks/check_project.py
```

The final command is the only command that claims the complete cumulative route. It validates fresh exported bytes semantically: table shape, keys, QA evidence, repair evidence, manifest hashes, bounded notes, and handoff content. It does not compare participant work with a frozen hash. A failing checkpoint is a stop condition; return to the relevant lab, review the change, and export into a fresh empty destination or use that lab's explicit reviewed-overwrite flow. Never hand-edit a cumulative payload to make the checker pass.

## Learning contract

Agent-learning goal: practise sequential context handoff, selective export, semantic verification, provenance, and explicit human review across otherwise independent agent tasks.

Plausible staff task: assemble a small, source-free synthetic-panel audit trail from independently repaired questionnaire, panel-QA, boundary, and release-summary work.

Expected artefacts are the allowlisted files under `lab-01/` through `lab-04/`, plus `PROJECT-INDEX.md`, `PROJECT-HANDOFF.md`, and the generated `checks/project-results.txt`. No restricted rows, credentials, attack fixtures, raw security samples, nested Git repositories, or symlinks belong here.

The mandatory linear spine is: finish and review each standalone lab; copy only its reviewed handoff payload; run the matching checkpoint; update the index and handoff; stop after the first failing check or after the complete pass. This route is feasible in about 70 minutes only when the standalone work is already complete. Choose the cumulative route only if the tutor allocates time; do not complete every route.

Reflection: Which claim came from a checker, which came from a human review, and what would remain uncertain if one lab were re-run?

## Navigation

Begin with [Lab 1](../lab-01-first-contact/README.md). The cumulative route is optional and never a prerequisite for Lab 2, Lab 3, or Lab 4.
