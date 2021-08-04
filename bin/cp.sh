#!/usr/bin/env bash
set -eu
src="$1"
shift
docker cp ipsec-vpn-server:"$src" "$@"
