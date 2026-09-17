#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2317
# UCI invokes fixture callbacks indirectly.
# Test the actual service helper with UCI/procd mocks and optional real binaries.
set -eo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
bin_dir=${1:-}
[ -z "$bin_dir" ] || bin_dir=$(cd "$bin_dir" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export calls="$tmp/calls" verify_status=0 real_binary=
cat > "$tmp/frp-mock" <<'EOF'
#!/bin/sh
printf 'verify %s\n' "$*" >> "$calls"
[ "$verify_status" -eq 0 ] || exit "$verify_status"
[ -z "$real_binary" ] || exec "$real_binary" "$@"
EOF
chmod +x "$tmp/frp-mock"
# UCI's callbacks see each section's options; a second load retains values
# until overwritten, as /lib/config/uci.sh does. No eval of user data is used.
declare -A values lists
reset_cb() { config_cb() { :; }; option_cb() { :; }; list_cb() { :; }; }
config() {
    current=$2
    sections+=("$current")
    values["$current,TYPE"]=$1
    config_cb "$@"
}
option() { values["$current,$1"]=$2; option_cb "$@"; }
list() {
    lists["$current,$1"]+="$2"$'\n'
    list_cb "$@"
}
config_load() {
    sections=(); lists=()
    # These fixtures are shell declarations authored by this test.
    # shellcheck disable=SC1090
    source "$fixture"
    config_cb
}
config_get() { printf -v "$1" '%s' "${values["$2,$3"]:-${4:-}}"; }
config_get_bool() {
    local bool_value=${values["$2,$3"]:-${4:-0}}
    case "$bool_value" in 1|true|yes|on) bool_value=1 ;; *) bool_value=0 ;; esac
    printf -v "$1" '%s' "$bool_value"
}
config_foreach() {
    local entry
    for entry in "${sections[@]}"; do
        if [[ ${values["$entry,TYPE"]} == "$2" ]]; then "$1" "$entry"; fi
    done
}
config_list_foreach() {
    local entry
    while IFS= read -r entry; do
        [[ -z $entry ]] || "$3" "$entry"
    done <<< "${lists["$1,$2"]:-}"
}
logger() { :; }
procd_open_instance() { printf 'open %s\n' "${1:-instance1}" >> "$calls"; }
procd_set_param() { printf '%s\n' "$*" >> "$calls"; }
procd_append_param() { procd_set_param "$@"; }
procd_close_instance() { echo close >> "$calls"; }
procd_add_reload_trigger() { :; }
# shellcheck disable=SC1091
source "$repo/frp/files/frp-service.sh"
for NAME in frpc frps; do
    # shellcheck disable=SC1090
    source "$repo/frp/files/$NAME-master.sh"
    # shellcheck disable=SC1091
    source "$repo/frp/files/frp-service.sh"
    PROG="$tmp/frp-mock"
    FRP_RUNTIME="$tmp/runtime"
    real_binary=
    if [[ -n $bin_dir ]]; then
        real_binary="$bin_dir/$NAME"
        [[ ! -f "$real_binary.exe" ]] || real_binary="$real_binary.exe"
    fi
    fixture="$tmp/$NAME.uci"
    # New installations must stay off with the shipped UCI defaults.
    values=(); cp "$repo/frp/files/$NAME.config" "$fixture"
    : > "$calls"; start_service; [[ ! -s $calls ]]
    # Preserve the previous version of this feed's direct-file mode.
    cat > "$fixture" <<EOF
config $NAME main
option enabled 1
option config_file '$tmp/missing'
EOF
    values=()
    if start_service; then echo 'Accepted missing config'; exit 1; fi
    sed -i "s|$tmp/missing|relative.ini|" "$fixture"
    if start_service; then echo 'Accepted relative config'; exit 1; fi
    path="$tmp/config with spaces.toml"
    sed -i "s|relative.ini|$path|" "$fixture"
    cp "$repo/frp/files/$NAME.toml" "$path"
    if start_service; then echo 'Accepted placeholder token'; exit 1; fi
    sed -i 's/CHANGE_ME_WITH_A_LONG_RANDOM_TOKEN/test-only-token/' "$path"
    : > "$calls"; verify_status=1
    if start_service; then echo 'Accepted failed verify'; exit 1; fi
    if grep -q '^open ' "$calls"; then exit 1; fi
    verify_status=0; : > "$calls"; start_service
    grep -Fxq "command $PROG -c $path" "$calls"
    grep -Fxq 'open instance1' "$calls"
    grep -qx close "$calls"
    # Old official LuCI UCI layout: init, common and named/disabled proxies.
    cat > "$fixture" <<EOF
config init service
option uci_format ini
option stdout 0
option respawn 0
list env 'FRP_TEST_ENV=test-value'
list conf_inc '$tmp/extra.ini'
config conf common
option token test-only-token
EOF
    if [[ $NAME == frpc ]]; then
        cat >> "$fixture" <<'EOF'
