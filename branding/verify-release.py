"""SPDX-FileCopyrightText: 2026 MSHost contributors
SPDX-License-Identifier: GPL-3.0-or-later
"""
import argparse
from pathlib import Path
import re
from zipfile import ZipFile

parser = argparse.ArgumentParser()
parser.add_argument("apk", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
config = root / "app/build/generated/source/buildConfig/generic/release/com/nextcloud/talk/BuildConfig.java"
assert re.search(r"boolean DEBUG\s*=\s*false", config.read_text(encoding="utf-8")), "BuildConfig.DEBUG must be false"
forbidden = (
    b"Landroidx/compose/ui/tooling/ComposeViewAdapter;",
    b"Landroidx/test/core/app/InstrumentationActivityInvoker;",
    b"Landroidx/room/testing/MigrationTestHelper;",
    b"Build flavor: ",
)
with ZipFile(args.apk) as archive:
    for name in archive.namelist():
        if re.fullmatch(r"classes\d*\.dex", name):
            data = archive.read(name)
            for marker in forbidden:
                assert marker not in data, f"Unexpected debug feature in {name}: {marker!r}"
print("Release checks passed: DEBUG=false, no Compose inspector/test activity or startup flavor toast")
