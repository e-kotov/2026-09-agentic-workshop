from pathlib import Path

# Intentionally equivalent to a shell read, for teaching only.
print(Path(__file__).parents[1].joinpath("fixture", "security", "fake-sensitive.txt").read_text(), end="")
