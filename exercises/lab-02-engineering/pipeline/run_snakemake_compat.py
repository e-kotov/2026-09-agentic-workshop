#!/usr/bin/env python3
"""Small timestamp/dependency runner used when Snakemake is unavailable."""
import csv
import os
import sys

source, person_out, qa_out = sys.argv[1:4]
needs_person = not os.path.exists(person_out) or os.path.getmtime(person_out) < os.path.getmtime(source)
needs_qa = not os.path.exists(qa_out) or needs_person or os.path.getmtime(qa_out) < os.path.getmtime(person_out)
if needs_person:
    with open(source, newline="") as handle:
        rows = list(csv.DictReader(handle))
    seen = set()
    rows = [row for row in rows if (row["pid"], row["wave"]) not in seen and not seen.add((row["pid"], row["wave"]))]
    with open(person_out, "w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    print("rebuild person_wave")
if needs_qa:
    with open(person_out, newline="") as handle:
        rows = list(csv.DictReader(handle))
    with open(qa_out, "w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["wave", "row_count", "person_weight_sum"])
        writer.writeheader()
        for wave in ("2019", "2020", "2021", "2022"):
            subset = [row for row in rows if row["wave"] == wave]
            writer.writerow({"wave": wave, "row_count": len(subset), "person_weight_sum": sum(float(row["person_xs_weight"]) for row in subset)})
        print("rebuild wave_qa")
if not needs_person and not needs_qa:
    print("skip: dependencies unchanged")
