echo need to update this script

dhclient -r -v &&

ip link set dev $ethX down &&
ip link set $ethX nomaster &&

ip link set dev br0 down

for ((i=0;;++i)); do
	tapX=tap${i}
	ip address show $tapX || break
	echo try to down $tapX
	ip link set dev $tapX down
	ip link set $tapX nomaster
	ip tuntap delete dev $tapX mode tap
done

ip link delete br0 &&

service NetworkManager restart

echo bridge:
bridge link
echo tuntap:
ip tuntap show
echo ip a:
ip a
