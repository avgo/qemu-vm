#!/bin/bash

script_rp="$(realpath "${0}")"         || exit 1
script_dir="$(dirname "${script_rp}")" || exit 1

source "${script_dir}/qemu.lib.sh" || exit 1

check_file_ext_test() {
	local ret
	while test $# -gt 2; do
		echo " * * * testing $1 $3"; echo
		if ret="$(check_file_ext "$3" "$1")"; then
			if test x"$ret" = x"$2"; then
				echo "result: ok (check ok, result: ${ret})"
			else
				echo "result: ok (check failed)"
			fi
		else
			echo result: failed
		fi
		shift 3
		echo
	done
}

check_file_ext_test \
	"1.qcow2"    1 qcow2 \
	"qwe.txt"  qwe   txt \
	"werew"     ""   txt \
	"/.txt"     ""   txt \
	".txt"      ""   txt

