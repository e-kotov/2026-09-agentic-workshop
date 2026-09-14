#!/usr/bin/env python3
"""Check the intentionally stale release manifest without changing the release."""

from __future__ import annotations

import argparse
import csv
import hashlib
from pathlib import Path


LAB = Path(__file__).resolve().parents[1]
RELEASE = LAB / "fixture" / "release"
EXPECTED_CLEAN = {
    "person_static.csv": "518f9220146b5e6afddd80cbdd61f57b3522a6f06e54533cc3c0e77cb581596b",
    "household_wave.csv": "3c5eec09c11c4f13391f2366366938082e3b31bd6f473296cdce64a292a5243a",
    "person_wave.csv": "f907c45c0dc2add565565187910f66c6d54e387eae34009811ffd90b088600d3",
    "questionnaire.csv": "48bf1693afa4eeb11c0053fe275a95c022434d9006d98b3cbd97e098a067c8e4",
    "response.csv": "67e45b4388808e0b014c84d55a30eb042f23180c131ad765146d56c5da8408af",
    "schema.csv": "7cc4c3cf407494ce80806b71ebcc7e6669fb978d187fedc5590befd5965dd393",
}
EXPECTED_FIELDS = (
    "release_id", "defect_profile", "generator_version", "seed", "generated_utc",
    "r_version", "r_platform", "fabricatr_version", "simstudy_version",
    "data_table_version", "digest_version", "renv_version", "lockfile_sha256",
    "generator_sha256", "generator_inputs_sha256", "source_provenance", "table_name",
    "file_name", "row_count", "sha256", "expected_validation_status", "target_total",
    "target_unit",
)
EXPECTED_GENERATOR_SHA256 = "c5edbaa5b0161951d6f5d02517d9161a68885dbf8d1f849458ff0f9fd519c702"
EXPECTED_GENERATOR_INPUTS_SHA256 = "ba29e37645dfd63cc39813c0e597197d389aed235dd0ff8a7af873a4bef7c055"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", "--cumulative", dest="base", default=str(LAB / "work"))
    args = parser.parse_args()
    evidence = Path(args.base).expanduser().resolve() / "evidence" / "manifest.txt"
    evidence.parent.mkdir(parents=True, exist_ok=True)

    lines = [
        "integrity_scope=fixture/release (immutable; no repair performed)",
        "evidence_type=deterministic integrity check",
    ]
    errors: list[str] = []
    manifest_reader = None
    try:
        with (RELEASE / "release_manifest.csv").open(newline="") as handle:
            manifest_reader = csv.DictReader(handle)
            rows = list(manifest_reader)
    except (OSError, csv.Error) as exc:
        rows = []
        errors.append(f"manifest_read_error={exc}")

    declared: dict[str, str] = {}
    for row in rows:
        filename = row.get("file_name", "")
        if filename in declared:
            errors.append(f"duplicate_manifest_file={filename}")
        declared[filename] = row.get("sha256", "")

    mismatches: list[tuple[str, str, str]] = []
    for filename in sorted(EXPECTED_CLEAN):
        path = RELEASE / filename
        actual = sha256(path) if path.is_file() else "MISSING"
        expected = declared.get(filename, "MISSING")
        if actual != expected:
            mismatches.append((filename, expected, actual))
        if actual != EXPECTED_CLEAN[filename]:
            errors.append(f"analytical_bytes_changed={filename}")

    if len(rows) != len(EXPECTED_CLEAN) or set(declared) != set(EXPECTED_CLEAN):
        errors.append("manifest_file_set_is_not_exactly_six_tables")
    if rows and any(row.get("defect_profile") != "stale_manifest_checksum" for row in rows):
        errors.append("manifest_profile_is_not_stale_manifest_checksum")
    manifest_fields = tuple(manifest_reader.fieldnames or ()) if manifest_reader is not None else ()
    if manifest_fields != EXPECTED_FIELDS:
        errors.append("manifest_schema_is_not_current_canonical_schema")
    if rows and any(row.get("generator_sha256") != EXPECTED_GENERATOR_SHA256 for row in rows):
        errors.append("manifest_generator_sha256_is_not_current")
    if rows and any(row.get("generator_inputs_sha256") != EXPECTED_GENERATOR_INPUTS_SHA256 for row in rows):
        errors.append("manifest_generator_inputs_sha256_is_not_current")
    if rows and any(row.get("source_provenance") != "source-free: no respondent/source records are generator inputs" for row in rows):
        errors.append("manifest_source_provenance_is_not_current")
    if rows and any(row.get("expected_validation_status") != "expected_failure:manifest_checksums" for row in rows):
        errors.append("manifest_expected_status_is_not_exact")

    if mismatches:
        for filename, expected, actual in mismatches:
            lines.append(f"mismatch file={filename} expected={expected} actual={actual}")
    lines.append(f"mismatch_count={len(mismatches)}")
    analytical_equal = not any(x.startswith("analytical_bytes_changed=") for x in errors)
    lines.append(f"analytical_files_equal_clean={str(analytical_equal).lower()}")
    lines.append(f"manifest_schema=current canonical ({len(EXPECTED_FIELDS)} fields)")
    lines.append(f"manifest_generator_sha256={EXPECTED_GENERATOR_SHA256 if not any(x.startswith('manifest_generator_sha256') for x in errors) else 'mismatch'}")
    lines.append(f"manifest_generator_inputs_sha256={EXPECTED_GENERATOR_INPUTS_SHA256 if not any(x.startswith('manifest_generator_inputs_sha256') for x in errors) else 'mismatch'}")
    intended = (
        len(mismatches) == 1
        and mismatches[0][0] == "person_wave.csv"
        and mismatches[0][1] == "0" * 64
        and mismatches[0][2] == EXPECTED_CLEAN["person_wave.csv"]
        and not any(x.startswith("analytical_bytes_changed=") for x in errors)
        and not errors
    )
    lines.append(f"detection_is_not_repair={str(intended).lower()}")
    if intended:
        lines.append("result=PASS intended stale person_wave checksum detected; detection is not repairing it")
    else:
        lines.append("result=FAIL fixture does not contain exactly the intended stale checksum")
        lines.extend(f"error={error}" for error in errors)
    evidence.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    return 0 if intended else 1


if __name__ == "__main__":
    raise SystemExit(main())
