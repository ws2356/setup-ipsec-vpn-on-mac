#!/usr/bin/env bash
set -eu


# docker run \
#     --name ipsec-vpn-server \
#     --restart=always \
#     --network=host \
#     -v ikev2-vpn-data:/etc/ipsec.d \
#     -p 500:500/udp \
#     -p 4500:4500/udp \
#     -d --privileged \
#     hwdsl2/ipsec-vpn-server

this_file="${BASH_SOURCE[0]}"
if ! [ -e "$this_file" ] ; then
  this_file="$(type -p "$this_file")"
fi
if ! [ -e "$this_file" ] ; then
  echo "Failed to resolve file."
  exit 1
fi
if ! [[ "$this_file" =~ ^/ ]] ; then
  this_file="$(pwd)/$this_file"
fi
while [ -h "$this_file" ] ; do
    ls_res="$(ls -ld "$this_file")"
    link_target=$(expr "$ls_res" : '.*-> \(.*\)$')
    if [[ "$link_target" =~ ^/ ]] ; then
      this_file="$link_target"
    else
      this_file="$(dirname "$this_file")/$link_target"
    fi
done
this_dir="$(dirname "$this_file")"

cd "${this_dir}/.."

VPN_IPSEC_PSK='12345678' \
VPN_USER='test' \
VPN_PASSWORD='123456' bash vpnsetup_mac.sh