option server_addr 127.0.0.1
option server_port 7000
option tls_enable true
config conf proxy_internal
option type tcp
option local_ip 127.0.0.1
option local_port 8080
option remote_port 6000
option name public-web
list _ 'use_compression = true'
config conf disabled_proxy
option enabled false
option type invalid-disabled-type
EOF
    else
        cat >> "$fixture" <<'EOF'
option bind_addr 127.0.0.1
option bind_port 7000
option tls_only true
list _ 'allow_ports = 6000'
EOF
    fi
    printf '# included file\n' > "$tmp/extra.ini"
    values=(); : > "$calls"; start_service
    generated="$FRP_RUNTIME/$NAME.ini"
    grep -Fxq '[common]' "$generated"
    grep -Fxq 'token = test-only-token' "$generated"
    grep -Fxq '# included file' "$generated"
    if grep -q disabled_proxy "$generated"; then exit 1; fi
    if [[ $NAME == frpc ]]; then
        grep -Fxq '[public-web]' "$generated"
        grep -Fxq 'use_compression = true' "$generated"
        if grep -q '^name =' "$generated"; then exit 1; fi
    fi
    grep -qx 'stdout 0' "$calls"
    if grep -q '^respawn' "$calls"; then exit 1; fi
    grep -Fxq 'env FRP_TEST_ENV=test-value' "$calls"
    grep -Fxq "command $PROG -c $generated" "$calls"
    grep -Fxq 'open instance1' "$calls"
    cp "$generated" "$tmp/last-good.ini"
    # Reject errors before registering a process; keep last good generated INI.
    rm "$tmp/extra.ini"; : > "$calls"
    if start_service; then echo 'Ignored missing include'; exit 1; fi
    if grep -q '^open ' "$calls"; then exit 1; fi
    cmp "$generated" "$tmp/last-good.ini"
    # Explicit INI under init bypasses conflicting UCI conf sections.
    cat > "$fixture" <<EOF
config init service
option config_file '$tmp/last-good.ini'
config conf common
option invalid_ignored_setting foo
EOF
    values=(); : > "$calls"; start_service
    grep -Fxq "command $PROG -c $tmp/last-good.ini" "$calls"
    grep -qx close "$calls"
    echo "PASS: $NAME native TOML/INI, legacy UCI, includes, disabled proxy, procd options, error handling"
    # Current master default: UCI -> TOML, including modern list/map options.
    cat > "$fixture" <<EOF
config init service
option stdout 0
config conf common
option token test-only-token
option log_file console
EOF
    if [[ $NAME == frpc ]]; then
        cat >> "$fixture" <<'EOF'
option server_addr 127.0.0.1
option server_port 7000
option wire_protocol v1
option tls_enable true
list metadatas 'origin=master-test'
config conf web
option name master-web
option type tcp
option local_ip 127.0.0.1
option local_port 8080
option remote_port 6000
EOF
    else
        cat >> "$fixture" <<'EOF'
option bind_addr 127.0.0.1
option bind_port 7000
option tls_only true
option allow_ports 6000-6010
option max_ports_per_client 4
EOF
    fi
    values=(); : > "$calls"
    # Upstream ash code does not use errexit; use an explicit result check.
    if ! start_service; then echo 'Master generator failed'; exit 1; fi
    generated="$FRP_RUNTIME/$NAME.toml"
    grep -Fxq 'auth.token = "test-only-token"' "$generated"
    grep -Fxq 'open instance1' "$calls"
    grep -Fxq "command $PROG -c $generated" "$calls"
    if [[ $NAME == frpc ]]; then
        grep -Fxq 'serverAddr = "127.0.0.1"' "$generated"
        grep -Fxq 'transport.wireProtocol = "v1"' "$generated"
        grep -Fxq 'metadatas."origin" = "master-test"' "$generated"
        grep -Fxq 'name = "master-web"' "$generated"
    else
        grep -Fxq 'bindPort = 7000' "$generated"
        grep -Fxq 'maxPortsPerClient = 4' "$generated"
        grep -Fxq 'transport.tls.force = true' "$generated"
    fi
    # Invalid modern numeric values must not launch a process.
    if [[ $NAME == frpc ]]; then key=server_port; else key=bind_port; fi
    sed -i "s/option $key 7000/option $key invalid/" "$fixture"
    values=(); : > "$calls"
    if start_service; then echo 'Accepted invalid master config'; exit 1; fi
    if grep -q '^open ' "$calls"; then exit 1; fi
    sed -i "s/option $key invalid/option $key 7000/" "$fixture"
    # Missing/foreign include paths must be fatal, not silently dropped.
    sed -i "/config init service/a list conf_inc '/missing/include.toml'" "$fixture"
    values=(); : > "$calls"
    if start_service; then echo 'Ignored missing master include'; exit 1; fi
    if grep -q '^open ' "$calls"; then exit 1; fi
    echo "PASS: $NAME current master TOML mappings and failure handling"

done
