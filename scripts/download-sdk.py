#!/usr/bin/env python3
"""Download an official SDK, checking the HTTPS SHA256 manifest."""
import argparse
import json
from pathlib import Path
import re
from tempfile import TemporaryDirectory
import time
from upstream import fetch

p = argparse.ArgumentParser()
p.add_argument("distribution", choices=["openwrt", "immortalwrt"])
p.add_argument("target", choices=["x86/64", "mediatek/filogic", "ipq40xx/generic", "ramips/mt7621"])
p.add_argument("output", type=Path)
p.add_argument("--release", default="snapshot")
a = p.parse_args()
if a.release != "snapshot" and not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", a.release):
    p.error("release must be snapshot or a stable version such as 25.12.2")
channel = "snapshots" if a.release == "snapshot" else f"releases/{a.release}"
base = f"https://downloads.{a.distribution}.org/{channel}/targets/{a.target}"
a.output.mkdir(parents=True, exist_ok=True)
attempts = 3 if a.release == "snapshot" else 1
with TemporaryDirectory(dir=a.output) as temporary:
    for attempt in range(1, attempts + 1):
        manifest_url = base + "/sha256sums"
        if attempt > 1:
            manifest_url += f"?refresh={time.time_ns()}"
        manifest = fetch(manifest_url).decode()
        matches = re.findall(rf"^([a-f0-9]{{64}})\s+\*?({a.distribution}-sdk-[^/\s]+\.tar\.(?:zst|xz))$", manifest, re.M)
        if len(matches) != 1:
            raise SystemExit("Expected exactly one SDK in the official manifest")
        expected, name = matches[0]
        url = base + "/" + name
        print(f"Downloading SDK (attempt {attempt}/{attempts}): {url}", flush=True)
        candidate = Path(temporary) / name
        # Snapshot filenames are reused. On retry, key the archive request to
        # the refreshed manifest digest so an old cache entry can be bypassed.
        download_url = f"{url}?sha256={expected}&refresh={time.time_ns()}" if attempt > 1 else url
        actual = fetch(download_url, candidate)
        if actual == expected:
            candidate.replace(a.output / name)
            break
        print(f"SDK SHA256 mismatch: expected {expected}, received {actual}", flush=True)
        candidate.unlink()
        if attempt == attempts:
            raise SystemExit("SDK hash mismatch after verification; refusing to use the archive.")
        print("Snapshot SDK hash mismatch; refreshing the official manifest before retrying.", flush=True)
        time.sleep(5)
(a.output / "sdk-provenance.json").write_text(json.dumps({"url": url, "sha256": actual}, indent=2) + "\n")
(a.output / "sha256sums").write_text(manifest)
print(a.output / name)
