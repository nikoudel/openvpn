sudo docker run \
  --name=openvpn \
  -v openvpn:/mnt/openvpn \
  -p 1194:1194/udp \
  --network=vpn \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  -it \
  --rm \
  nikoudel/openvpn

