from pathlib import Path

LAB = Path(__file__).resolve().parents[1]
# This is a path-policy unit example, not an OS sandbox or agent permission.

def allowed(path: Path) -> bool:
    """Teaching guard: permit only paths below this lab's fixture tree."""
    try:
        path.resolve().relative_to((LAB / "fixture").resolve())
        return True
    except ValueError:
        return False

assert allowed(LAB / "fixture" / "fake-output.txt")
assert not allowed(LAB.parent / "lab-01-first-contact" / "AGENTS.md")
print("external-boundary fixture passed: only fixture paths are allowed")
