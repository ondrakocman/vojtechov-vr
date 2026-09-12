# Větrný park Vojtěchov – VR

Online: https://ondrakocman.github.io/vojtechov-vr/

## Offline demo (PC hotspot)

```bash
./serve-local.sh
```

1. On the Quest join Wi-Fi **Vojtechov VR**, password **vojtechov2026**.
2. Open **https://10.42.0.1:8443/** in the Quest browser.
3. Accept the certificate warning once (Advanced → Proceed), then pick a view.

Ctrl+C stops the server, turns the hotspot off and reconnects the PC to its previous Wi-Fi.
`./serve-local.sh --no-ap` serves only (when PC and headset already share a Wi-Fi); the script prints the address.
The A-Frame fallback is bundled (`aframe/aframe.min.js`) so everything works without internet.
