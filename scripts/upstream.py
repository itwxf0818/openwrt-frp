#!/usr/bin/env python3
"""Version metadata and authenticated release lookup. Python 3.11+, stdlib only."""
import hashlib
import json
import os
from pathlib import Path
import re
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MAKEFILE = ROOT / "frp" / "Makefile"
API = "https://api.github.com/repos/fatedier/frp/releases/latest"


def version_tuple(value):
    if not re.fullmatch(r"\d+\.\d+\.\d+", value):
        raise ValueError(f"Not a stable numeric version: {value!r}")
    return tuple(map(int, value.split(".")))


def metadata(text=None):
    text = MAKEFILE.read_text(encoding="utf-8") if text is None else text
    result = {}
    for key in ("PKG_VERSION", "PKG_HASH", "PKG_RELEASE"):
        matches = re.findall(rf"^{key}:=([^\n]+)$", text, re.M)
        if len(matches) != 1:
            raise ValueError(f"Expected exactly one {key}")
        result[key] = matches[0].strip()
    version_tuple(result["PKG_VERSION"])
    if not re.fullmatch(r"[0-9a-f]{64}", result["PKG_HASH"]):
        raise ValueError("Invalid SHA256")
    return result


def source_url(version):
    version_tuple(version)
    return f"https://codeload.github.com/fatedier/frp/tar.gz/v{version}"


def fetch(url, destination=None):
    headers = {"User-Agent": "itwxf0818-openwrt-frp", "Accept": "application/vnd.github+json"}
    # Never send the GitHub token to codeload or a download mirror.
    if url.startswith("https://api.github.com/") and os.getenv("GH_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GH_TOKEN"]
    for attempt in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=120) as r:
                if destination is None:
                    return r.read()
                destination = Path(destination)
                destination.parent.mkdir(parents=True, exist_ok=True)
                partial = destination.with_suffix(destination.suffix + ".part")
                digest = hashlib.sha256()
                with partial.open("wb") as output:
                    while block := r.read(1024 * 1024):
                        digest.update(block)
                        output.write(block)
                partial.replace(destination)
                return digest.hexdigest()
        except (OSError, urllib.error.URLError):
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)


def stable_release(data):
    if data.get("draft") or data.get("prerelease"):
        raise ValueError("Refusing draft or prerelease")
    tag = data.get("tag_name", "")
    if not tag.startswith("v"):
        raise ValueError("Expected upstream v-prefixed tag")
    version_tuple(tag[1:])
    return tag[1:]


def replace_metadata(text, version, digest):
    version_tuple(version)
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("Invalid SHA256")
    metadata(text)
    for key, value in {"PKG_VERSION": version, "PKG_HASH": digest, "PKG_RELEASE": "1"}.items():
        text = re.sub(rf"^{key}:=.*$", f"{key}:={value}", text, flags=re.M)
    return text


def check_update():
    current = metadata()["PKG_VERSION"]
    release = json.loads(fetch(API))
    latest = stable_release(release)
    changed = version_tuple(latest) > version_tuple(current)
    if changed:
        archive = ROOT / "work" / f"frp-{latest}.tar.gz"
        digest = fetch(source_url(latest), archive)
        # An HTML error page is not accepted as an upstream source archive.
        import tarfile
        with tarfile.open(archive, "r:gz") as tar:
            module = tar.extractfile(f"frp-{latest}/go.mod").read().decode()
            if not module.startswith("module github.com/fatedier/frp\n"):
                raise ValueError("Unexpected Go module")
        text = replace_metadata(MAKEFILE.read_text(encoding="utf-8"), latest, digest)
        MAKEFILE.write_text(text, encoding="utf-8", newline="\n")
    else:
        print(f"No newer stable release (current={current}, upstream={latest})")
    output = f"changed={str(changed).lower()}\nversion={latest}\n"
    print(output, end="")
    if os.getenv("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as f:
            f.write(output)


def sync_readme():
    data = metadata()
    version = data["PKG_VERSION"]
    release = data["PKG_RELEASE"]
    if not re.fullmatch(r"\d+", release):
        raise ValueError("Invalid package release")
    path = ROOT / "README.md"
    original = path.read_text(encoding="utf-8")
    line = f"<!-- frp-version --> 当前版本：**FRP {version}** · 软件包：**{version}-r{release}**"
    updated, count = re.subn(r"^<!-- frp-version -->[^\n]*$", lambda _: line, original, flags=re.M)
    if count != 1:
        raise ValueError("Expected exactly one README version marker")
    path.write_text(updated, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--sync-readme", action="store_true")
    args = parser.parse_args()
    if args.sync_readme:
        sync_readme()
    else:
        check_update()
