#!/usr/bin/env python3
"""Download the exact package source and verify its recorded SHA256."""
import hashlib
from pathlib import Path
import sys
import tarfile
from upstream import ROOT, fetch, metadata, source_url

m = metadata()
version = m["PKG_VERSION"]
archive = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "work" / f"frp-{version}.tar.gz"
if not archive.exists():
    fetch(source_url(version), archive)
with archive.open("rb") as f:
    digest = hashlib.file_digest(f, "sha256").hexdigest()
if digest != m["PKG_HASH"]:
    raise SystemExit(f"Source hash mismatch: {digest}")
target = ROOT / "work" / "source"
target.mkdir(parents=True, exist_ok=True)
if any(target.iterdir()):
    raise SystemExit(f"Use an empty source directory: {target}")
with tarfile.open(archive, "r:gz") as tar:
    for entry in tar:
        parts = Path(entry.name).parts
        if not parts or parts[0] != f"frp-{version}" or ".." in parts:
            raise SystemExit("Unexpected archive path")
        # No symlink/device extraction; FRP compilation needs regular files only.
        if not entry.isfile() or len(parts) < 2:
            continue
        path = target.joinpath(*parts[1:])
        path.parent.mkdir(parents=True, exist_ok=True)
        with tar.extractfile(entry) as src, path.open("wb") as dst:
            import shutil
            shutil.copyfileobj(src, dst)
print(f"Verified FRP {version}: {digest}")
print((target / "go.mod").read_text().splitlines()[2])
