#!/bin/sh
# TCP and remote DNS round trip through the local SOCKS proxy; no account data.
export PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin
umask 077
port=${1:-1080}
case "$port" in 1080|1081|1082) ;; *) exit 2;; esac
reply=/tmp/agvpn-probe.$$
np=
cleanup() {
 trap - EXIT HUP INT TERM
 [ -z "$np" ] || kill "$np" 2>/dev/null
 [ -z "$np" ] || wait "$np" 2>/dev/null
 rm -f "$reply"
}
trap cleanup EXIT HUP INT TERM
{
 printf BQEA | /opt/bin/busybox base64 -d
 sleep 1
 printf BQEAAwtleGFtcGxlLmNvbQBQ | /opt/bin/busybox base64 -d
 sleep 1
 printf 'GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n'
 sleep 6
} | /opt/bin/busybox nc 127.0.0.1 "$port" > "$reply" 2>/dev/null &
np=$!
n=0
while [ "$n" -lt 10 ]; do
 if grep -q 'HTTP/1.[01] 200' "$reply" && grep -q 'Example Domain' "$reply"; then exit 0; fi
 sleep 1
 n=$((n + 1))
done
exit 1
