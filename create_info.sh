#!/bin/bash

script_rp="$(realpath "${0}")"         || exit 1
script_dir="$(dirname "${script_rp}")" || exit 1
conf_rp="${script_dir}/qemu.conf.sh"
source "$conf_rp"                      || exit 1

mark_black=$'\E[30m'
mark_black_bold=$'\E[1;30m'
mark_blue=$'\E[34m'
mark_blue_bold=$'\E[1;34m'
mark_brown=$'\E[33m'
mark_brown_bold=$'\E[1;33m'
mark_cyan=$'\E[36m'
mark_cyan_bold=$'\E[1;36m'
mark_e=$'\E[0m'
mark_e_bold=$'\E[1;0m'
mark_green=$'\E[32m'
mark_green_bold=$'\E[1;32m'
mark_magenta=$'\E[35m'
mark_magenta_bold=$'\E[1;35m'
mark_red=$'\E[31m'
mark_red_bold=$'\E[1;31m'
mark_white=$'\E[37m'
mark_white_bold=$'\E[1;37m'

create_info() {
	local date_timestamp="$1"; shift
	local info_file="$1"; shift
	if test -f "$info_file"; then
		echo "info: ${mark_green}${info_file}${mark_e}"
	else
		echo "info: ${mark_red}${info_file}${mark_e}"
		cat > "${info_file}" <<EOF
$date_timestamp

temporary snapshot
EOF
	fi
}

main() {
	if ! test -d "$1"; then
		echo error: >&2
		return 1
	fi
	local cf cf_bn date_timestamp cf_info
	for cf in "$1"/*; do
		test -d "$cf" || break
		cf_info="${cf}/info.txt"
		echo "$cf"
		cf_bn="$(basename "$cf")" || return 1
		echo "$cf_bn"
		date_timestamp="$(${script_dir}/bin/date-timestamp-for-file "$cf_bn")" || return 1
		echo "$date_timestamp"
		create_info "$date_timestamp" "$cf_info"
		echo
		test -d "$cf/i" && main "$cf/i"
	done
}

main "$virt_hdd_dir"
