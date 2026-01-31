# config — Runtime Configuration

This folder contains configuration files used by the Pi services. Edit these files to change runtime behavior, file locations, and external endpoints.

Files
- `camera_config.py` — Camera defaults, storage paths, streaming and backend parameters.
- `pi_server_config.py` — FastAPI server metadata, logging, and CORS settings.
- `tts_config.py` — TTS runtime settings and persistence for voice preferences.
- `voice_config.py` — Voice assistant settings: wake-word, Vosk model path, backend API, audio parameters.

What to update
- Adjust absolute paths (for example `/home/sage/...` or `/var/log/sage`) if your deployment uses a different user or layout.
- Update `BACKEND` URLs to point to your mobile/backend services.
- Configure `VOSK_MODEL_PATH` and `PORCUPINE_ACCESS_KEY` before starting voice assistant services.

Persistence and safety
- `tts_config.py` may persist runtime TTS changes to disk. Ensure the configured directories are writable by the service user.
