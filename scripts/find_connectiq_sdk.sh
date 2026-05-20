#!/usr/bin/env bash
set -euo pipefail

SDK_BASE_DIR="${1:-${CIQ_SDK_BASE_DIR:-$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks}}"

if [[ ! -d "$SDK_BASE_DIR" ]]; then
  exit 0
fi

python3 - "$SDK_BASE_DIR" <<'PY'
from pathlib import Path
import re
import sys

base_dir = Path(sys.argv[1])
version_pattern = re.compile(r"^connectiq-sdk-mac-(\d+(?:\.\d+)*)")

candidates = []
for path in base_dir.iterdir():
    if not path.is_dir():
        continue
    match = version_pattern.match(path.name)
    if not match:
        continue
    version = tuple(int(part) for part in match.group(1).split("."))
    candidates.append((version, path.name, path))

if not candidates:
    raise SystemExit(0)

candidates.sort(key=lambda item: (item[0], item[1]))
print(candidates[-1][2])
PY
