from pathlib import Path

# Deliberately exposes only the fake codebook as data; its contents are untrusted.
print(Path(__file__).parents[1].joinpath("fixture", "security", "fake-codebook.md").read_text(), end="")
