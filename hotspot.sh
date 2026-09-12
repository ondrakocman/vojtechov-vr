#!/bin/bash
# Toggle the offline-demo Wi-Fi hotspot.  The HTTPS server itself runs permanently as a
# systemd user service (vojtechov-vr.service) – see README.md.
#
#   ./hotspot.sh on     start hotspot "Vojtechov VR" (disconnects the PC from its current Wi-Fi)
#   ./hotspot.sh off    stop hotspot and reconnect the previous Wi-Fi
#   ./hotspot.sh        show status
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SSID="Vojtechov VR"; PASS="vojtechov2026"; CON="vojtechov-vr-hotspot"; PORT=8443; AP_IP="10.42.0.1"
IFACE="$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')"
STATE="$HERE/local/.prev-connection"

ensure_profile(){
  nmcli -t -f NAME connection show | grep -qx "$CON" && return
  # 2.4 GHz ch 6: the Intel AX211 refuses AP mode on 5 GHz under the current regulatory domain.
  nmcli connection add type wifi ifname "$IFACE" con-name "$CON" autoconnect no ssid "$SSID" \
    -- 802-11-wireless.mode ap 802-11-wireless.band bg 802-11-wireless.channel 6 \
    ipv4.method shared ipv6.method disabled wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PASS" >/dev/null
}
ensure_server(){
  systemctl --user is-active -q vojtechov-vr.service 2>/dev/null && return
  echo "Server not running – starting it (systemctl --user start vojtechov-vr)…"
  systemctl --user start vojtechov-vr.service 2>/dev/null || \
    (nohup python3 "$HERE/local/serve.py" --port $PORT --root "$HERE" >/dev/null 2>&1 &)
}
banner(){
  echo "================================================================"
  printf "  Wi-Fi:     %s\n  Password:  %s\n  Open:      https://%s:%s/\n" "$SSID" "$PASS" "$AP_IP" "$PORT"
  echo "  (accept the certificate warning once: Advanced -> Proceed)"
  echo "================================================================"
}

case "${1:-status}" in
  on)
    [ -z "$IFACE" ] && { echo "No Wi-Fi interface."; exit 1; }
    ensure_profile; ensure_server
    PREV="$(nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v d="$IFACE" '$2==d && $1!="'"$CON"'"{print $1; exit}')"
    [ -n "$PREV" ] && echo "$PREV" > "$STATE"
    echo "Starting hotspot (disconnects: ${PREV:-nothing})…"
    nmcli connection up "$CON" >/dev/null && banner || { echo "Hotspot failed to start."; exit 1; }
    ;;
  off)
    nmcli connection down "$CON" >/dev/null 2>&1 && echo "Hotspot off."
    if [ -f "$STATE" ]; then PREV="$(cat "$STATE")"; rm -f "$STATE"
      nmcli connection up "$PREV" >/dev/null 2>&1 && echo "Reconnected to $PREV."; fi
    ;;
  *)
    if nmcli -t -f NAME connection show --active | grep -qx "$CON"; then echo "Hotspot: ON"; banner
    else echo "Hotspot: off  (./hotspot.sh on)"; fi
    printf "Server:  %s  (https://%s:%s/ on the current network)\n" "$(systemctl --user is-active vojtechov-vr.service 2>/dev/null)" "$(hostname -I | awk '{print $1}')" "$PORT"
    ;;
esac
