#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts" "$tmp/new-frp"
export expected_package="$tmp/new-frp"
cat > "$tmp/scripts/feeds" <<'EOF'
#!/usr/bin/env bash
set -eu
case "$1" in
    uninstall) printf '# selections removed by feeds uninstall\n' > .config ;;
    install)
        [[ ${fail_install:-0} == 0 ]] || exit 1
        mkdir -p package/feeds/frp_custom
        ln -s "$expected_package" package/feeds/frp_custom/frp
        ;;
    *) exit 1 ;;
esac
EOF
chmod +x "$tmp/scripts/feeds"
cd "$tmp"
printf 'CONFIG_PACKAGE_frpc=y\nCONFIG_PACKAGE_frps=m\nCONFIG_TARGET_x86=y\n' > original
cp original .config
bash "$repo/scripts/install-feed.sh" frp_custom "$expected_package"
cmp original .config
[[ $(readlink -f package/feeds/frp_custom/frp) == "$expected_package" ]]
if fail_install=1 bash "$repo/scripts/install-feed.sh" frp_custom "$expected_package"; then
    echo 'Installation failure was ignored' >&2
    exit 1
fi
cmp original .config
rm package/feeds/frp_custom/frp
expected_package="$repo/frp"
bash "$repo/scripts/install-feed.sh"
cmp original .config
[[ $(readlink -f package/feeds/frp_custom/frp) == "$expected_package" ]]
echo 'PASS: feed switch selects the new package and preserves .config on success and failure'
