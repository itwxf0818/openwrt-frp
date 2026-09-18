import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
spec = importlib.util.spec_from_file_location("release_assets", Path(__file__).resolve().parents[1] / "scripts/release-assets.py")
assets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assets)


class ReleaseAssets(unittest.TestCase):
    def fixture(self, root):
        identity = assets.identity()
        directories = []
        for target, arch in assets.TARGETS.items():
            directory = root / target.replace("/", "-")
            directory.mkdir(parents=True)
            (directory / "sdk.config").write_text(f'CONFIG_TARGET_ARCH_PACKAGES="{arch}"\n')
            for name in ("sdk-provenance.json", "feed-commits.txt", "feeds.conf.used"):
                (directory / name).write_text("fixture\n")
            for name in ("frpc", "frps"):
                (directory / f"{name}-{identity['version']}-r{identity['revision']}.apk").write_bytes(b"test-package" + arch.encode())
            assets.record(directory, "immortalwrt", target, assets.CHANNEL)
            directories.append(directory)
        return directories

    def test_complete_release_and_checksums(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.fixture(root / "inputs")
            output = root / "output"
            assets.prepare(root / "inputs", output)
            self.assertEqual(len(list(output.glob("*.apk"))), 8)
            for line in (output / "SHA256SUMS").read_text().splitlines():
                checksum, name = line.split("  ")
                self.assertEqual(assets.digest(output / name), checksum)

    def test_reject_incomplete_wrong_version_and_tampering(self):
        for failure in ("missing", "version", "tampering", "architecture"):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                directories = self.fixture(root / "inputs")
                path = directories[0] / "build-metadata.json"
                if failure == "missing":
                    path.unlink()
                elif failure == "tampering":
                    next(directories[0].glob("*.apk")).write_bytes(b"changed")
                else:
                    data = json.loads(path.read_text())
                    data["version" if failure == "version" else "architecture"] = "incorrect"
                    path.write_text(json.dumps(data))
                with self.assertRaises(ValueError):
                    assets.prepare(root / "inputs", root / "output")
