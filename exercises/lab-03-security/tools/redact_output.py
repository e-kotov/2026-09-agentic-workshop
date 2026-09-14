import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text() if len(sys.argv) > 1 else sys.stdin.read()
text = re.sub(r"(?i)(token=)[^\s]+", r"\1[REDACTED]", text)
text = re.sub(r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}", "[EMAIL-REDACTED]", text)
print(text, end="")
