#!/bin/bash
# Offline demo: start a Wi-Fi hotspot on this PC and serve the site over HTTPS.
#
#   ./serve-local.sh            hotspot + server (Ctrl+C stops both and reconnects Wi-Fi)
#   ./serve-local.sh --no-ap    server only (PC already on the same Wi-Fi as the headset)
#
# On the Quest: join Wi-Fi "Vojtechov VR" (password below), open https://10.42.0.1:8443/
# and accept the certificate warning once (Advanced -> Proceed).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SSID="Vojtechov VR"
PASS="vojtechov2026"
CON="vojtechov-vr-hotspot"
IFACE="$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')"
PORT=8443
AP_IP="10.42.0.1"
CERTS="$HERE/local/certs"

# --- certificate (self-signed, 10 years, valid for the hotspot IP) ---------------------
if [ ! -f "$CERTS/cert.pem" ]; then
  mkdir -p "$CERTS"
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$CERTS/key.pem" -out "$CERTS/cert.pem" \
    -subj "/CN=Vojtechov VR" \
    -addext "subjectAltName=IP:$AP_IP,IP:127.0.0.1,DNS:localhost" >/dev/null 2>&1
  echo "Certificate created in $CERTS"
fi

USE_AP=1
[ "${1:-}" = "--no-ap" ] && USE_AP=0

PREV_CON=""
if [ $USE_AP -eq 1 ]; then
  [ -z "$IFACE" ] && { echo "No Wi-Fi interface found."; exit 1; }
  PREV_CON="$(nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v d="$IFACE" '$2==d{print $1; exit}')"
  if ! nmcli -t -f NAME connection show | grep -qx "$CON"; then
    nmcli connection add type wifi ifname "$IFACE" con-name "$CON" autoconnect no ssid "$SSID" \
      -- 802-11-wireless.mode ap 802-11-wireless.band a ipv4.method shared ipv6.method disabled \
      wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PASS" >/dev/null || exit 1
  fi
  echo "Starting hotspot \"$SSID\" on $IFACE (this disconnects: ${PREV_CON:-nothing}) ..."
  nmcli connection up "$CON" >/dev/null || { echo "Hotspot failed to start."; exit 1; }
  URL="https://$AP_IP:$PORT/"
else
  IP="$(hostname -I | awk '{print $1}')"
  URL="https://$IP:$PORT/"
fi

cleanup(){
  echo
  if [ $USE_AP -eq 1 ]; then
    nmcli connection down "$CON" >/dev/null 2>&1
    [ -n "$PREV_CON" ] && nmcli connection up "$PREV_CON" >/dev/null 2>&1 && echo "Reconnected to $PREV_CON."
  fi
}
trap cleanup EXIT INT TERM

echo
echo "================================================================"
[ $USE_AP -eq 1 ] && printf "  Wi-Fi:     %s\n  Password:  %s\n" "$SSID" "$PASS"
printf "  Open:      %s\n" "$URL"
echo "  (accept the certificate warning once: Advanced -> Proceed)"
echo "  Ctrl+C to stop."
echo "================================================================"
echo
python3 "$HERE/local/serve.py" --port "$PORT" --root "$HERE"
