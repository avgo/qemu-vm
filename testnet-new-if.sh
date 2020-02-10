#!/bin/bash

for ((i=0;;++i)); do
	tapX="tap${i}"
	ip address show "${tapX}" || break
done

ip tuntap add dev "$tapX" mode tap &&
ip link set "$tapX" master br0 &&
ip link set dev "$tapX" up &&

echo bridge: &&
bridge link &&
echo tuntap: &&
ip tuntap show &&
echo ip a: &&
ip a
