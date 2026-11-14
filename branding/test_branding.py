"""SPDX-FileCopyrightText: 2026 MSHost contributors
SPDX-License-Identifier: GPL-3.0-or-later
"""
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID = "{http://schemas.android.com/apk/res/android}"


class BrandingContractTest(unittest.TestCase):
    def test_accounts_and_contacts_are_isolated(self):
        build = (ROOT / "app/build.gradle.kts").read_text(encoding="utf-8")
        generic = re.search(r'create\("generic"\)\s*\{(.*?)\n\s*}', build, re.S).group(1)
        app_id = re.search(r'applicationId = "([^"]+)"', generic).group(1)
        self.assertNotIn(app_id, ["com.nextcloud.talk2", "io.github.bigshishka.mshostcloud"])
        for name in ["auth.xml", "syncadapter.xml"]:
            element = ET.parse(ROOT / "app/src/main/res/xml" / name).getroot()
            self.assertEqual(element.attrib[ANDROID + "accountType"], app_id)
        contacts = ET.parse(ROOT / "app/src/main/res/xml/contacts.xml").getroot()
        mime = contacts.find("ContactsDataKind").attrib[ANDROID + "mimeType"]
        self.assertEqual(mime, f"vnd.android.cursor.item/vnd.{app_id}.chat")
        manifest = ET.parse(ROOT / "app/src/main/AndroidManifest.xml").getroot()
        self.assertTrue(any(item.attrib.get(ANDROID + "mimeType") == mime for item in manifest.iter("data")))
        for name in ["activities/MainActivity.kt", "jobs/ContactAddressBookWorker.kt"]:
            source = (ROOT / "app/src/main/java/com/nextcloud/talk" / name).read_text(encoding="utf-8")
            self.assertIn(f'"{mime}"', source)
            self.assertNotIn("vnd.com.nextcloud.talk2.chat", source)

    def test_login_branding_and_service_choices(self):
        resources = ET.parse(ROOT / "app/src/generic/res/values/mshost.xml").getroot()
        values = {item.attrib["name"]: item.text or "" for item in resources}
        self.assertEqual(values["nc_app_name"], "MSHost Talk")
        self.assertEqual(values["nc_app_product_name"], "MSHost Talk")
        self.assertEqual(values["weblogin_url"], "https://cloud.mshostcloud.org")
        self.assertEqual(values["hide_provider"], "true")
        self.assertEqual(values["nc_import_account_type"], "")
        self.assertEqual(values["nc_import_accounts_from"], "")
        for density in ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]:
            self.assertTrue((ROOT / f"app/src/generic/res/mipmap-{density}/ic_launcher.png").is_file())


if __name__ == "__main__":
    unittest.main()
