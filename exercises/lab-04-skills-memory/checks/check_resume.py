from pathlib import Path

root = Path(__file__).parents[1]
cumulative = root.parent / "lab-01-first-contact" / "project"
required = [
    "README.md", "BOUNDARY.md", "GOALS.md", "WORKLOG.md", "DECISIONS.md", "HANDOFF.md",
    "analysis/data/README.md", "analysis/code/README.md", "analysis/tests/README.md",
    "analysis/outputs/README.md", "analysis/outputs/placement.md",
]
missing = [path for path in required if not (cumulative / path).is_file()]
if missing:
    raise SystemExit("missing cumulative control files: " + ", ".join(missing))
contents = {path: (cumulative / path).read_text() for path in required}
for name in ("DECISIONS.md", "HANDOFF.md"):
    shipped = (root / "template" / name).read_bytes()
    if (cumulative / name).read_bytes() == shipped:
        raise SystemExit(f"participant must replace or extend shipped template {name}")
placeholder_markers = ("[write", "not started", "yyyy-mm-dd", "[todo", "[fill")
for path, text in contents.items():
    if path not in {"README.md", "analysis/data/README.md", "analysis/code/README.md", "analysis/tests/README.md", "analysis/outputs/README.md"} and any(marker in text.lower() for marker in placeholder_markers):
        raise SystemExit(f"untouched placeholder remains in cumulative {path}")
handoff = contents["HANDOFF.md"]
handoff_lower = handoff.lower()
if "human review" not in handoff_lower or "stop" not in handoff_lower:
    raise SystemExit("handoff lacks a stop condition and human review point")
if "current state" not in handoff_lower or "next" not in handoff_lower or not any(term in handoff_lower for term in ("placement", "sample", "task", "cumulative")):
    raise SystemExit("handoff lacks a task-specific current state and next action")
if "classification" not in contents["analysis/outputs/placement.md"].lower() or "evidence" not in contents["analysis/outputs/placement.md"].lower():
    raise SystemExit("placement artefact needs a classification and evidence")
if contents["WORKLOG.md"].count("|") < 6 or "action" not in contents["WORKLOG.md"].lower():
    raise SystemExit("work log lacks substantive action/evidence entries")
decisions_lower = contents["DECISIONS.md"].lower()
if not all(term in decisions_lower for term in ("decision", "alternatives", "evidence", "rationale")) or not any(term in decisions_lower for term in ("placement", "sample", "task", "cumulative")):
    raise SystemExit("decision log lacks a task-specific decision, alternatives, evidence, and rationale")
print("resume contract passed: cumulative control tree, artefact, logs, and bounded handoff are present")
