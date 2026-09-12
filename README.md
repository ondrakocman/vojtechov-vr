# Větrný park Vojtěchov – VR

Online: https://ondrakocman.github.io/vojtechov-vr/

## Offline demo (PC hotspot)

The HTTPS server runs permanently on this PC as a systemd user service
(`vojtechov-vr.service`, port 8443, starts at boot – unit file in `local/`).

```bash
./hotspot.sh on      # start Wi-Fi "Vojtechov VR" (PC drops its own Wi-Fi while on)
./hotspot.sh off     # stop hotspot and reconnect the previous Wi-Fi
./hotspot.sh         # status
```

1. On the Quest join Wi-Fi **Vojtechov VR**, password **vojtechov2026**.
2. Open **https://10.42.0.1:8443/** in the Quest browser.
3. Accept the certificate warning once (Advanced → Proceed), then pick a view.

Without the hotspot, a headset on the same Wi-Fi as the PC can use `https://<PC IP>:8443/`
(`./hotspot.sh` prints it). A-Frame is bundled (`aframe/aframe.min.js`) so nothing needs internet.

Server maintenance: `systemctl --user status|restart vojtechov-vr`.
Hotspot is 2.4 GHz (channel 6) – the Intel AX211 refuses AP mode on 5 GHz here.
