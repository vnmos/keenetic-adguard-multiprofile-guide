#!/bin/sh
# One supervisor per profile. No session deadline; no native route mutations.
export PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin
umask 077
base=/opt/adguardvpn_cli
[ -r "$base/boot/profiles.sh" ] || exit 2
. "$base/boot/profiles.sh"
case "$1" in
profile-a) country=$PROFILE_A_LOCATION; port=1080;;
profile-b) country=$PROFILE_B_LOCATION; port=1081;;
profile-c) country=$PROFILE_C_LOCATION; port=1082;;
*) exit 2;;
esac
case "$country" in ''|*'<'*|*'>'*) exit 2;; esac
profile=$1
export AGVPN_CLI_DATA_PATH=$base/profiles/$profile
export SSL_CERT_FILE=$base/ca-certificates.crt
run=/tmp/agvpn-boot/$profile
mkdir "$run" || exit 3
vp=
state() { printf '%s\n' "$1" > "$run/status"; }
stop_child() {
 if [ -n "$vp" ] && [ /proc/$vp/exe -ef "$base/adguardvpn-cli" ]; then
  kill -TERM "$vp" 2>/dev/null
  n=0
  while kill -0 "$vp" 2>/dev/null && [ "$n" -lt 5 ]; do sleep 1; n=$((n+1)); done
  [ ! /proc/$vp/exe -ef "$base/adguardvpn-cli" ] || kill -KILL "$vp" 2>/dev/null
 fi
 [ -z "$vp" ] || wait "$vp" 2>/dev/null
 vp=
 rm -f "$run/child"
}
cleanup() { trap - EXIT HUP INT TERM; stop_child; state STOPPED; rm -f "$run/pid"; }
trap cleanup EXIT HUP INT TERM
echo $$ > "$run/pid"
if netstat -lnt | grep -q "127.0.0.1:$port "; then state PORT_CONFLICT; exit 3; fi
while [ ! -f /tmp/agvpn-boot/stop ] && [ ! -f "$base/autostart.disabled" ]; do
 state CONNECTING
 "$base/adguardvpn-cli" connect --no-fork -l "$country" </dev/null > "$run/output.log" 2>&1 &
 vp=$!
 echo "$vp" > "$run/child"
 misses=0
 while kill -0 "$vp" 2>/dev/null; do
  [ ! -f /tmp/agvpn-boot/stop ] && [ ! -f "$base/autostart.disabled" ] || break
  if /opt/bin/busybox sh "$base/boot/health.sh" "$port"; then
   misses=0; state HEALTH_OK
  else
   misses=$((misses+1)); state "HEALTH_MISS:$misses"
   [ "$misses" -lt 6 ] || break
  fi
  # Bound diagnostic files; accounts and profile configuration are untouched.
  for log in "$run/output.log" "$AGVPN_CLI_DATA_PATH/app.log"; do
   if [ -f "$log" ] && [ "$(wc -c < "$log")" -gt 262144 ]; then
    tail -c 32768 "$log" > "$run/last-log.txt"
    : > "$log"
   fi
  done
  sleep 10
 done
 stop_child
 state RETRY_WAIT
 [ ! -f /tmp/agvpn-boot/stop ] && [ ! -f "$base/autostart.disabled" ] || break
 sleep 15
done
