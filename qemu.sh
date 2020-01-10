#!/bin/bash

script_rp="$(realpath "${0}")"         || exit 1
script_dir="$(dirname "${script_rp}")" || exit 1
conf_rp="${script_dir}/qemu.conf.sh"
source "$conf_rp"                      || exit 1

action_mount() {
	if test $# -ne 1; then
		echo error: >&2
		return 1
	fi
	sudo "${script_rp}" mount_root "$@"
}

action_mount_root() {
	local img="$1" mount_part="$2"
	source "${script_dir}/qemu.lib.sh" || return 1
	if lsmod | grep nbd > /dev/null 2>&1; then
		true
	else
		echo invoking modprobe nbd...
		modprobe nbd max_part=16 || return 1
	fi

	local img_rmpt # root mount point

	img_rmpt="$(check_file_ext "qcow2" "${img}")" || return 1

	if ! test -d "${img_rmpt}"; then
		mkdir "${img_rmpt}" || return 1
	fi

	img_rmpt="${img_rmpt}/mpt"

	if test -d "${img_rmpt}"; then
		echo "error in ${FUNCNAME[0]}(): \"${img_rmpt}\" is already existing mountpoint." >&2
		return 1
	fi

	mkdir "${img_rmpt}" || return 1

	local parts

	parts="${img_rmpt}/parts"

	mkdir "${parts}" || return 1

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

	qemu-nbd -c "$block_dev" "$img" || return 1

	local fs_type cur_mpt block_dev_part_bn

	for dev1 in "$block_dev"*; do
		fs_type="$(blkid -s TYPE -o value "$dev1")"
		case "$fs_type" in
		ext2 | ext3 | ext4 )
			block_dev_part_bn="$(basename "$dev1")"
			cur_mpt="${block_dev_part_bn#$block_dev_bn}"
			if test x"${cur_mpt}" = x; then
				echo "warning: can't mount $dev1"
				continue
			fi
			cur_mpt="${parts}/${cur_mpt}"
			mkdir -v "${cur_mpt}"
			echo "mounting known fs (type '$fs_type') on $dev1 to ${cur_mpt}"
			mount "${dev1}" "${cur_mpt}"
			;;
		*)	continue
			;;
		esac
	done

	read

	for cur_mpt in "${parts}"/*; do
		umount -v "${cur_mpt}" && rmdir -v "${cur_mpt}"
	done

	qemu-nbd -d "${block_dev}" || return 1

	rmdir -v "${parts}" || return 1
	rmdir -v "${img_rmpt}" || return 1
}

action_umount() {
	if test $# -ne 1; then
		echo error: >&2
		exit 1
	fi
	sudo "${script_rp}" umount_root "$@"
}

action_umount_root() {
	local img="$1" img_mounted block_dev block_dev_bn img_m_pt

	source "${script_dir}/qemu.lib.sh" || return 1

	img_m_pt="$(check_file_ext "qcow2" "${img}")" || return 1

	if mountpoint -q "${img_m_pt}"; then
		umount "${img_m_pt}" || return 1
	fi

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
