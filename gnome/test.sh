#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
set -eu
task_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$task_dir"
python3 -m unittest discover -s tests -v
node --check extension/extension.js
node --check extension/prefs.js
node --experimental-vm-modules --test tests/*.test.js
python3 package.py
python3 - <<'PY'
import json,zipfile
from pathlib import Path
p=Path('dist/ai-limitshower@mermalat.shell-extension.zip')
with zipfile.ZipFile(p) as z:
    names=z.namelist()
    assert 'metadata.json' in names and 'schemas/gschemas.compiled' in names
    assert 'backend.py' in names and 'LICENSE' in names
    assert not any('.credentials' in x or 'sessions/' in x or '__pycache__' in x for x in names)
    assert json.loads(z.read('metadata.json'))['uuid']=='ai-limitshower@mermalat'
print('ZIP contents verified.')
PY
