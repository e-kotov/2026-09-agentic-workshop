import csv

with open(snakemake.input[0], newline="") as handle:
    rows = list(csv.DictReader(handle))
seen = set()
rows = [row for row in rows if (row["pid"], row["wave"]) not in seen and not seen.add((row["pid"], row["wave"]))]
with open(snakemake.output[0], "w", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)
