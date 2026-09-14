# Cumulative project handoff

## Current state

This fresh optional starter contains no lab payloads. The `.gitkeep` files preserve the four export destinations; they are not participant solutions. Standalone labs and their human review remain the source of any future payload.

## Check and next action

Run `python checks/check_project.py --labs lab-01` after the first reviewed export, then extend the checkpoint in lab order. Run `python checks/check_project.py` only after all four handoffs pass. The checker writes `checks/project-results.txt`; inspect it and the index after every pass.

## Uncertainty and stop

The project checker establishes structural and semantic properties of source-free teaching artefacts. It does not establish substantive validity, model resistance, operating-system isolation, or production release quality. Stop on a failed check, an unexpected file, an overwrite prompt, or an unresolved human-review question. Return to the standalone lab rather than repairing a cumulative copy.

## Human owner and safety boundary

The participant owns the export decision and a tutor reviews the allowlist, provenance, generated evidence, and final result. Copy only the documented payloads. Keep credentials, restricted or personal rows, fixtures, raw security samples, caches, symlinks, and nested Git metadata outside this folder. The cumulative route is optional and does not gate any next lab.
