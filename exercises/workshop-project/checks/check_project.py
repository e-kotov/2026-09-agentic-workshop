#!/usr/bin/env python3
"""Semantic checkpoint for the optional, participant-exported project.

The starter is intentionally empty.  This checker validates the artefacts that
the lab handoffs produce, rather than comparing them with a frozen answer.
"""

from __future__ import annotations

import csv
import hashlib
import math
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
# Handoff tests commonly copy the exercise directories into a flat disposable
# root (rather than preserving the repository's exercises/ wrapper).
if not (REPO / "exercises" / "lab-02-engineering").is_dir() and (ROOT.parent / "lab-02-engineering").is_dir():
    REPO = ROOT.parent
RESULTS = ROOT / "checks" / "project-results.txt"

ALLOWLIST = {
    "lab-01": {
        "corrected-questionnaire.csv", "provenance.md", "session-observations.md", ".gitkeep"
    },
    "lab-02": {
        "derived/person_wave.csv", "derived/person_household_wave.csv",
        "qa/duplicate-proof.csv", "qa/join-qa.csv", "qa/wave-qa.csv",
        "tests/test_panel_contract.R", "git-recovery.txt", "invalidation-evidence.txt", ".gitkeep",
        "derived/.gitkeep", "qa/.gitkeep", "tests/.gitkeep"
    },
    # Lab 3's handoff sanitises its evidence before copying it here.  The
    # fixture and raw security samples remain lab-local.
    "lab-03": {
        "threat-control.md", "BOUNDARY.md", "evidence/manifest.txt",
        "evidence/permission.md", "evidence/injection.md", "evidence/redaction.txt", ".gitkeep", "evidence/.gitkeep"
    },
    "lab-04": {
        "release/household_wave.csv", "release/person_static.csv", "release/person_wave.csv",
        "release/questionnaire.csv", "release/release_manifest.csv", "release/response.csv",
        "release/schema.csv", "code/repair_release.R", "code/summarize_income.R",
        "outputs/income-summary.csv", "LOOP.md", "GOALS.md", "WORKLOG.md",
        "logs/attempt-1.txt", "logs/attempt-2.txt", "DECISIONS.md", "HANDOFF.md",
        "placement.md", ".gitkeep", "code/.gitkeep", "logs/.gitkeep", "outputs/.gitkeep"
    },
}
REQUIRED = {
    "lab-01": {"corrected-questionnaire.csv", "provenance.md", "session-observations.md"},
    "lab-02": {
        "derived/person_wave.csv", "derived/person_household_wave.csv",
        "qa/duplicate-proof.csv", "qa/join-qa.csv", "qa/wave-qa.csv",
        "tests/test_panel_contract.R", "git-recovery.txt", "invalidation-evidence.txt"
    },
    "lab-03": {
        "threat-control.md", "BOUNDARY.md", "evidence/manifest.txt",
        "evidence/permission.md", "evidence/injection.md", "evidence/redaction.txt"
    },
    "lab-04": {
        "release/household_wave.csv", "release/person_static.csv", "release/person_wave.csv",
        "release/questionnaire.csv", "release/release_manifest.csv", "release/response.csv",
        "release/schema.csv", "code/repair_release.R", "code/summarize_income.R",
        "outputs/income-summary.csv", "LOOP.md", "GOALS.md", "WORKLOG.md", "logs/attempt-1.txt",
        "DECISIONS.md", "HANDOFF.md", "placement.md"
    },
}
LAB_ORDER = tuple(ALLOWLIST)
PLACEHOLDER = re.compile(r"\b(?:TODO|TBD|placeholder|fill[ -]?in|not started)\b", re.I)


def entries(folder: Path) -> set[str]:
    result: set[str] = set()
    if not folder.exists():
        return result
    for path in folder.rglob("*"):
        if path.is_symlink() or path.is_file():
            result.add(path.relative_to(folder).as_posix())
        elif path.is_dir() and path.name == ".git":
            result.add(path.relative_to(folder).as_posix())
    return result


