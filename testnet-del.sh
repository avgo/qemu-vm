dhclient -r -v &&

ip link set dev $ethX down &&
ip link set dev br0 down &&
ip link set dev tap0 down &&

ip link set $ethX nomaster &&
ip link set tap0 nomaster &&
ip tuntap delete dev tap0 mode tap &&
ip link delete br0 &&

service NetworkManager restart &&

echo bridge: &&
bridge link &&
echo tuntap: &&
ip tuntap show &&
echo ip a: &&
ip a
