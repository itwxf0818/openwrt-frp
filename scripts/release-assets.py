#!/usr/bin/env python3
"""Record SDK package identity and prepare a complete, checksummed release."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile
from upstream import metadata

TARGETS = {
    "x86/64": "x86_64",
    "mediatek/filogic": "aarch64_cortex-a53",
    "ipq40xx/generic": "arm_cortex-a7_neon-vfpv4",
    "ramips/mt7621": "mipsel_24kc",
}
CHANNEL = "25.12.2"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def identity():
    data = metadata()
    return {"version": data["PKG_VERSION"], "revision": data["PKG_RELEASE"],
            "source_hash": data["PKG_HASH"]}


def record(directory, distribution, target, channel):
    config = (directory / "sdk.config").read_text(encoding="utf-8")
    match = re.search(r'^CONFIG_TARGET_ARCH_PACKAGES="([a-zA-Z0-9_-]+)"$', config, re.M)
    if not match:
        raise ValueError("SDK package architecture is missing")
    data = dict(identity(), distribution=distribution, target=target,
                channel=channel, architecture=match[1], packages={})
    for name in ("frpc", "frps"):
        candidates = list(directory.glob(f"{name}_*.ipk")) + list(directory.glob(f"{name}-*.apk"))
        if len(candidates) != 1:
            raise ValueError(f"Expected exactly one {name} package")
        package = candidates[0]
        expected = f"{name}-{data['version']}-r{data['revision']}.apk"
        if package.suffix == ".apk" and package.name != expected:
            raise ValueError(f"Unexpected package version: {package.name}")
        data["packages"][name] = {"file": package.name, "sha256": digest(package)}
    (directory / "build-metadata.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def prepare(inputs, output):
    wanted = identity()
    selected = {}
    for path in inputs.glob("*/build-metadata.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        if data["distribution"] != "immortalwrt" or data["channel"] != CHANNEL:
            continue
        target = data["target"]
        if target not in TARGETS or target in selected:
            raise ValueError(f"Unexpected or duplicate target: {target}")
        if any(data[key] != value for key, value in wanted.items()):
            raise ValueError("Artifact version/source hash does not match the release")
        if data["architecture"] != TARGETS[target]:
            raise ValueError(f"Unexpected SDK architecture for {target}")
        selected[target] = (path.parent, data)
    if set(selected) != set(TARGETS):
        raise ValueError(f"Missing release targets: {set(TARGETS) - set(selected)}")
    if output.exists() and any(output.iterdir()):
        raise ValueError("Release output directory must be empty")
    output.mkdir(parents=True, exist_ok=True)
    provenance = []
    for target, (directory, data) in selected.items():
        for name in ("frpc", "frps"):
            item = data["packages"][name]
            filename = f"{name}-{wanted['version']}-r{wanted['revision']}.apk"
            if item["file"] != filename:
                raise ValueError("Unexpected package filename or format")
            package = directory / filename
            if digest(package) != item["sha256"]:
                raise ValueError("Package checksum mismatch")
            dest = f"{name}_{wanted['version']}-r{wanted['revision']}_{data['architecture']}.apk"
            shutil.copyfile(package, output / dest)
        for name in ("sdk-provenance.json", "sdk.config", "feed-commits.txt", "feeds.conf.used", "build-metadata.json"):
            provenance.append((directory / name, target.replace("/", "-") + "/" + name))
    with zipfile.ZipFile(output / "build-provenance.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path, name in provenance:
            archive.write(path, name)
    checksums = "".join(f"{digest(p)}  {p.name}\n" for p in sorted(output.iterdir()))
    (output / "SHA256SUMS").write_text(checksums, encoding="utf-8", newline="\n")
    print(f"Prepared {len(TARGETS) * 2} APK packages for ImmortalWrt {CHANNEL}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    rec = commands.add_parser("record")
    rec.add_argument("directory", type=Path)
    rec.add_argument("distribution")
    rec.add_argument("target")
    rec.add_argument("channel")
    prep = commands.add_parser("prepare")
    prep.add_argument("inputs", type=Path)
    prep.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.command == "record":
        record(args.directory, args.distribution, args.target, args.channel)
    else:
        prepare(args.inputs, args.output)
