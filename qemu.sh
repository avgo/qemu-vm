#!/bin/bash

script_rp="$(realpath "${0}")"         || exit 1
script_dir="$(dirname "${script_rp}")" || exit 1
conf_rp="${script_dir}/qemu.conf.sh"
source "$conf_rp"                      || exit 1


action_run() {
	local snapshot=-snapshot
	qemu-system-x86_64                         \
		-m 2G                              \
		-hda "${virt_hdd}"                 \
		$snapshot                          \
		-nodefaults                        \
		-nographic                         \
		-vga none                          \
		-serial stdio
}

main() {
	if test $# -ne 1; then
		echo "error: " >&2
		return 1
	fi
	local action="$1"; shift
	case "${action}" in
	run) ;;
	*)	echo "error: bad action '${action}'" >&2
		return 1
		;;
	esac
	"action_${action}" "$@"
}

main "$@"
