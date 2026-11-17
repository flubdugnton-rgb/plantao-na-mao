#!/bin/bash
set -euo pipefail
SELECTED_XCODE=$(python3 - <<'PY'
from pathlib import Path
import re
paths = [p for p in Path('/Applications').glob('Xcode_26*.app') if 'beta' not in p.name.lower()]
if not paths:
    raise SystemExit('Xcode 26 ou superior da série 26 é necessário para compilar o Liquid Glass nativo.')
print(max(paths, key=lambda p: tuple(map(int, re.findall(r'\d+', p.name)))) / 'Contents/Developer')
PY
)
echo "DEVELOPER_DIR=$SELECTED_XCODE" >> "$GITHUB_ENV"
DEVELOPER_DIR="$SELECTED_XCODE" xcodebuild -version
