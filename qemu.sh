#!/bin/bash

script_rp="$(realpath "${0}")"         || exit 1
script_dir="$(dirname "${script_rp}")" || exit 1
conf_rp="${script_dir}/qemu.conf.sh"
source "$conf_rp"                      || exit 1

action_mount() {
	if test $# -ne 1; then
		echo error: >&2
		exit 1
	fi
	sudo "${script_rp}" mount_root "$@"
}

action_mount_root() {
	local img="$1"
	if lsmod | grep nbd > /dev/null 2>&1; then
		true
	else
		echo invoking modprobe nbd...
		modprobe nbd max_part=16 || return 1
	fi
	# block device variables
	local bd_idx bd_tmp block_dev block_dev_bn
	for ((bd_idx=0;;++bd_idx)); do
		bd_tmp="/dev/nbd${bd_idx}"
		test -b "$bd_tmp" || break
		if ! lsblk "$bd_tmp" > /dev/null 2>&1; then
			block_dev="$bd_tmp"
			block_dev_bn="$(basename "$block_dev")" || return 1
			break
		fi
	done
	if test x"$block_dev" = x; then
		echo "error: can't find free nbd device" >&2
		return 1
	fi
	local img_mounted="${img}.mounted"
	if test -f "$img_mounted"; then
		printf "error: image %s is mounted at '%s' device.\n" "$img" "$(cat "$img_mounted")" >&2
		return 1
	fi
	qemu-nbd -c "$block_dev" "$img" || return 1
	echo image "$img" is mounted to "$block_dev"
	echo "${block_dev_bn}" > "$img_mounted"
}

action_umount() {
	if test $# -ne 1; then
		echo error: >&2
		exit 1
	fi
	sudo "${script_rp}" umount_root "$@"
}

action_umount_root() {
	local img="$1" img_mounted block_dev block_dev_bn
	img_mounted="${img}.mounted"
	if ! test -f "$img_mounted"; then
		printf "error: image '%s' is not mounted (mount-file is absent).\n" "${img}" >&2
		return 1
	fi
	block_dev_bn="$(cat "$img_mounted")" || return 1
	block_dev="/dev/${block_dev_bn}"
	printf "unmounting %s\n" "$block_dev"
	qemu-nbd -d "${block_dev}" || return 1
	rm -vf "$img_mounted"
	if lsmod | grep nbd > /dev/null 2>&1; then
		echo lsmod nbd rmmod
		rmmod nbd || return 1
	else
		echo lsmod nbd not loaded
	fi
}

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
		-netdev tap,id=network0,ifname=tap0,script=no,downscript=no & PID=$!

	echo PID: $PID

	sleep 2

	cat "/proc/${PID}/cmdline" | xargs -0 echo
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
	mount) ;;
	mount_root) ;;
	run) ;;
	run_root) ;;
	run_setup) ;;
	run_setup2) ;;
	run_snapshot) ;;
	run_snapshot_root) ;;
	snapshot) ;;
	umount) ;;
	umount_root) ;;
	*)	echo "error: bad action '${action}'" >&2
		return 1
		;;
	esac
	"action_${action}" "$@"
}

main "$@"
