"""SPDX-FileCopyrightText: 2026 MSHost contributors
SPDX-License-Identifier: GPL-3.0-or-later
"""
import hashlib
import json
from pathlib import Path
import shutil
from source_archive import validated_sources
from zipfile import ZIP_DEFLATED, ZipFile

root = Path(__file__).resolve().parents[1]
apk_dir = root / "app/build/outputs/apk/generic/release"
metadata = json.loads((apk_dir / "output-metadata.json").read_text(encoding="utf-8"))
assert metadata["applicationId"] == "org.mshostcloud.talk", metadata
element = metadata["elements"][0]
version = element["versionName"]
assert version == "25.1.0", version
files = validated_sources(root)
output = root.parents[1] / "Builds/TalkAndroid/dist" / version
output.mkdir(parents=True, exist_ok=True)
apk = output / f"MSHost-Talk-Android-{version}-generic-release.apk"
shutil.copy2(apk_dir / element["outputFile"].replace("-unsigned.apk", ".apk"), apk)
with ZipFile(output / f"MSHost-Talk-Android-{version}-source.zip", "w", ZIP_DEFLATED, compresslevel=6) as archive:
    for name in sorted(set(files) - {""}):
        if (root / name).is_file():
            archive.write(root / name, Path("MSHost-Talk-Android-source") / name)
(output / "README.txt").write_text(
    f"MSHost Talk Android {version}\n\n"
    "Логотип Talk: белая монограмма MT в градиентном облаке.\n"
    "Android 8.0 и новее. Пакет org.mshostcloud.talk.\n"
    "Установите APK и войдите своим аккаунтом cloud.mshostcloud.org.\n"
    "Сборка generic/release без отладки; отдельный ключ с цепочкой ротации alpha.\n"
    "Обновляйте поверх предыдущего MSHost Talk, не удаляя приложение и аккаунты.\n"
    "Для уведомлений разрешите Web Push на сервере; при Google Play services доступен встроенный distributor.\n"
    "Инструкция находится в исходниках: docs/mshost/README.md.\n"
    "Лицензия GPL-3.0-or-later; исходники приложены.\n",
    encoding="utf-8",
)
report = {
    "product": "MSHost Talk Android", "applicationId": metadata["applicationId"],
    "versionName": version, "versionCode": element["versionCode"], "flavor": "genericRelease", "debuggable": False,
    "signing": "Dedicated release key; v3 rotation from alpha certificate on Android 9+, legacy v2 for Android 8",
    "upstream": "nextcloud/talk-android 25.1.0", "notifications": "Web Push via embedded distributor with Google Play services, or external UnifiedPush",
    "logo": "MT monogram in gradient cloud", "startupFlavorToast": False,
}
(output / "build-result.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
checksums = []
for file in sorted(output.iterdir()):
    if file.is_file() and file.name != "SHA256SUMS.txt":
        with file.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        checksums.append(f"{digest}  {file.name}")
(output / "SHA256SUMS.txt").write_text("\n".join(checksums) + "\n", encoding="utf-8")
print(output)
print("\n".join(checksums))
