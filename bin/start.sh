#!/usr/bin/env bash

docker run \
    --name ipsec-vpn-server \
    --restart=always \
    --network=host \
    -v ikev2-vpn-data:/etc/ipsec.d \
    -p 500:500/udp \
    -p 4500:4500/udp \
    -d --privileged \
    hwdsl2/ipsec-vpn-server

