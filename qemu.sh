#!/bin/bash

script_rp="$(realpath "${0}")"         || exit 1
script_dir="$(dirname "${script_rp}")" || exit 1
conf_rp="${script_dir}/qemu.conf.sh"
source "$conf_rp"                      || exit 1

action_run() {
	sudo "${script_rp}" run_root "$@"
}

action_run_root() {
	local snapshot virt_hdd_loc

	if test $# -ne 1; then
		echo error: >&2
		return 1
	fi

	if test x"$1" = x-snapshot; then
		snapshot=-snapshot
		virt_hdd_loc="$virt_hdd"
	else
		snapshot=
		virt_hdd_loc="$1"
	fi

	qemu-system-x86_64                  \
		-m 2G                       \
		-hda "${virt_hdd_loc}"      \
		$snapshot                   \
		-device virtio-net,netdev=network0,mac=52:54:00:12:34:01 \
		-netdev tap,id=network0,ifname=tap0,script=no,downscript=no \
		& PID=$!

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
	local sn_str
	if test x"$snapshot" = x; then
		sn_str=no
	else
		sn_str=yes
	fi
	echo snapshot: $sn_str
	echo hda: $virt_hdd
	read
	qemu-system-x86_64                  \
		-m 2G                       \
		-hda "${virt_hdd}"          \
		$snapshot                   \
		-device virtio-net,netdev=network0,mac=52:54:00:12:34:01 \
		-netdev tap,id=network0,ifname=tap0,script=no,downscript=no \
		&
	echo PID: $PID
}

action_run_snapshot() {
	source "${script_dir}/qemu.lib.sh" || return 1
	qemu_snapshot "${backing_fn}"
	qemu_snapshot "${qemu_snapshot_filename}"
	echo sudo "${script_rp}" run_snapshot_root "${qemu_snapshot_filename}"
	sudo "${script_rp}" run_snapshot_root "${qemu_snapshot_filename}"
}

action_run_snapshot_root() {
	echo UID: $UID
	qemu-system-x86_64                  \
		-m 2G                       \
		-hda "${1}"                 \
		-device virtio-net,netdev=network0,mac=52:54:00:12:34:01 \
		-netdev tap,id=network0,ifname=tap0,script=no,downscript=no \
		&
	echo "PID: $PID hda: ${1}"
}

action_snapshot() {
	if test $# -ne 1; then
		echo "error: bad usage." >&2
		return 1
	fi

	source "${script_dir}/qemu.lib.sh" || return 1

	qemu_snapshot "${1}"
}

main() {
	if test $# -lt 1; then
		echo "error: " >&2
		return 1
	fi
	local action="$1"; shift
	case "${action}" in
	run) ;;
	run_root) ;;
	run_setup) ;;
	run_setup2) ;;
	run_snapshot) ;;
	run_snapshot_root) ;;
	snapshot) ;;
	*)	echo "error: bad action '${action}'" >&2
		return 1
		;;
	esac
	"action_${action}" "$@"
}

main "$@"
