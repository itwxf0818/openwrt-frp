#!/usr/bin/env bash
# Run on Ubuntu with the SDK prerequisites installed.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
distribution=${1:?distribution required}
target=${2:?target required}
release=${3:-snapshot}
mkdir -p "$repo/work/sdk-download" "$repo/work/sdk" "$repo/dist"
# Only expose package inputs to the feed scanner. Linking the whole repository
# would make work/sdk/feeds/frp_custom point back into its own parent tree.
feed_root=$(mktemp -d "$repo/work/frp-feed.XXXXXX")
cp -R "$repo/frp" "$feed_root/frp"
python3 "$repo/scripts/download-sdk.py" "$distribution" "$target" "$repo/work/sdk-download" --release "$release"
archives=("$repo"/work/sdk-download/*-sdk-*.tar.*)
[[ ${#archives[@]} == 1 ]]
tar -xf "${archives[0]}" -C "$repo/work/sdk" --strip-components=1
cd "$repo/work/sdk"
# SDK LibreSSL cannot load Ubuntu's OpenSSL 3 provider configuration.
# Key generation needs no configuration modules.
export OPENSSL_CONF=/dev/null
(
    umask 077
    /usr/bin/openssl ecparam -name prime256v1 -genkey -noout -out private-key.pem
)
/usr/bin/openssl ec -in private-key.pem -pubout -out public-key.pem
[[ -s private-key.pem && -s public-key.pem ]]
staging_dir/host/bin/openssl ec -in private-key.pem -check -noout
# Preserve SDK-pinned feed revisions, including its Go toolchain recipe.
./scripts/feeds update -a
./scripts/feeds install -a
feed_config=feeds.conf.default
[[ ! -f feeds.conf ]] || feed_config=feeds.conf
printf '\nsrc-link frp_custom %s\n' "$feed_root" >> "$feed_config"
./scripts/feeds update frp_custom
bash "$repo/scripts/install-feed.sh" frp_custom "$feed_root/frp"
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
cp public-key.pem "$repo/dist/public-key.pem"
for package in "$repo"/dist/*.apk; do
    [[ -f "$package" ]] || continue
    # Stable SDKs sign repository indexes, but leave individual APKs unsigned.
    # Release downloads need their own signature for standalone installation.
    # Accept unsigned input only while signing our own freshly built artifact.
    staging_dir/host/bin/apk adbsign --allow-untrusted --reset-signatures --sign "$PWD/private-key.pem" "$package"
    staging_dir/host/bin/apk --keys-dir "$repo/dist" verify "$package"
done
python3 "$repo/scripts/release-assets.py" record "$repo/dist" "$distribution" "$target" "$release"
