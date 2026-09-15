#!/bin/sh
export PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin
umask 077
base=/opt/adguardvpn_cli
run=/tmp/agvpn-boot
profiles='profile-a profile-b profile-c'
lock=/tmp/agvpn-service.lock
live() {
 for p in $profiles; do
  for file in "$run/$p.launch.pid" "$run/$p/pid" "$run/$p/child"; do
   [ -f "$file" ] || continue
   pid=$(cat "$file")
   case "$pid" in ''|*[!0-9]*|0|1) continue;; esac
   # An ambiguous/reused live PID blocks cleanup; never kill it here.
   kill -0 "$pid" 2>/dev/null && return 0
  done
 done
 return 1
}
clear_runtime() {
 for p in $profiles; do
  rm -f "$run/$p.launch.pid"
  for file in pid child status output.log last-log.txt; do
   rm -f "$run/$p/$file"
  done
  [ ! -d "$run/$p" ] || rmdir "$run/$p" || return 1
 done
 rm -f "$run/stop" "$run/status"
 [ ! -d "$run" ] || rmdir "$run"
}
case "${1:-start}" in
 start|stop)
  mkdir "$lock" 2>/dev/null || { echo SERVICE_BUSY; exit 4; }
  trap 'rmdir "$lock"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM HUP
 ;;
esac
case "${1:-start}" in
start)
 [ ! -f "$base/autostart.disabled" ] || exit 0
 [ -x "$base/adguardvpn-cli" ] || exit 2
 [ -r "$base/boot/profiles.sh" ] || { echo PROFILE_SETTINGS_MISSING; exit 2; }
 . "$base/boot/profiles.sh"
 for location in "$PROFILE_A_LOCATION" "$PROFILE_B_LOCATION" "$PROFILE_C_LOCATION"; do
  case "$location" in ''|*'<'*|*'>'*) echo SET_PROFILE_LOCATIONS; exit 2;; esac
 done
 for p in $profiles; do
  [ -s "$base/profiles/$p/adguardvpn-cli.conf" ] || exit 2
 done
 live && { echo ALREADY_RUNNING_OR_PID_CONFLICT; exit 3; }
 if pidof adguardvpn-cli >/dev/null; then
  echo EXISTING_VPN_CONFLICT; exit 3
 fi
 clear_runtime || { echo RUNTIME_CLEANUP_FAILED; exit 3; }
 mkdir "$run" || exit 3
 for p in $profiles; do
  /opt/bin/busybox sh "$base/boot/worker.sh" "$p" </dev/null >/dev/null 2>&1 &
  echo $! > "$run/$p.launch.pid"
 done
 echo START_DISPATCHED > "$run/status"
 ;;
stop)
 [ -d "$run" ] || exit 0
 : > "$run/stop"
 n=0
 while live; do
  [ "$n" -lt 60 ] || { echo STOP_TIMEOUT; exit 3; }
  sleep 1
  n=$((n+1))
 done
 # Refuse cleanup if an untracked CLI survived. Do not terminate unrelated VPNs.
 pidof adguardvpn-cli >/dev/null && { echo EXISTING_VPN_CONFLICT; exit 3; }
 clear_runtime || { echo RUNTIME_CLEANUP_FAILED; exit 3; }
 echo STOPPED
 ;;
status)
 for p in $profiles; do
  printf '%s: ' "$p"; cat "$run/$p/status" 2>/dev/null || echo NOT_STARTED
 done
 ;;
*) exit 2;;
esac
