#!/usr/bin/env python3
"""Download an official SDK, checking the HTTPS SHA256 manifest."""
import argparse
import json
from pathlib import Path
import re
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
manifest = fetch(base + "/sha256sums").decode()
matches = re.findall(rf"^([a-f0-9]{{64}})\s+\*?({a.distribution}-sdk-[^/\s]+\.tar\.(?:zst|xz))$", manifest, re.M)
if len(matches) != 1:
    raise SystemExit("Expected exactly one SDK in the official manifest")
expected, name = matches[0]
a.output.mkdir(parents=True, exist_ok=True)
actual = fetch(base + "/" + name, a.output / name)
if actual != expected:
    raise SystemExit("SDK hash mismatch; snapshot may have rotated. Rerun the workflow.")
(a.output / "sdk-provenance.json").write_text(json.dumps({"url": base + "/" + name, "sha256": actual}, indent=2) + "\n")
(a.output / "sha256sums").write_text(manifest)
print(a.output / name)
