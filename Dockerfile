FROM alpine:latest

RUN apk add iptables \
  && apk add openvpn \
  && apk add easy-rsa \
  && apk add nano

