ethX=eth0

service NetworkManager stop &&

ip link add name br0 type bridge &&
ip tuntap add dev tap0 mode tap &&
# ip addr flush dev br0 &&
ip link set tap0 master br0 &&
ip link set $ethX master br0 &&

ip link set dev $ethX up &&
ip link set dev br0 up &&
ip link set dev tap0 up &&

dhclient -v br0 &&

echo bridge: &&
bridge link &&
echo tuntap: &&
ip tuntap show &&
echo ip a: &&
ip a
