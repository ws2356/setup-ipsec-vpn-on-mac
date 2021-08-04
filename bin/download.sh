#!/usr/bin/env bash
set -eu
docker exec -it ipsec-vpn-server cp /etc/ipsec.d/vpnclient.sswan /etc/ipsec.d/vpnclient.p12 /etc/ipsec.d/vpnclient.mobileconfig .
