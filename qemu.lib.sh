#!/bin/bash

date-timestamp-for-file() {
    ARGS=('date');
    test x"$1" != x && ARGS+=("--date=@$1");
    ARGS+=("+%Y-%m-%d_%H-%M-%S");
    "${ARGS[@]}"
}

qemu_snapshot() {
	unset qemu_snapshot_filename

	#local snapshot_dir="$1"; shift
	local back_rp="$1"; shift

	if ! qemu-img check -q "$back_rp"; then
		echo "error in ${FUNCNAME[0]}(): invalid file argument, file must be a valid snapshot (backing file)." >&2
		return 1
	fi

	local snapshot_dir date_timestamp

	snapshot_dir="$(dirname "$(realpath "$back_rp")")"

	while true; do
		date_timestamp="$(date-timestamp-for-file)"
		qemu_snapshot_filename="${snapshot_dir}/virt_hdd_debian_${date_timestamp}.qcow2"
		test -f "$qemu_snapshot_filename" || break
		sleep 0.2
	done

	qemu-img create -f qcow2 -b "${back_rp}" "${qemu_snapshot_filename}"

	#qemu-img info "${snapshot_dir}/virt_hdd_debian_3.qcow2"

	qemu-img info "$qemu_snapshot_filename"
}

qemu_snapshot_template() {
	:
}
