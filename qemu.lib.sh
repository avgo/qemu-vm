#!/bin/bash

date-timestamp-for-file()
{
    local ARGS ns
    ARGS=('date');
    for arg; do
        if echo "$arg" | grep -q "^[0-9][0-9]*$" 2> /dev/null 1>&2; then
            ARGS+=("--date=@$arg");
        elif test x"$arg" = xns; then
            ns=_%N
        else
            echo "error: " >&2
            return 1
        fi
    done
    ARGS+=("+%Y-%m-%d_%H-%M-%S$ns");
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

	date_timestamp="$(${script_dir}/bin/date-timestamp-for-file)" || return 1
	qemu_snapshot_filename="${back_rp_ne}/${date_timestamp}.qcow2"

	if ! cd "${back_rp_ne}"; then
		echo "error in ${FUNCNAME[0]}(): \"${back_rp_ne}\" can't change directory." >&2
		return 1
	fi

	qemu_snapshot_do "../$(basename "${back_rp}")" "${qemu_snapshot_filename}"

	cd -
}

qemu_snapshot_do() {
	qemu-img create -f qcow2 -b "$@" || return 1

	qemu-img info --backing-chain "$qemu_snapshot_filename"
}

qemu_snapshot_template() {
	:
}