def files(folder: Path):
    for path in folder.rglob("*"):
        if path.is_file() and not path.is_symlink():
            yield path


def read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def run_command(command: list[str], failures: list[str], label: str, timeout: int = 90) -> bool:
    """Run a checker-owned command and retain a short actionable failure."""
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        failures.append(f"{label} could not be executed: {error}")
        return False
    if result.returncode:
        output = (result.stdout + result.stderr).strip().splitlines()
        detail = output[-1] if output else f"exit {result.returncode}"
        failures.append(f"{label} rejected exported payload: {detail}")
        return False
    return True


def canonical_lab1_fixture() -> Path | None:
    source = REPO / "data" / "synthetic-panel" / "fixtures" / "defects" / "duplicate_questionnaire_item"
    if (source / "questionnaire.csv").is_file():
        return source
    lab = REPO / "exercises" / "lab-01-first-contact"
    if not lab.is_dir():
        lab = REPO / "lab-01-first-contact"
    fallback = lab / "fixture" / "release"
    return fallback if (fallback / "questionnaire.csv").is_file() else None


def exercise_dir(name: str) -> Path:
    wrapped = REPO / "exercises" / name
    return wrapped if wrapped.is_dir() else REPO / name


def need_text(path: Path, failures: list[str], label: str) -> str:
    if not path.is_file():
        failures.append(f"missing {label}")
        return ""
    if path.stat().st_size == 0:
        failures.append(f"empty exported artefact: {label}")
        return ""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as error:
        failures.append(f"cannot read {label}: {error}")
        return ""
    if PLACEHOLDER.search(text):
        failures.append(f"placeholder text in exported artefact: {label}")
    return text


def check_lab1(folder: Path, failures: list[str]) -> None:
    path = folder / "corrected-questionnaire.csv"
    try:
        columns, rows = read_csv(path)
        keys = [(row.get("wave"), row.get("item_id")) for row in rows]
        required = {"wave", "item_id", "instrument", "variable", "value_type", "allowed_codes",
                    "minimum", "maximum", "required_if", "label", "metadata_version"}
        if len(rows) != 16 or len(set(keys)) != 16 or keys.count(("2019", "EMP")) != 1:
            failures.append("lab-01 corrected questionnaire must contain 16 unique rows including one 2019::EMP")
        if set(columns) != required:
            failures.append("lab-01 corrected questionnaire columns are incomplete")
    except (OSError, csv.Error) as error:
        failures.append(f"cannot parse lab-01 corrected questionnaire: {error}")
    # Bind the export to the immutable source fixture.  Shape checks alone
    # permit the reviewed counterexample (change one label or delete a
    # different row while keeping 16 rows) to pass.
    canonical = canonical_lab1_fixture()
    if canonical is None:
        failures.append("lab-01 canonical duplicate-questionnaire fixture is unavailable")
    else:
        try:
            source_columns, source_rows = read_csv(canonical / "questionnaire.csv")
            source_keys = [(row.get("wave"), row.get("item_id")) for row in source_rows]
            expected_rows = [row for index, row in enumerate(source_rows) if source_keys.index((row.get("wave"), row.get("item_id"))) == index]
            out_columns, out_rows = read_csv(path)
            if out_columns != source_columns or out_rows != expected_rows:
                failures.append("lab-01 corrected questionnaire is not stable-first output from the canonical fixture")
            manifest_rows = read_csv(canonical / "release_manifest.csv")[1]
            q_manifest = next((row for row in manifest_rows if row.get("file_name") == "questionnaire.csv"), None)
            if q_manifest is None or q_manifest.get("sha256") != hashlib.sha256((canonical / "questionnaire.csv").read_bytes()).hexdigest():
                failures.append("lab-01 canonical manifest does not bind questionnaire.csv to its bytes")
            if q_manifest is None or q_manifest.get("source_provenance") != "source-free: no respondent/source records are generator inputs":
                failures.append("lab-01 canonical manifest has false or missing source provenance")
        except (OSError, csv.Error, StopIteration) as error:
            failures.append(f"cannot independently bind lab-01 questionnaire fixture: {error}")
    provenance = need_text(folder / "provenance.md", failures, "lab-01/provenance.md")
    # Require the reviewed four-line provenance contract, not merely words
    # that can be retained while changing the source or repair description.
    provenance_lines = {line.strip() for line in provenance.splitlines() if line.strip()}
    exact_provenance = {
        "Source: fixture/release/questionnaire.csv (source-free synthetic fixture).",
        "Defect: 2019::EMP was an exact duplicate.",
        "Transformation: removed one exact duplicate; retained one declaration.",
        "Verification: Rscript checks/check_lab1.R",
    }
    for line in exact_provenance:
        if line not in provenance_lines:
            failures.append(f"lab-01 provenance omits reviewed detail: {line}")
    if provenance_lines != exact_provenance:
        failures.append("lab-01 provenance contains unreviewed or altered claims")
    observations = need_text(folder / "session-observations.md", failures, "lab-01/session-observations.md")
    lines = observations.splitlines()
    headings = ("Observed", "Inferred", "Permission", "Verification")
    for heading in headings:
        positions = [index for index, line in enumerate(lines) if line.strip() == heading]
        if len(positions) != 1:
            failures.append(f"lab-01 observations must contain one heading: {heading}")
        else:
            start = positions[0] + 1
            end = next((i for i in range(start, len(lines)) if lines[i].strip() in headings), len(lines))
            body = [line.strip() for line in lines[start:end] if line.strip()]
            if not body:
                failures.append(f"lab-01 observations heading is empty: {heading}")


