import sys
from pathlib import Path
import unittest
from unittest.mock import patch
import tempfile
import json
import io
import tarfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import upstream


class Updates(unittest.TestCase):
    def test_readme_version_follows_package_and_rejects_missing_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            readme = root / "README.md"
            original = "# FRP\n\n<!-- frp-version --> old version\n\nKeep these instructions.\n"
            readme.write_text(original, encoding="utf-8")
            with patch.object(upstream, "ROOT", root), patch.object(upstream, "metadata", return_value={"PKG_VERSION": "0.72.0", "PKG_RELEASE": "1"}):
                upstream.sync_readme()
                updated = readme.read_text(encoding="utf-8")
                self.assertIn("**FRP 0.72.0**", updated)
                self.assertIn("**0.72.0-r1**", updated)
                self.assertTrue(updated.endswith("\n\nKeep these instructions.\n"))
                for invalid in ("# No marker\n", "<!-- frp-version --> a\n<!-- frp-version --> b\n"):
                    readme.write_text(invalid, encoding="utf-8")
                    with self.assertRaises(ValueError):
                        upstream.sync_readme()
                    self.assertEqual(readme.read_text(encoding="utf-8"), invalid)

    def test_reject_unstable_and_injection(self):
        for tag in ["v0.72.0-rc1", "v0.72.0;echo bad", "0.72.0", "vmain"]:
            with self.assertRaises(ValueError):
                upstream.stable_release({"tag_name": tag})
        for flag in ["draft", "prerelease"]:
            with self.assertRaises(ValueError):
                upstream.stable_release({"tag_name": "v0.72.0", flag: True})

    def test_numeric_order(self):
        self.assertGreater(upstream.version_tuple("0.100.0"), upstream.version_tuple("0.99.9"))

    def test_rewrite_only_metadata(self):
        text = "PKG_VERSION:=0.71.0\nPKG_HASH:=" + "a" * 64 + "\nPKG_RELEASE:=9\nkeep:=yes\n"
        result = upstream.replace_metadata(text, "0.72.0", "b" * 64)
        self.assertEqual(upstream.metadata(result)["PKG_RELEASE"], "1")
        self.assertIn("keep:=yes\n", result)

    def test_no_downgrade_or_same_version_rehash(self):
        for version in ["0.70.0", "0.71.0"]:
            with patch.object(upstream, "metadata", return_value={"PKG_VERSION": "0.71.0"}), patch.object(upstream, "fetch", return_value=json.dumps({"tag_name": "v" + version}).encode()) as fetch:
                upstream.check_update()
                self.assertEqual(fetch.call_count, 1)

    def test_update_and_download_failure_are_atomic(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            makefile = root / "Makefile"
            original = "PKG_VERSION:=0.71.0\nPKG_HASH:=" + "a" * 64 + "\nPKG_RELEASE:=4\n"
            makefile.write_text(original)
            def download(url, destination=None):
                if destination is None:
                    return b'{"tag_name":"v0.72.0"}'
                destination.parent.mkdir(parents=True, exist_ok=True)
                with tarfile.open(destination, "w:gz") as tar:
                    data = b"module github.com/fatedier/frp\n\ngo 1.25.0\n"
                    entry = tarfile.TarInfo("frp-0.72.0/go.mod")
                    entry.size = len(data)
                    tar.addfile(entry, io.BytesIO(data))
                return "b" * 64
            with patch.object(upstream, "ROOT", root), patch.object(upstream, "MAKEFILE", makefile), patch.object(upstream, "fetch", side_effect=download):
                upstream.check_update()
                self.assertEqual(upstream.metadata()["PKG_VERSION"], "0.72.0")
                makefile.write_text(original)
                with patch.object(upstream, "fetch", side_effect=[b'{"tag_name":"v0.72.0"}', OSError("offline")]):
                    with self.assertRaises(OSError):
                        upstream.check_update()
                self.assertEqual(makefile.read_text(), original)


if __name__ == "__main__":
    unittest.main()
