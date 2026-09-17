#!/usr/bin/env bash
# Run on Ubuntu with the SDK prerequisites installed.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
distribution=${1:?distribution required}
target=${2:?target required}
mkdir -p "$repo/work/sdk-download" "$repo/work/sdk" "$repo/dist"
python3 "$repo/scripts/download-sdk.py" "$distribution" "$target" "$repo/work/sdk-download"
archives=("$repo"/work/sdk-download/*-sdk-*.tar.*)
[[ ${#archives[@]} == 1 ]]
tar -xf "${archives[0]}" -C "$repo/work/sdk" --strip-components=1
cd "$repo/work/sdk"
# Preserve SDK-pinned feed revisions, including its Go toolchain recipe.
./scripts/feeds update -a
./scripts/feeds install -a
feed_config=feeds.conf.default
[[ ! -f feeds.conf ]] || feed_config=feeds.conf
printf '\nsrc-link frp_custom %s\n' "$repo" >> "$feed_config"
./scripts/feeds update frp_custom
./scripts/feeds install -f -p frp_custom frp
test "$(readlink -f package/feeds/frp_custom/frp)" = "$repo"
cat >> .config <<'EOF'
CONFIG_ALL_NONSHARED=n
CONFIG_ALL_KMODS=n
CONFIG_ALL=n
CONFIG_PACKAGE_frpc=m
CONFIG_PACKAGE_frps=m
EOF
make defconfig
grep -qx 'CONFIG_PACKAGE_frpc=m' .config
grep -qx 'CONFIG_PACKAGE_frps=m' .config
make package/feeds/frp_custom/frp/download V=s
make package/feeds/frp_custom/frp/compile -j2 V=s
cp .config "$repo/dist/sdk.config"
cp "$feed_config" "$repo/dist/feeds.conf.used"
cp "$repo/work/sdk-download/sdk-provenance.json" "$repo/dist/"
for feed in feeds/*/.git; do
    directory=${feed%/.git}
    printf '%s %s\n' "$directory" "$(git -C "$directory" rev-parse HEAD)"
done > "$repo/dist/feed-commits.txt"
find bin/packages -type f \( -name 'frpc_*.ipk' -o -name 'frps_*.ipk' -o -name 'frpc-*.apk' -o -name 'frps-*.apk' \) -exec cp '{}' "$repo/dist/" \;
for binary in frpc frps; do
    packages=("$repo/dist/${binary}"*.ipk "$repo/dist/${binary}"*.apk)
    found=0
    for package in "${packages[@]}"; do [[ ! -f "$package" ]] || found=1; done
    [[ $found == 1 ]] || { echo "Missing package: $binary"; exit 1; }
done
