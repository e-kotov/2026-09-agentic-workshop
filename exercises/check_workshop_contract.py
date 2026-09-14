#!/usr/bin/env python3
"""Static usability contract checks for the four standalone workshop labs.

This checker reads only public lab source files. It does not enter participant
workspaces, run agent sessions, write artefacts, or inspect the cumulative
project.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LABS = (
    {
        "number": "01",
        "folder": "lab-01-first-contact",
        "checker": "Rscript checks/check_lab1.R",
        "next": 'cd "$(git rev-parse --show-toplevel)/exercises/lab-02-engineering"',
    },
    {
        "number": "02",
        "folder": "lab-02-engineering",
        "checker": "Rscript checks/check_lab2.R",
        "next": 'cd "$(git rev-parse --show-toplevel)/exercises/lab-03-security"',
    },
    {
        "number": "03",
        "folder": "lab-03-security",
        "checker": "python checks/check_lab3.py",
        "next": 'cd "$(git rev-parse --show-toplevel)/exercises/lab-04-skills-memory"',
    },
    {
        "number": "04",
        "folder": "lab-04-skills-memory",
        "checker": "Rscript checks/check_lab4.R",
        "next": 'cd "$(git rev-parse --show-toplevel)/exercises/workshop-project"',
    },
)
REQUIRED_WARNING = "Do not complete every route. Finish Beginner — recommended, then choose at most one optional route if time remains."
IMPORT = b"@AGENTS.md\n"


def fail(failures: list[str], lab: str, message: str) -> None:
    failures.append(f"{lab}: {message}")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def first_cd_line(text: str) -> str | None:
    for line in text.splitlines():
        candidate = line.strip().strip("`")
        if candidate.startswith("cd "):
            return candidate
    return None


def opening_bash_block(text: str) -> list[str] | None:
    """Return the non-empty lines when a fenced Bash block opens the file."""
    match = re.match(r"\A[\t ]*```bash[\t ]*\n(.*?)^```[\t ]*$", text, re.MULTILINE | re.DOTALL)
    if match is None:
        return None
    return [line.strip() for line in match.group(1).splitlines() if line.strip()]


def check_readme(meta: dict[str, str], failures: list[str]) -> None:
    folder = meta["folder"]
    lab = ROOT / "exercises" / folder
    path = lab / "README.md"
    label = folder
    if not path.is_file():
        fail(failures, label, "README.md is missing")
        return
    text = read(path)
    expected_cd = f'cd "$(git rev-parse --show-toplevel)/exercises/{folder}"'
    if first_cd_line(text) != expected_cd:
        fail(failures, label, f"first anywhere cd command must be exactly: {expected_cd}")
    if opening_bash_block(text) != [expected_cd]:
        fail(failures, label, "README must begin with a fenced Bash block containing only the canonical navigation command")
    if not re.search(rf"must end in `/exercises/{re.escape(folder)}`", text):
        fail(failures, label, "README does not state the expected pwd suffix")
    if meta["checker"] not in text:
        fail(failures, label, f"exact checker command is missing: {meta['checker']}")
    if text.startswith("---"):
        fail(failures, label, "README must not have YAML front matter")
    if len(re.findall(r"^# [^#].*$", text, re.MULTILINE)) != 1:
        fail(failures, label, "README must contain exactly one H1")

    for heading in ("## Beginner — recommended", "## Optional medium route", "## Optional advanced route"):
        if heading not in text:
            fail(failures, label, f"missing required route heading: {heading}")
    if REQUIRED_WARNING not in text:
        fail(failures, label, "missing exact do-not-complete-all warning")
    numbers = [int(match.group(1)) for match in re.finditer(r"^\s*(\d+)\.\s+", text, re.MULTILINE)]
    if not numbers or numbers[0] != 1 or numbers != list(range(1, max(numbers) + 1)) or max(numbers) < 5:
        fail(failures, label, "Beginner route must contain one ordered mandatory numbered spine")

    if "Standalone — recommended" not in text or "Cumulative — optional" not in text:
        fail(failures, label, "README must state standalone default and cumulative optional routes")
    if not re.search(r"If you do not choose, stay standalone", text, re.I):
        fail(failures, label, "README must make standalone the default when no route is chosen")
    if "## Stop, reset, or continue" not in text:
        fail(failures, label, "missing stop/reset section")
    stop_start = text.find("## Stop, reset, or continue")
    stop_text = text[stop_start:] if stop_start >= 0 else ""
    if meta["checker"] not in stop_text or "exits 0" not in stop_text:
        fail(failures, label, "stop section must name the exact checker and its exit-0 condition")
    if "bash tools/reset_lab.sh --archive" not in stop_text:
        fail(failures, label, "stop section must name safe reset")
    if "bash tools/handoff.sh" not in stop_text:
        fail(failures, label, "stop section must name optional cumulative export")
    if meta["next"] not in stop_text:
        fail(failures, label, f"stop section must name next navigation: {meta['next']}")
    if not re.search(r"review", stop_text, re.I) or not re.search(r"(?:Do not start an optional route|do not continue because an agent suggests)", stop_text, re.I):
        fail(failures, label, "stop section must require human review before optional work")

    # The README must expose an explicit cumulative checker/path, not merely
    # mention that handoff exists.
    if "--cumulative" not in text or not re.search(rf"{re.escape(meta['checker'])}[^\n]*--cumulative[^\n]*", text):
        fail(failures, label, "README lacks an explicit --cumulative checker/path command")


def check_checker_cli(meta: dict[str, str], failures: list[str]) -> None:
    folder = meta["folder"]
    lab = ROOT / "exercises" / folder
    checker_path = lab / "checks" / Path(meta["checker"].split()[-1]).name
    label = folder
    if not checker_path.is_file():
        fail(failures, label, f"checker is missing: {checker_path.relative_to(ROOT)}")
        return
    text = read(checker_path)
    if "--cumulative" not in text:
        fail(failures, label, "checker CLI does not expose --cumulative")
    if not re.search(r"(?:work|base|cumulative)[^\n]{0,100}", text, re.I):
        fail(failures, label, "checker has no visible standalone/cumulative base handling")
    if "usage:" not in text.lower():
        fail(failures, label, "checker lacks a usage/interface message")


def check_instructions(meta: dict[str, str], failures: list[str]) -> None:
    folder = meta["folder"]
    lab = ROOT / "exercises" / folder
    label = folder
    agents = lab / "AGENTS.md"
    if not agents.is_file() or len(read(agents).strip()) < 40:
        fail(failures, label, "AGENTS.md is missing or implausibly short")
    for name in ("CLAUDE.md", "GEMINI.md"):
        path = lab / name
        if not path.is_file() or path.read_bytes() != IMPORT:
            fail(failures, label, f"{name} must be exactly @AGENTS.md followed by one newline")
    adapter = lab / ".agents" / "rules" / "workshop.md"
    if not adapter.is_file():
        fail(failures, label, "Antigravity adapter is missing")
    else:
        adapter_text = read(adapter)
        if "@../../AGENTS.md" not in adapter_text or "Antigravity" not in adapter_text:
            fail(failures, label, "Antigravity adapter lacks its relative AGENTS import")


def check_wrapper(meta: dict[str, str], failures: list[str]) -> None:
    folder = meta["folder"]
    path = ROOT / "tutorial-website-src" / "labs" / f"lab-{meta['number']}.qmd"
    label = folder
    if not path.is_file():
        fail(failures, label, f"thin Quarto wrapper is missing: {path.relative_to(ROOT)}")
        return
    lines = [line.strip() for line in read(path).splitlines() if line.strip()]
    include = f"{{{{< include ../../exercises/{folder}/README.md >}}}}"
    if lines.count(include) != 1:
        fail(failures, label, "Quarto wrapper must include its lab README exactly once")
    extras = [line for line in lines if line != "---" and line != 'title: ""' and line != include]
    if extras:
        fail(failures, label, f"Quarto wrapper is not thin include-only content: {extras}")


def check_cross_paths(meta: dict[str, str], failures: list[str]) -> None:
    folder = meta["folder"]
    lab = ROOT / "exercises" / folder
    label = folder
    for path in lab.rglob("*"):
        if not path.is_file() or ".reset-archive" in path.parts or "work" in path.parts or "fixture" in path.parts:
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        if re.search(r"\.\./lab-0\d", text):
            fail(failures, label, f"forbidden direct cross-lab path in {path.relative_to(lab)}")


def main() -> int:
    failures: list[str] = []
    for meta in LABS:
        check_readme(meta, failures)
        check_checker_cli(meta, failures)
        check_instructions(meta, failures)
        check_wrapper(meta, failures)
        check_cross_paths(meta, failures)
    if failures:
        print("FAIL workshop usability contract:")
        for item in failures:
            print(f"FAIL {item}")
        print("NOTE: failures naming a lab are correction payloads for that lab owner; this checker does not edit lab files.")
        return 1
    print("PASS workshop usability contract: four labs, instructions, checkers, wrappers, and navigation verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
