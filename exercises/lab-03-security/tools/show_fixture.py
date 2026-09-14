from pathlib import Path

print(Path(__file__).parents[1].joinpath("fixture", "security", "fake-sensitive.txt").read_text(), end="")
