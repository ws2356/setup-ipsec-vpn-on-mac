#!/usr/bin/env bash
set -eu

docker container stop ipsec-vpn-server && docker container rm "$_" || true
docker volume rm ikev2-vpn-data
