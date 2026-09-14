#!/usr/bin/env python3
from pathlib import Path

LAB = Path(__file__).resolve().parents[1]
FIXTURE = (LAB / "fixture").resolve()


def allowed(path: Path) -> bool:
    """Teaching path policy; this is not an OS sandbox or agent permission."""
    try:
        path.resolve().relative_to(FIXTURE)
        return True
    except ValueError:
        return False


assert allowed(LAB / "fixture" / "security" / "fake-output.txt")
assert not allowed(LAB.parent / "lab-01-first-contact" / "AGENTS.md")
print("external-boundary fixture passed: only lab fixture paths are allowed")
print("This unit test is static path-policy evidence, not OS or agent containment.")
