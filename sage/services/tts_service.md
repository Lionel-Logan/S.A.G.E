# TTS Service

Purpose
- Text-to-speech service using `pyttsx3` (espeak) with additional `espeak | aplay` pipeline for reliable audio routing to Bluetooth devices.

Key methods
- `speak(text, blocking)` — speak synchronously (blocking) or asynchronously.
- `stop()` — stop current speech.
- `get_available_voices()` — list system voices and variants.
- `update_config(settings)` — update and persist TTS runtime settings.

Configuration
- Runtime defaults and persistence are in `config/tts_config.py`. Persisted settings write to the configured path when enabled.

Dependencies
- `pyttsx3`, `espeak`, `aplay` (ALSA/PulseAudio), and system PulseAudio/pipewire runtime.

Troubleshooting
- If audio does not route to Bluetooth, ensure the `sage` service has access to the PulseAudio runtime socket (`XDG_RUNTIME_DIR` and `PULSE_SERVER` environment variables) and that `pactl` sees the Bluetooth sink.
