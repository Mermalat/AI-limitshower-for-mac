#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build a GNOME extension ZIP; never includes local accounts or usage history."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parent
source = root/'extension'
metadata = json.loads((source/'metadata.json').read_text())
destination = root/'dist'
destination.mkdir(exist_ok=True)
compiler = shutil.which('glib-compile-schemas')
if not compiler:
    raise SystemExit('Install glib-compile-schemas (glib2 on Fedora, libglib2.0-bin on Ubuntu).')
archive = destination/(metadata['uuid']+'.shell-extension.zip')
with tempfile.TemporaryDirectory(prefix='ai-limits-package-') as temp:
    stage = Path(temp)/'extension'
    shutil.copytree(source, stage, ignore=shutil.ignore_patterns('__pycache__', '*.pyc', 'gschemas.compiled'))
    subprocess.run([compiler, '--strict', str(stage/'schemas')], check=True)
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as output:
        for file in sorted(stage.rglob('*')):
            if file.is_file():
                output.write(file, file.relative_to(stage))
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
(destination/'SHA256SUMS.txt').write_text(f'{checksum}  {archive.name}\n')
print(archive)
