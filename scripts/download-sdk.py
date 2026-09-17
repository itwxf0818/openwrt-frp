#!/usr/bin/env python3
"""Download an official snapshot SDK, checking the HTTPS SHA256 manifest."""
import argparse
import json
from pathlib import Path
import re
from upstream import fetch

p = argparse.ArgumentParser()
p.add_argument("distribution", choices=["openwrt", "immortalwrt"])
p.add_argument("target", choices=["x86/64", "mediatek/filogic"])
p.add_argument("output", type=Path)
a = p.parse_args()
base = f"https://downloads.{a.distribution}.org/snapshots/targets/{a.target}"
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
