#!/usr/bin/env bash
# Exercise the discovery pipeline from ImmortalWrt openwrt-25.12 include/scan.mk.
# The SDK stages package inputs separately; this checks the published feed layout.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/feeds/frp_custom"
git -C "$repo" ls-files --cached --others --exclude-standard -z |
    while IFS= read -r -d '' path; do
        [[ -f "$repo/$path" ]] || continue
        mkdir -p "$tmp/feeds/frp_custom/$(dirname "$path")"
        cp "$repo/$path" "$tmp/feeds/frp_custom/$path"
    done
cd "$tmp"
scan() {
    local directory=$1
    # Keep the upstream pipeline verbatim to detect feed discovery regressions.
    # shellcheck disable=SC2038
    find -L "$directory" -mindepth 1 -maxdepth 5 -name Makefile |
        xargs grep -aHE 'call (Build/DefaultTargets|BuildPackage|KernelPackage)' |
        sed -e "s#^$directory/##" -e 's#/Makefile:.*##' | uniq
}
actual=$(scan feeds/frp_custom)
[[ "$actual" == frp ]] || { printf 'Invalid feed package discovery: %s\n' "$actual" >&2; exit 1; }
[[ -f "feeds/frp_custom/$actual/files/frpc.init" ]]
[[ -f "feeds/frp_custom/$actual/files/frps.init" ]]
# Show that the former root-level layout fails this same discovery rule.
mkdir -p feeds/broken
cp feeds/frp_custom/frp/Makefile feeds/broken/Makefile
broken=$(scan feeds/broken)
[[ "$broken" == *'Makefile:'* ]] || { echo 'Former layout no longer reproduces the failure' >&2; exit 1; }
echo 'Published feed layout passed; former layout failure reproduced.'
