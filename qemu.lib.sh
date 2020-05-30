#!/bin/bash

check_file_ext() {
	if test $# -ne 2; then
		echo "error in ${FUNCNAME[0]}(): bad usage." >&2
		return 1
	fi

	local img ext img_no_ext

	img="$2"; ext="$1"; img_no_ext="${img%.$ext}"

	if test x"${img_no_ext}" = x"${img}"; then
		echo "error in ${FUNCNAME[0]}(): \"${img}\" must be with '*.${ext}' extension." >&2
		return 1
	fi

	if test x"${img_no_ext}" = x; then
		echo "error in ${FUNCNAME[0]}(): \"${img}\" have only extension." >&2
		return 1
	fi

	if test x"${img_no_ext%/}" != x"${img_no_ext}"; then
		echo "error in ${FUNCNAME[0]}(): \"${img_no_ext}\" must not be ends with \"/\"." >&2
		return 1
	fi

	echo "${img_no_ext}"
}

check_i_dir() {
	local magic="${1}"; shift
	local err_msg
	if test $# -gt 0; then
		err_msg=", ${1}"; shift
	fi

	local magic_i="${magic}/i"

	if test -d "${magic_i}"; then
		echo "error in ${FUNCNAME[0]}(): \"${magic}\" has i-dir${err_msg}." >&2
		return
	fi

	return 1
}

check_magic_dir() {
	local magic="$1"

	if ! test -d "${magic}"; then
		echo "error in ${FUNCNAME[0]}(): Directory (magic) \"${magic}\" not exists." >&2
		return 1
	fi

	local img="${magic}/img.qcow2"

	if ! test -f "${img}"; then
		echo "error in ${FUNCNAME[0]}(): img.qcow2 is not exists in directory (magic) \"${magic}\"." >&2
		return 1
	fi
}

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

qemu_snapshot2() {
	unset qemu_snapshot2_filename
	local magic="$1"; shift
	local ptr

	if test $# -gt 0; then
		ptr="$1"; shift
	fi

	if ! check_magic_dir "${magic}"; then
		echo "error in ${FUNCNAME[0]}()." >&2
		return 1
	fi

	local img="${magic}/img.qcow2"
	local imgs="${magic}/i"

	if ! test -d "${imgs}"; then
		mkdir -v "${imgs}" || return 1
	fi

	date_timestamp="$(${script_dir}/bin/date-timestamp-for-file)" || return 1

	magic_snapshot="${imgs}/${date_timestamp}"

	mkdir -v "${magic_snapshot}" || return 1

	cd "${magic_snapshot}" || return 1

	if ! qemu-img create -f qcow2 -b "../../img.qcow2" "img.qcow2"; then
		cd -
		return 1
	fi

	qemu-img info --backing-chain "img.qcow2"

	cd -

	echo new image: ${magic_snapshot}

	test x"$ptr" = x || eval "${ptr}=\"\${magic_snapshot}\""
}

virt_hdd_dir() {
	local dir1="$1"; shift
	local dir2="$virt_hdd_dir/$dir1"
	if test -d "$dir2"; then
		dir1="$dir2"
	elif ! test -d "$dir1"; then
		echo "error: not finded.
    $dir1
    $dir2" >&2
		return 1
	fi
	realpath "$dir1" || return 1
	return
}
