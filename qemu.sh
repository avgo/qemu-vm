#!/bin/bash

script_rp="$(realpath "${0}")"         || exit 1
script_dir="$(dirname "${script_rp}")" || exit 1
conf_rp="${script_dir}/qemu.conf.sh"
source "$conf_rp"                      || exit 1


action_run() {
	local snapshot=-snapshot
	xterm -T "MY QEMU" -geometry "100x80-0+0" -e qemu-system-x86_64 \
		-m 2G                              \
		-hda "${virt_hdd}"                 \
		$snapshot                          \
		-nodefaults                        \
		-nographic                         \
		-vga none                          \
		-serial stdio                      \
		-net nic -net user & PID=$!
		#-net nic,vlan=0 -net user,vlan=0
	echo PID: $PID
}

action_run_setup() {
	qemu-system-x86_64 \
		-boot d -cdrom "${virt_cdrom}" \
		-m 2G                              \
		-hda "${virt_hdd}"                 \
		-net nic -net user & PID=$!
	echo PID: $PID
}

action_run_setup2() {
	local snapshot=-snapshot
	qemu-system-x86_64                  \
		-m 2G                       \
		-hda "${virt_hdd}"          \
		$snapshot                   \
		-net nic -net user & PID=$!
	echo PID: $PID
}

main() {
	if test $# -ne 1; then
		echo "error: " >&2
		return 1
	fi
	local action="$1"; shift
	case "${action}" in
	run) ;;
	run_setup) ;;
	run_setup2) ;;
	*)	echo "error: bad action '${action}'" >&2
		return 1
		;;
	esac
	"action_${action}" "$@"
}

main "$@"
