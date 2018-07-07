This repository contains a do-it-yourself guide to create a docker container providing VPN access to other containers in the same docker network. For example, you can host a Redis server in a cloud and use it from your home machine over a secure VPN connection.

The docker image "nikoudel/openvpn" only contains the needed binaries - namely openvpn, iptables and easy-rsa. All configuration is left for the user. The following sections describe one way of configuring an OpenVPN server and a client for the Redis scenario mentioned above.

## Prepare docker host

* Create a volume to be used by the vpn container

`sudo docker volume create openvpn`

* Create a network inside which containers will communicate

`sudo docker network create vpn --subnet 172.20.108.0/24`

* Create a test container in the new network and note the ip address (e.g. 172.20.108.2)

`sudo docker inspect $(sudo docker run --name redis --network=vpn -d redis) | grep IPAddress`

## Configure OpenVPN

* If you want to build the docker image from scratch:

```
git pull https://github.com/nikoudel/openvpn.git
cd openvpn
sudo docker build -t nikoudel/openvpn .
```

Otherwise the next step will get the image from the docker repository.

* Start the VPN container with a shell

```
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
```

* Generate keys (see the [quickstart](https://github.com/OpenVPN/easy-rsa/blob/master/README.quickstart.md) for details)

```
cd /mnt/openvpn

/usr/share/easy-rsa/easyrsa init-pki
/usr/share/easy-rsa/easyrsa build-ca
/usr/share/easy-rsa/easyrsa gen-dh
openvpn --genkey --secret /mnt/openvpn/pki/ta.key

/usr/share/easy-rsa/easyrsa gen-req <server name> nopass
/usr/share/easy-rsa/easyrsa sign-req server <server name>

/usr/share/easy-rsa/easyrsa gen-req <client name> nopass
/usr/share/easy-rsa/easyrsa sign-req client <client name>
```

Note: repeat the last two steps to create more client certificates if needed.

Copy (cat and copy/paste) `/mnt/openvpn/pki/ca.crt` and `/mnt/openvpn/pki/ta.key` to all client machines. Also get each `/mnt/openvpn/pki/issued/<client name>.crt` and `/mnt/openvpn/pki/private/<client name>.key` to each corresponding client machine.

* Create the OpenVPN server configuration file

The following configuration is based on recommendations from [this example](https://github.com/OpenVPN/openvpn/blob/master/sample/sample-config-files/server.conf).

`nano /mnt/openvpn/server.ovpn`

```
port 1194
proto udp
dev tun
ca /mnt/openvpn/pki/ca.crt
cert /mnt/openvpn/pki/issued/<server name>.crt
key /mnt/openvpn/pki/private/<server name>.key  # This file should be kept secret
dh /mnt/openvpn/pki/dh.pem
tls-auth /mnt/openvpn/pki/ta.key 0 # This file is secret
server 10.8.108.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "route 172.20.108.0 255.255.255.0" # push route to the docker network
keepalive 10 120
cipher AES-256-CBC
user nobody
group nobody
persist-key
persist-tun
status openvpn-status.log
verb 3
mute 20
explicit-exit-notify 1
```

* Create the OpenVPN client configuration file

The following configuration is based on recommendations from [this example](https://github.com/OpenVPN/openvpn/blob/master/sample/sample-config-files/client.conf).

Note: this example was tested on Windows but should work on other platforms too.

`notepad.exe "C:\Program Files\OpenVPN\config\client.ovpn"`

```
client
dev tun
proto udp
remote <public server ip address / fqdn> 1194
resolv-retry infinite
nobind
persist-key
persist-tun
ca "C:\\Program Files\\OpenVPN\\config\\ca.crt"
cert "C:\\Program Files\\OpenVPN\\config\\client.crt"
key "C:\\Program Files\\OpenVPN\\config\\client.key"
tls-auth "C:\\Program Files\\OpenVPN\\config\\ta.key" 1
remote-cert-tls server
cipher AES-256-CBC
auth-nocache
comp-lzo
verb 3
mute 20
```

## Create the VPN startup script and run OpenVPN

In the VPN container `nano /mnt/openvpn/start-vpn.sh`

```
#!/bin/sh

iptables -t nat -A POSTROUTING -o eth0 -s 10.8.108.0/24 -j MASQUERADE
openvpn --config /mnt/openvpn/server.ovpn
```

The ipdatables command enables NAT for packets going from VPN to the docker network (e.g. to the redis server) - otherwise the packets will not find their way back to the VPN gateway.

Now start the VPN server by running `sh /mnt/openvpn/start-vpn.sh` and the Windows client `net start OpenVPNService`. The server will print logs to console and the client to `C:\Program Files\OpenVPN\log\<client name>.log`; both should not have any errors. Pinging the redis container from the Windows machine should work now too:

```
C:\> ping 172.20.108.2

Pinging 172.20.108.2 with 32 bytes of data:
Reply from 172.20.108.2: bytes=32 time=47ms TTL=63
Reply from 172.20.108.2: bytes=32 time=47ms TTL=63
Reply from 172.20.108.2: bytes=32 time=48ms TTL=63
Reply from 172.20.108.2: bytes=32 time=48ms TTL=63
```

Stop both the client (`net stop OpenVPNService`) and the server (Ctrl+C) and exit the VPN container. Start the server detached like this:

```
sudo docker run \
  --name=openvpn \
  -v openvpn:/mnt/openvpn \
  -p 1194:1194/udp \
  --network=vpn \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  -d \
  nikoudel/openvpn \
  sh /mnt/openvpn/start-vpn.sh
```

Start the client again with `net start OpenVPNService` and see if it still works.

Congratulations! Now you can use your dockerized cloud-hosted service locally!