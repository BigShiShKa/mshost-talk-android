"""SPDX-FileCopyrightText: 2026 MSHost contributors
SPDX-License-Identifier: GPL-3.0-or-later
"""
from pathlib import Path
import re
import sys
from zipfile import ZipFile

apk = Path(sys.argv[1])
with ZipFile(apk) as archive:
    dex_files = [name for name in archive.namelist() if re.fullmatch(r"classes\d*\.dex", name)]
    if not dex_files:
        raise SystemExit("No application bytecode found")
    for name in dex_files:
        if b"Build flavor: " in archive.read(name):
            raise SystemExit(f"Startup flavor toast is still present in {name}")
print("APK contains no startup build-flavor toast")