def check_lab2(folder: Path, failures: list[str]) -> None:
    try:
        columns, rows = read_csv(folder / "derived/person_wave.csv")
        keys = [(row.get("pid"), row.get("wave")) for row in rows]
        if len(rows) != 513 or len(set(keys)) != 513:
            failures.append("lab-02 person_wave must contain 513 unique pid/wave rows")
        if set(columns) != {"pid", "wave", "hid", "age", "employment_status", "response_mode",
                            "response_status", "moved_since_prior_wave", "income_raw", "income_final",
                            "income_imp", "income_missing_code", "person_xs_weight", "long_weight_2019_2022"}:
            failures.append("lab-02 person_wave columns are incomplete")
        by_wave = {str(wave): [row for row in rows if str(row.get("wave")) == str(wave)] for wave in (2019, 2020, 2021, 2022)}
        if {wave: len(values) for wave, values in by_wave.items()} != {"2019": 130, "2020": 122, "2021": 137, "2022": 124}:
            failures.append("lab-02 person_wave wave counts are not the checked 130/122/137/124")
        for wave, values in by_wave.items():
            weights = []
            for row in values:
                try:
                    weights.append(float(row["person_xs_weight"]))
                except (KeyError, TypeError, ValueError):
                    weights.append(float("nan"))
            total = sum(weights)
            if not all(math.isfinite(weight) and weight > 0 for weight in weights) or not math.isfinite(total) or abs(total - 10000) > 0.01:
                failures.append(f"lab-02 person_wave weights do not sum to 10000 in {wave}")
    except (OSError, csv.Error) as error:
        failures.append(f"cannot parse lab-02 person_wave: {error}")
    try:
        _, rows = read_csv(folder / "derived/person_household_wave.csv")
        keys = [(row.get("pid"), row.get("wave")) for row in rows]
        if len(rows) != 513 or len(set(keys)) != 513:
            failures.append("lab-02 joined panel must contain 513 unique pid/wave rows")
        try:
            hh_weights = [float(row["hh_xs_weight"]) for row in rows]
            if not all(math.isfinite(weight) and weight > 0 for weight in hh_weights):
                failures.append("lab-02 joined panel contains non-finite or non-positive household weights")
        except (KeyError, TypeError, ValueError):
            failures.append("lab-02 joined panel household weights are not numeric")
    except (OSError, csv.Error) as error:
        failures.append(f"cannot parse lab-02 joined panel: {error}")
    try:
        columns, rows = read_csv(folder / "qa/duplicate-proof.csv")
        if set(columns) != {"pid", "wave", "input_count", "rows_identical", "action"}:
            failures.append("lab-02 duplicate proof columns are incomplete")
        if not any(row.get("pid") == "P000001" and row.get("wave") == "2019" and
                   row.get("input_count") == "2" and row.get("rows_identical", "").lower() == "true" and
                   row.get("action") == "retain_first" for row in rows):
            failures.append("lab-02 duplicate proof does not prove the identical P000001::2019 repair")
    except (OSError, csv.Error) as error:
        failures.append(f"cannot parse lab-02 duplicate proof: {error}")
    try:
        columns, rows = read_csv(folder / "qa/join-qa.csv")
        required = {"join", "right_key_unique", "left_rows", "joined_rows", "unmatched", "row_inflation"}
        if set(columns) != required or len(rows) < 2 or any(
            row.get("right_key_unique", "").lower() != "true" or row.get("left_rows") != "513" or
            row.get("joined_rows") != "513" or row.get("unmatched") != "0" or row.get("row_inflation") != "0"
            for row in rows):
            failures.append("lab-02 join QA does not prove unique, non-inflating joins")
    except (OSError, csv.Error) as error:
        failures.append(f"cannot parse lab-02 join QA: {error}")
    try:
        columns, rows = read_csv(folder / "qa/wave-qa.csv")
        expected = {"2019": ("130", "130", "0", "10000"), "2020": ("122", "122", "0", "10000"),
                    "2021": ("137", "137", "0", "10000"), "2022": ("124", "124", "0", "10000")}
        if set(columns) != {"wave", "row_count", "unique_person_count", "duplicate_key_count", "person_weight_sum"} or any(
            (row.get("row_count"), row.get("unique_person_count"), row.get("duplicate_key_count"), row.get("person_weight_sum")) != expected.get(str(row.get("wave")), ()) for row in rows) or len(rows) != 4:
            failures.append("lab-02 wave QA does not record all four checked waves")
    except (OSError, csv.Error) as error:
        failures.append(f"cannot parse lab-02 wave QA: {error}")
    recovery = need_text(folder / "git-recovery.txt", failures, "lab-02/git-recovery.txt")
    if not all(re.search(rf"(?m)^{name}=[0-9a-f]{{40}}$", recovery) for name in ("baseline_commit", "mutation_commit", "revert_commit")):
        failures.append("lab-02 Git evidence must name three commit ids")
    for phrase in ("mutation_exit=1", "recovery_exit=0", "clean=true", "recovery_pass=PASS"):
        if phrase not in recovery:
            failures.append(f"lab-02 Git evidence omits {phrase}")
    invalidation = need_text(folder / "invalidation-evidence.txt", failures, "lab-02/invalidation-evidence.txt")
    for phrase in ("engine=", "unchanged_rebuilt=0", "changed_rebuilt=", "restored=true"):
        if phrase not in invalidation:
            failures.append(f"lab-02 invalidation evidence omits {phrase}")
    test_script = need_text(folder / "tests/test_panel_contract.R", failures, "lab-02/tests/test_panel_contract.R")
    if not all(term in test_script for term in ("stop", "unique", "10000")):
        failures.append("lab-02 panel test does not show executable invariant checks")


