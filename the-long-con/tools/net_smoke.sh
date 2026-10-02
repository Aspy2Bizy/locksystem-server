#!/usr/bin/env bash
# Starts a headless host and client on localhost and checks they agree on the bank.
set -u
cd "$(dirname "$0")/.."
godot --headless -- --scene=res://tests/net_smoke.tscn --net=host > /tmp/tlc_host.log 2>&1 &
HOST=$!
sleep 2
godot --headless -- --scene=res://tests/net_smoke.tscn --net=client > /tmp/tlc_client.log 2>&1
CLIENT=$?
wait $HOST
HOSTRC=$?
grep -h "\[host\]\|\[client\]" /tmp/tlc_host.log /tmp/tlc_client.log
echo "host exit $HOSTRC, client exit $CLIENT"
[ $HOSTRC -eq 0 ] && [ $CLIENT -eq 0 ]
