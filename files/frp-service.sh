# SPDX-License-Identifier: Apache-2.0
# Legacy UCI layout follows ImmortalWrt packages/openwrt-23.05 net/frp.
# New implementation: preserve conf/init sections, validate before procd starts,
# and allow a complete upstream INI or TOML file without rewriting it.
# BusyBox ash supports local variables.
# shellcheck disable=SC3043,SC2329 # UCI invokes callbacks indirectly.

frp_error() {
	logger -t "$NAME" "$*"
	return 1
}

frp_find_init() {
	[ -n "$init_cfg" ] || init_cfg="$1"
	return 0
}

frp_readable() {
	case "$1" in
		/*) ;;
		*) frp_error 'configuration path must be absolute'; return 1 ;;
	esac
	[ -f "$1" ] && [ -r "$1" ] || {
		frp_error 'configuration file is missing or unreadable'; return 1
	}
}

frp_ini_section() {
	local section_name active
	frp_emit=0
	[ "${1:-}" = conf ] || return 0
	config_get_bool active "$2" enabled 1
	[ "$active" -eq 1 ] || return 0
	config_get section_name "$2" name "$2"
	case "$section_name" in
		''|*']'*|*'['*|*'
'*) frp_failed=1; frp_error 'invalid INI section name'; return 0 ;;
	esac
	printf '\n[%s]\n' "$section_name" >> "$generated"
	frp_emit=1
}

frp_ini_option() {
	[ "$frp_emit" -eq 1 ] || return 0
	case "$1" in name|enabled) return 0 ;; esac
	case "$2" in
		*'
'*) frp_failed=1; frp_error 'INI option must occupy one line'; return 0 ;;
	esac
	printf '%s = %s\n' "$1" "$2" >> "$generated"
}

frp_ini_list() {
	[ "$frp_emit" -eq 1 ] || return 0
	if [ "$1" = _ ]; then
		printf '%s\n' "$2" >> "$generated"
	else
		frp_failed=1
		frp_error 'this UCI list requires the newer official TOML generator' || :
	fi
}

frp_include() {
	if frp_readable "$1"; then
		printf '\n' >> "$generated"
		cat "$1" >> "$generated" || frp_failed=1
		printf '\n' >> "$generated"
	else
		frp_failed=1
	fi
}

frp_watch() {
	procd_append_param file "$1"
}

frp_env() {
	procd_append_param env "$1"
}

frp_export() {
	case "$1" in
		*=*) export "${1?}" ;;
		*) return 1 ;;
	esac
}

start_service() {
	local init_cfg='' main_type enabled=1 config_file generated=''
	local stdout=1 stderr=1 respawn=1 run_user='' run_group=''
	local frp_failed=0 frp_emit=0 old_umask
	# rc.common normally supplies these callbacks. Reset after previous reloads.
	reset_cb
	config_load "$NAME" || return 1
	config_foreach frp_find_init init
	config_get main_type main TYPE
	if [ "$main_type" = "$NAME" ]; then
		# Preserve this feed's original direct-file configuration as well.
		init_cfg=main
		config_get config_file main config_file "/etc/frp/$NAME.toml"
	elif [ -n "$init_cfg" ]; then
		config_get config_file "$init_cfg" config_file
	fi
	if [ -n "$init_cfg" ]; then
		config_get_bool enabled "$init_cfg" enabled 1
		config_get_bool stdout "$init_cfg" stdout 1
		config_get_bool stderr "$init_cfg" stderr 1
		config_get_bool respawn "$init_cfg" respawn 1
		config_get run_user "$init_cfg" user
		config_get run_group "$init_cfg" group
	fi
	[ "$enabled" -eq 1 ] || return 0
	if [ -z "$config_file" ]; then
		local common_type
		config_get common_type common TYPE
		[ "$common_type" = conf ] || {
			frp_error 'expected legacy UCI conf/common or an explicit config_file'; return 1
		}
		mkdir -p "$FRP_RUNTIME" || return 1
		old_umask=$(umask)
		umask 077
		generated=$(mktemp "$FRP_RUNTIME/.$NAME.XXXXXX")
		umask "$old_umask"
		[ -n "$generated" ] || return 1
		config_cb() { frp_ini_section "$@"; }
		option_cb() { frp_ini_option "$@"; }
		list_cb() { frp_ini_list "$@"; }
		config_load "$NAME" || frp_failed=1
		reset_cb
		[ -z "$init_cfg" ] || config_list_foreach "$init_cfg" conf_inc frp_include
		if [ "$frp_failed" -ne 0 ]; then
			rm -f "$generated"
			return 1
		fi
		config_file="$generated"
	fi
	if ! frp_readable "$config_file" || grep -q 'CHANGE_ME_WITH_A_LONG_RANDOM_TOKEN' "$config_file"; then
		[ -z "$generated" ] || rm -f "$generated"
		frp_error 'check the configuration path and replace the example token'
		return 1
	fi
	# Apply the same template environment during verification and at runtime.
	if ! (
		[ -z "$init_cfg" ] || config_list_foreach "$init_cfg" env frp_export
		"$PROG" verify -c "$config_file"
	); then
		[ -z "$generated" ] || rm -f "$generated"
		return 1
	fi
	if [ -n "$generated" ]; then
		if [ -n "$run_user" ]; then
			chown "$run_user${run_group:+:$run_group}" "$generated" || {
				rm -f "$generated"; return 1
			}
		fi
		config_file="$FRP_RUNTIME/$NAME.ini"
		mv -f "$generated" "$config_file" || { rm -f "$generated"; return 1; }
	fi
	procd_open_instance main
	procd_set_param command "$PROG" -c "$config_file"
	procd_set_param file "$config_file" "/etc/config/$NAME"
	[ -z "$init_cfg" ] || config_list_foreach "$init_cfg" conf_inc frp_watch
	procd_set_param stdout "$stdout"
	procd_set_param stderr "$stderr"
	[ -z "$run_user" ] || procd_set_param user "$run_user"
	[ -z "$run_group" ] || procd_set_param group "$run_group"
	[ "$respawn" -eq 0 ] || procd_set_param respawn 3600 5 5
	[ -z "$init_cfg" ] || config_list_foreach "$init_cfg" env frp_env
	procd_set_param limits core="0"
	procd_close_instance
}

service_triggers() {
	procd_add_reload_trigger "$NAME"
}

reload_service() {
	stop
	start
}