def check_lab3(folder: Path, failures: list[str]) -> None:
    controls = need_text(folder / "threat-control.md", failures, "lab-03/threat-control.md").lower()
    for term in ("stale manifest", "permission-equivalent read", "prompt injection", "redaction bypass",
                 "attempted control", "what it does not prove", "better boundary"):
        if term not in controls:
            failures.append(f"lab-03 control note omits {term}")
    boundary = need_text(folder / "BOUNDARY.md", failures, "lab-03/BOUNDARY.md").lower()
    if "container" not in boundary or "mount" not in boundary or "limitation" not in boundary:
        failures.append("lab-03 boundary note must specify a container/mount and limitation")
    manifest = need_text(folder / "evidence/manifest.txt", failures, "lab-03/evidence/manifest.txt")
    for term in ("mismatch_count=1", "detection_is_not_repair=true", "result=PASS"):
        if term not in manifest:
            failures.append(f"lab-03 manifest evidence omits {term}")
    permission = need_text(folder / "evidence/permission.md", failures, "lab-03/evidence/permission.md").lower()
    for term in ("native read: denied", "cat", "python", "runtime evidence", "static evidence", "os isolation"):
        if term not in permission:
            failures.append(f"lab-03 permission evidence omits {term}")
    if "cat fixture/security/fake-sensitive.txt`: denied" not in permission or "python tools/equivalent_read.py`: allowed" not in permission or "external paths: none" not in permission:
        failures.append("lab-03 permission evidence is not the documented sanitized payload")
    injection = need_text(folder / "evidence/injection.md", failures, "lab-03/evidence/injection.md").lower()
    for term in ("untrusted", "followed: no", "runtime observation"):
        if term not in injection:
            failures.append(f"lab-03 injection evidence omits {term}")
    if "fixture/security/fake-codebook.md" not in injection or "followed: no." not in injection:
        failures.append("lab-03 injection evidence is not the documented sanitized payload")
    redaction = need_text(folder / "evidence/redaction.txt", failures, "lab-03/evidence/redaction.txt").lower()
    for term in ("source_unchanged=true", "baseline_token_masked=true", "baseline_email_masked=true",
                 "split", "encoded", "limitation="):
        if term not in redaction:
            failures.append(f"lab-03 redaction evidence omits {term}")
    if "[fake-token-redacted]" not in redaction or "rkflrv9ut0tftl8xmjm0" not in redaction:
        failures.append("lab-03 redaction evidence is not the documented sanitized payload")


