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

	local snapshot_dir date_timestamp back_rp_ne

	back_rp_ne="${back_rp%.qcow2}"

	if test x"${back_rp_ne}" = x"${back_rp}"; then
		echo "error in ${FUNCNAME[0]}(): \"${back_rp_ne}\" must be with '*.qcow2' extension." >&2
		return 1
	fi

	if test x"${back_rp_ne%/}" != x"${back_rp_ne}"; then
		echo "error in ${FUNCNAME[0]}(): \"${back_rp_ne}\" must not be ends with \"/\"." >&2
		return 1
	fi

	if test -d "${back_rp_ne}"; then
		find "${back_rp_ne}" | sort
		echo
	else
		mkdir -v "${back_rp_ne}" 1>&2 || return 1
	fi

	while true; do
		date_timestamp="$(date-timestamp-for-file)"
		qemu_snapshot_filename="${back_rp_ne}/${date_timestamp}.qcow2"
		test -f "$qemu_snapshot_filename" || break
		sleep 0.2
	done

	qemu-img create -f qcow2 -b "${back_rp}" "${qemu_snapshot_filename}"

	qemu-img info "$qemu_snapshot_filename"
}

qemu_snapshot_template() {
	:
}
