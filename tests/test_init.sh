#!/usr/bin/env bash
# Exercise init decisions with UCI/procd mocks. Real procd still needs a router.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export calls="$tmp/calls"
export verify_status=0
cat > "$tmp/frp-mock" <<'EOF'
#!/bin/sh
echo "verify $*" >> "$calls"
exit "$verify_status"
EOF
chmod +x "$tmp/frp-mock"
config_load() { :; }
config_get_bool() { printf -v "$1" '%s' "$test_enabled"; }
config_get() { printf -v "$1" '%s' "$test_path"; }
logger() { :; }
procd_open_instance() { echo 'open' >> "$calls"; }
procd_set_param() { printf '%s\n' "$*" >> "$calls"; }
procd_close_instance() { echo 'close' >> "$calls"; }
procd_add_reload_trigger() { :; }
for name in frpc frps; do
    sed "s|/usr/bin/$name|$tmp/frp-mock|g" "$repo/files/$name.init" > "$tmp/init"
    # shellcheck disable=SC1091
    source "$tmp/init"
    : > "$calls"
    test_enabled=0
    test_path="$tmp/missing"
    start_service
    [[ ! -s "$calls" ]]
    test_enabled=1
    if start_service; then echo 'Accepted missing config'; exit 1; fi
    test_path='relative.toml'
    if start_service; then echo 'Accepted relative config'; exit 1; fi
    test_path="$tmp/config with spaces.toml"
    cp "$repo/files/$name.toml" "$test_path"
    if start_service; then echo 'Accepted placeholder token'; exit 1; fi
    printf 'auth.token = "test-token"\n' > "$test_path"
    verify_status=1
    if start_service; then echo 'Accepted failed verify'; exit 1; fi
    if grep -qx open "$calls"; then echo 'Started after failed verify'; exit 1; fi
    verify_status=0
    : > "$calls"
    start_service
    grep -qx open "$calls"
    grep -qx 'respawn 3600 5 5' "$calls"
    grep -Fxq "file $test_path" "$calls"
    grep -qx close "$calls"
    echo "PASS: $name disabled, missing path, relative path, placeholder, validation failure, valid launch"
done
