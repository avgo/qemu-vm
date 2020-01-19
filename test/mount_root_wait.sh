#!/bin/bash

mount_root_wait() {
	local dev="$1" dev_i tries=0 tries_max=3
	for ((;;)); do
		for dev_i in "${dev}"p*; do
			test -b "$dev_i" && return
		done
		if test $tries -lt $tries_max; then
			echo waiting for sub devices in $dev ...
			sleep 1; let ++tries
		else
			return 1
		fi
	done
}

for ((i = 0; i < 5; ++i)); do
	dev=/dev/nbd${i}
	echo waiting for $dev
	if mount_root_wait ${dev}; then
		echo ok
	else
		echo fail
	fi
done
