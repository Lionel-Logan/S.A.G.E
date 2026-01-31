# SAGE — Raspberry Pi Runtime

This folder contains the Raspberry Pi runtime for the SAGE smartglasses project.

## Overview

- Purpose: BLE pairing & provisioning, Pi HTTP server for camera/tts control, voice-assistant orchestration (wake-word → STT → backend), TTS playback, and Bluetooth audio management.

## Key entry points

- `pi_server.py` — FastAPI server exposing camera, TTS and bluetooth endpoints.
- `voice_assistant.py` — Main voice assistant loop (wake-word → record → STT → backend).
- `ble_gatt_server.py` — BLE GATT server used for WiFi provisioning and pairing with mobile app.

## Main directories

- `config/` — Runtime configuration files for services.
- `services/` — Implementation of `camera`, `stt`, `tts`, and `wake_word` services.
- `utils/` — Low-level helpers: audio, bluetooth, and storage utilities.
- `scripts/` — Installation scripts, systemd unit files and helper utilities for deployment.
- `models/` — Binary models (wake-word `.ppn`, etc.).
- `requirements/` — Python requirements files per component.

## Quickstart (high level)

1. Prepare the Pi: create `sage` user and ensure paths under `/home/sage` exist or update config paths.
2. Install system packages (BlueZ, PulseAudio/PipeWire, ffmpeg, nmcli/wpa_supplicant, python3-dbus, python3-gi).
3. Install Python virtualenv and pip packages from `requirements/`.
4. Download the Vosk model and place it at the path configured in `config/voice_config.py`.
5. Set the Porcupine access key and ensure `models/hey-sage-wake-up-train.ppn` exists.
6. Run the installer scripts in `scripts/` and enable services via `systemctl`.

## Important notes

- Many scripts and unit files assume `/home/sage` and `User=sage`; update paths or run commands as appropriate.
- Audio routing requires PulseAudio/pipewire and correct `XDG_RUNTIME_DIR`/`PULSE_SERVER` environment for systemd services.
- The wake-word `.ppn` model is a binary trained for Picovoice/Porcupine; follow licensing and regeneration instructions if needed.

## Support and troubleshooting

- Missing Vosk model: download from the URL in `config/voice_config.py`.
- Porcupine key: obtain from https://console.picovoice.ai/ and add to `config/voice_config.py` or use the installer prompts.
- Audio not routing to Bluetooth: verify `pactl list` / `wpctl` and that the `sage` user has access to runtime PulseAudio socket.

## Next steps

- See the per-folder READMEs for detailed configuration, service docs and troubleshooting instructions.
