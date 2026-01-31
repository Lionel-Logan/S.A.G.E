# scripts — Deployment and helper scripts

Purpose
- Contains installation scripts, systemd service unit templates, and helper management scripts for deploying SAGE services on a Raspberry Pi.

Key scripts
- `install_voice_assistant.sh` — installer for voice assistant dependencies and service registration.
- `install_pi_server.sh` — installs the FastAPI Pi server as a systemd service.
- `install_ble_service.sh` — installs the BLE GATT server as a systemd service.
- `switch_wifi.sh` — WiFi switching helper used by BLE credential flow.
- Service unit files: `*.service` — templates that assume `/home/sage` and a virtualenv at `/home/sage/sage/venv`.
- Helper scripts: `pi_server.sh`, service manager scripts, and auto-connect helpers.

Usage notes
- Review and adapt paths, usernames and environment variables before running installers. Some scripts must be run as root, while others explicitly require non-root runs — read the header comments.
- Unit files reference `XDG_RUNTIME_DIR` and PulseAudio environment; adjust if your runtime differs.
