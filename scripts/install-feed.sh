#!/usr/bin/env bash
# Run from the OpenWrt/ImmortalWrt source root after updating the feeds.
set -euo pipefail
feed=${1:-frp_custom}
expected=${2:-$(cd "$(dirname "$0")/../frp" && pwd)}
[[ "$feed" =~ ^[a-zA-Z0-9_]+$ ]] || { echo 'Invalid feed name' >&2; exit 1; }
[[ -x ./scripts/feeds ]] || { echo 'Run this command from the firmware source root.' >&2; exit 1; }

# feeds uninstall refreshes .config and can drop existing frpc/frps selections.
# Restore the original configuration even if installation fails.
backup=
restore_config() {
    if [[ -n "$backup" ]]; then
        cp "$backup" .config
        rm -f "$backup"
    fi
}
trap restore_config EXIT
if [[ -f .config ]]; then
    backup=$(mktemp)
    cp .config "$backup"
fi
./scripts/feeds uninstall frp
./scripts/feeds install -f -p "$feed" frp
actual=$(readlink -f "package/feeds/$feed/frp")
[[ "$actual" == "$(cd "$expected" && pwd -P)" ]] || {
    echo "FRP feed selection failed: expected $expected, got $actual" >&2
    exit 1
}
printf 'FRP source selected: %s\n' "$actual"
