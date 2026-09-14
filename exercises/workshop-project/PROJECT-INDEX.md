# Cumulative project index

This starter intentionally has no exported payloads. Add a row only after the corresponding standalone checker passes, the participant reviews the files, and the documented handoff copies them into the matching folder.

| Lab | Exported artefact | Standalone check and review |
| --- | --- | --- |
| lab-01 | Add the three questionnaire-repair artefacts after review. | `Rscript checks/check_lab1.R`, then `python checks/check_project.py --labs lab-01` |
| lab-02 | Add the panel, join-QA, recovery, and invalidation artefacts after review. | Lab 2 checker, then the Lab 1+2 checkpoint |
| lab-03 | Add the sanitized control, boundary, and evidence notes after review. | Lab 3 checker, then the Lab 1+2+3 checkpoint |
| lab-04 | Add the repaired release, summary, code, goals, log, decisions, placement, and handoff after review. | Lab 4 checker, then `python checks/check_project.py` |

The checker is the source of truth for accepted relative paths and semantic requirements. This index records participant review; it is not evidence that an empty row has been completed.
