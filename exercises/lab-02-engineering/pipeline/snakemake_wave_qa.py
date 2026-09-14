import csv

with open(snakemake.input[0], newline="") as handle:
    rows = list(csv.DictReader(handle))
with open(snakemake.output[0], "w", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=["wave", "row_count", "person_weight_sum"])
    writer.writeheader()
    for wave in ("2019", "2020", "2021", "2022"):
        subset = [row for row in rows if row["wave"] == wave]
        writer.writerow({"wave": wave, "row_count": len(subset), "person_weight_sum": sum(float(row["person_xs_weight"]) for row in subset)})