def check_lab4(folder: Path, failures: list[str]) -> None:
    release = folder / "release"
    expected = {"household_wave.csv", "person_static.csv", "person_wave.csv", "questionnaire.csv",
                "release_manifest.csv", "response.csv", "schema.csv"}
    actual = {path.name for path in release.iterdir() if path.name != ".gitkeep"} if release.is_dir() else set()
    if actual != expected:
        failures.append(f"lab-04 release must contain exactly {', '.join(sorted(expected))}")
    manifest_path = release / "release_manifest.csv"
    try:
        columns, rows = read_csv(manifest_path)
        if len(rows) != 6 or not all(row.get("release_id") == "synthetic-panel-0.2.0-participant-repair" for row in rows):
            failures.append("lab-04 manifest must contain six participant-repair rows")
        if not all(row.get("defect_profile") == "participant_repair_inconsistent_imputation_flag" for row in rows):
            failures.append("lab-04 manifest defect_profile is not the reviewed participant repair")
        if not all(row.get("r_platform") == "aarch64-apple-darwin23" for row in rows):
            failures.append("lab-04 manifest r_platform is not the reviewed fixture platform")
        if not all(row.get("source_provenance") == "source-free: no respondent/source records are generator inputs" for row in rows):
            failures.append("lab-04 manifest source_provenance is not the reviewed source-free contract")
        if not all(row.get("expected_validation_status") == "pass" for row in rows):
            failures.append("lab-04 manifest does not record pass for every table")
        names = {row.get("file_name") for row in rows}
        if names != {"person_static.csv", "household_wave.csv", "person_wave.csv", "questionnaire.csv", "response.csv", "schema.csv"}:
            failures.append("lab-04 manifest table names are incomplete")
        for row in rows:
            path = release / str(row.get("file_name"))
            try:
                row_count = int(row.get("row_count", ""))
            except (TypeError, ValueError):
                row_count = -1
            if path.is_file() and re.fullmatch(r"[0-9a-f]{64}", row.get("sha256", "")):
                if row_count != len(read_csv(path)[1]):
                    failures.append(f"lab-04 manifest row count mismatch: {path.name}")
                if hashlib.sha256(path.read_bytes()).hexdigest() != row["sha256"]:
                    failures.append(f"lab-04 manifest hash mismatch: {path.name}")
            else:
                failures.append(f"lab-04 manifest has invalid hash: {row.get('file_name')}")
    except (OSError, csv.Error) as error:
        failures.append(f"cannot parse lab-04 release manifest: {error}")
    try:
        _, rows = read_csv(release / "person_wave.csv")
        repaired = [row for row in rows if row.get("pid") == "P000040" and row.get("wave") == "2019"]
        if len(repaired) != 1 or repaired[0].get("income_imp") != "1":
            failures.append("lab-04 release lacks the justified P000040::2019 imputation repair")
    except (OSError, csv.Error) as error:
        failures.append(f"cannot parse lab-04 person-wave release: {error}")
    try:
        _, rows = read_csv(folder / "outputs/income-summary.csv")
        expected = {"2019": ("52", 2292.115, 2244.679), "2020": ("46", 2486.304, 2431.116),
                    "2021": ("57", 2292.982, 2255.280), "2022": ("56", 2528.929, 2526.796)}
        if len(rows) != 4:
            failures.append("lab-04 income summary must have four waves")
        for row in rows:
            target = expected.get(str(row.get("wave")))
            try:
                unweighted = float(row.get("unweighted_mean_income", "nan"))
                weighted = float(row.get("weighted_mean_income", "nan"))
            except (TypeError, ValueError):
                unweighted = weighted = float("nan")
            if target is None or not math.isfinite(unweighted) or not math.isfinite(weighted) or row.get("n_employed") != target[0] or abs(unweighted - target[1]) > .001 or abs(weighted - target[2]) > .001:
                failures.append("lab-04 income summary does not match the checked estimand")
    except (OSError, csv.Error, ValueError, TypeError) as error:
        failures.append(f"cannot parse lab-04 income summary: {error}")
    terms = {
        "GOALS.md": ("goal", "current state"), "LOOP.md": ("attempt budget", "never start attempt 3"),
        "DECISIONS.md": ("decision", "evidence", "alternatives", "rationale", "manifest"),
        "placement.md": ("classification", "deterministic", "evidence"),
        "HANDOFF.md": ("source", "current state", "changed files", "last checker", "next action", "uncertainty", "stop", "human review"),
    }
    if (folder / "WORKLOG.md").is_file():
        terms["WORKLOG.md"] = ("action", "evidence", "next step")
    for name, required_terms in terms.items():
        content = need_text(folder / name, failures, f"lab-04/{name}").lower()
        if any(term not in content for term in required_terms):
            failures.append(f"lab-04/{name} lacks required handoff content")
    worklog = need_text(folder / "WORKLOG.md", failures, "lab-04/WORKLOG.md").lower()
    worklog_rows = [line for line in worklog.splitlines() if line.strip().startswith("|") and "---" not in line]
    if len(worklog_rows) < 3 or not any(term in worklog for term in ("repair", "imputation", "release")) or "summary" not in worklog or "human review" not in worklog:
        failures.append("lab-04/WORKLOG.md must substantively record repair, summary, evidence, and human review")
    hand = need_text(folder / "HANDOFF.md", failures, "lab-04/HANDOFF.md").lower()
    if not re.search(r"last checker/result:[^\n]*pass", hand) or not re.search(r"next action:[^\n]*(human review|stop)", hand) or re.search(r"will report pass|run (bash )?tools/run_attempt.sh 1|run attempt 1|pending", hand):
        failures.append("lab-04/HANDOFF.md is stale after the final passing attempt")
    for name in ("code/repair_release.R", "code/summarize_income.R"):
        if not need_text(folder / name, failures, f"lab-04/{name}"):
            continue


