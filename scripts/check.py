#!/usr/bin/env python3
"""Local structural checks; runtime and SDK checks are separate CI steps."""
import tomllib
from upstream import ROOT, metadata

m = metadata()
for service in ("frpc", "frps"):
    with (ROOT / "frp" / "files" / f"{service}.toml").open("rb") as f:
        data = tomllib.load(f)
    assert data["auth"]["method"] == "token"
    assert data["log"]["to"] == "console"
    config = (ROOT / "frp" / "files" / f"{service}.config").read_text()
    assert "option enabled '0'" in config
for path in [ROOT / "frp" / "Makefile", * (ROOT / "frp" / "files").iterdir(), *(ROOT / "scripts").glob("*.sh")]:
    raw = path.read_bytes()
    assert b"\r" not in raw, f"CRLF in {path}"
    assert not raw.startswith(b"\xef\xbb\xbf"), f"BOM in {path}"
makefile = (ROOT / "frp" / "Makefile").read_text()
assert "\ninclude $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk\n" in makefile
assert "GO_PKG_TAGS:=noweb" in makefile
print(f"Static checks passed: FRP {m['PKG_VERSION']}")
