sudo docker run \
  --name=openvpn \
  -v openvpn:/mnt/openvpn \
  -p 1194:1194/udp \
  --network=vpn \
  --ip=172.20.108.2 \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  -d \
  nikoudel/openvpn sh /mnt/openvpn/start-vpn.sh