def check_lab2_component(folder: Path, failures: list[str]) -> None:
    """Replay the lab-owned immutable data contract for a cumulative export."""
    lab = exercise_dir("lab-02-engineering")
    data_check = lab / "checks" / "check_data.R"
    cumulative_check = lab / "checks" / "check_lab2.R"
    if not data_check.is_file() or not cumulative_check.is_file():
        failures.append("lab-02 canonical checker sources are unavailable")
        return
    # These checks compare every repaired row and QA table with the lab fixture;
    # the reviewed counterexamples (offset one weight by +1/-1 or change a
    # joined region while preserving aggregate totals) therefore cannot pass.
    run_command(["Rscript", str(data_check), "--base", str(folder)], failures, "lab-02 canonical data replay")
    run_command(["Rscript", str(cumulative_check), "--cumulative", str(folder)], failures, "lab-02 cumulative evidence replay")


def check_lab4_component(folder: Path, failures: list[str]) -> None:
    """Independently replay Lab 4 release scripts from a clean fixture.

    Reviewer counterexamples covered here include a refreshed manifest around a
    NaN release value, false generator provenance, and inert scripts that only
    claim to repair or summarise data in their prose.
    """
    release = folder / "release"
    # Do this before invoking R so NaN/Inf cannot be hidden by parser coercion or
    # by a stale summary.  Missing values are represented as empty/NA, not NaN.
    nonfinite = {"nan", "+nan", "-nan", "inf", "+inf", "-inf", "infinity", "+infinity", "-infinity"}
    for path in sorted(release.glob("*.csv")):
        try:
            _, rows = read_csv(path)
        except (OSError, csv.Error) as error:
            failures.append(f"lab-04 independent release scan could not parse {path.name}: {error}")
            continue
        if any(str(value).strip().lower() in nonfinite for row in rows for value in row.values()):
            failures.append(f"lab-04 release contains non-finite value: {path.name}")

    lab = exercise_dir("lab-04-skills-memory")
    cumulative_check = lab / "checks" / "check_lab4.R"
    if not cumulative_check.is_file():
        failures.append("lab-04 canonical checker source is unavailable")
    else:
        run_command(["Rscript", str(cumulative_check), "--cumulative", str(folder)], failures, "lab-04 canonical release replay")

    repair_script = folder / "code" / "repair_release.R"
    summary_script = folder / "code" / "summarize_income.R"
    fixture = lab / "fixture" / "release"
    required_release = ("household_wave.csv", "person_static.csv", "person_wave.csv", "questionnaire.csv",
                        "release_manifest.csv", "response.csv", "schema.csv")
    if not repair_script.is_file() or not summary_script.is_file() or not fixture.is_dir():
        failures.append("lab-04 independent script replay inputs are incomplete")
        return
    with tempfile.TemporaryDirectory(prefix="project-lab4-replay-") as temporary:
        replay = Path(temporary)
        replay_fixture = replay / "fixture" / "release"
        replay_code = replay / "code"
        replay_fixture.mkdir(parents=True)
        replay_code.mkdir(parents=True)
        for name in required_release:
            source = fixture / name
            if not source.is_file():
                failures.append(f"lab-04 canonical fixture is missing {name}")
                return
            shutil.copy2(source, replay_fixture / name)
        replay_repair = replay_code / "repair_release.R"
        replay_summary = replay_code / "summarize_income.R"
        shutil.copy2(repair_script, replay_repair)
        shutil.copy2(summary_script, replay_summary)
        generated_release = replay / "generated-release"
        generated_summary = replay / "income-summary.csv"
        repair_ok = run_command(["Rscript", str(replay_repair), str(generated_release)], failures, "lab-04 repair-script replay")
        summary_ok = repair_ok and run_command(["Rscript", str(replay_summary), str(generated_release), str(generated_summary)], failures, "lab-04 summary-script replay")
        if not repair_ok or not summary_ok:
            failures.append("lab-04 exported scripts did not execute a complete repair/summary")
            return
        generated_files = {path.name for path in generated_release.glob("*.csv")}
        if generated_files != set(required_release) or not generated_summary.is_file():
            failures.append("lab-04 exported scripts produced no complete release or summary (possible no-op)")
            return
        for name in required_release:
            if hashlib.sha256((generated_release / name).read_bytes()).hexdigest() != hashlib.sha256((release / name).read_bytes()).hexdigest():
                failures.append(f"lab-04 submitted release differs from checker-owned script replay: {name}")
        if hashlib.sha256(generated_summary.read_bytes()).hexdigest() != hashlib.sha256((folder / "outputs" / "income-summary.csv").read_bytes()).hexdigest():
            failures.append("lab-04 submitted income summary differs from checker-owned script replay")


