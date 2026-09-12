from pathlib import Path

# This helper is intentionally equivalent to a shell read, for teaching only.
print(Path(__file__).parents[1].joinpath("fixture", "fake-sensitive.txt").read_text())