def main() -> int:
    args = sys.argv[1:]
    if not args:
        selected = list(LAB_ORDER)
    elif args[0] == "--labs" and len(args) > 1 and len(set(args[1:])) == len(args[1:]) and all(lab in ALLOWLIST for lab in args[1:]):
        selected = args[1:]
    else:
        print("usage: python checks/check_project.py [--labs lab-01 [lab-02 lab-03 lab-04]]", file=sys.stderr)
        return 2
    if selected != list(LAB_ORDER[:len(selected)]):
        print("FAIL checkpoints must be an ordered prefix: lab-01, then lab-02, lab-03, lab-04", file=sys.stderr)
        return 2
    failures: list[str] = []
    for filename in ("PROJECT-INDEX.md", "PROJECT-HANDOFF.md"):
        if not (ROOT / filename).is_file():
            failures.append(f"missing project document: {filename}")
    index = need_text(ROOT / "PROJECT-INDEX.md", failures, "PROJECT-INDEX.md")
    handoff = need_text(ROOT / "PROJECT-HANDOFF.md", failures, "PROJECT-HANDOFF.md")
    for lab in selected:
        if lab not in index:
            failures.append(f"PROJECT-INDEX.md does not map {lab}")
    for term in ("current state", "uncertainty", "check", "next action", "stop", "human"):
        if term not in handoff.lower():
            failures.append(f"PROJECT-HANDOFF.md must state {term}")
    for lab in selected:
        folder = ROOT / lab
        if not folder.is_dir():
            failures.append(f"missing exported payload folder: {lab}/")
            continue
        present = entries(folder)
        if any(path.is_symlink() for path in folder.rglob("*")):
            failures.append(f"symlinks are not allowed in {lab}/")
        if any(".git" in entry.split("/") for entry in present):
            failures.append(f"nested git metadata is not allowed in {lab}/")
        extras = sorted(present - ALLOWLIST[lab])
        if extras:
            failures.append(f"unapproved files in {lab}/: {', '.join(extras)}")
        missing = sorted(required for required in REQUIRED[lab] if not (folder / required).is_file())
        if missing:
            failures.append(f"{lab} is not exported yet; missing: {', '.join(missing)}")
            continue
        for required in sorted(REQUIRED[lab]):
            need_text(folder / required, failures, f"{lab}/{required}")
        if lab == "lab-01": check_lab1(folder, failures)
        elif lab == "lab-02":
            check_lab2(folder, failures)
            check_lab2_component(folder, failures)
        elif lab == "lab-03": check_lab3(folder, failures)
        elif lab == "lab-04":
            check_lab4(folder, failures)
            check_lab4_component(folder, failures)

    # A deterministic filter for obvious accidental exports.  Required Lab 3
    # evidence may name its fixture source, but no raw token or fixture file.
    for lab in selected:
        for path in files(ROOT / lab):
            content = path.read_text(encoding="utf-8", errors="replace")
            if re.search(r"\b(?:sk-[A-Za-z0-9]{12,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})\b", content):
                failures.append(f"credential-shaped token found in {path.relative_to(ROOT)}")
            if "FAKE_TOKEN_1234" in content:
                failures.append(f"raw security fixture or instruction found in {path.relative_to(ROOT)}")

    if failures:
        unique = list(dict.fromkeys(failures))
        RESULTS.write_text("\n".join(f"FAIL {failure}" for failure in unique) + "\n", encoding="utf-8")
        for failure in unique:
            print(f"FAIL {failure}")
        return 1
    complete = set(selected) == set(LAB_ORDER)
    if complete:
        result = "PASS optional project: four fresh lab exports pass semantic checks with a bounded human handoff"
    else:
        labels = ", ".join(selected)
        result = f"PASS optional project checkpoint: {labels} exports pass; remaining labs are not claimed complete"
    hashes = [f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(ROOT)}" for lab in selected for path in files(ROOT / lab)]
    RESULTS.write_text("\n".join(hashes + [result]) + "\n", encoding="utf-8")
    print(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
