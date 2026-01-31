# requirements — Dependency manifests

Purpose
- Contains `requirements.txt` variants for voice, camera and combined installs to make deployment reproducible.

Files
- `requirements-voice.txt` — dependencies for `voice_assistant.py` (Vosk, Porcupine bindings, pyaudio, etc.).
- `requirements-camera.txt` — dependencies for camera features (`picamera2`, `Pillow`, etc.).
- `requirements.txt` — project-level requirements (if present).

Installation example
```bash
python3 -m venv ~/sage/venv
source ~/sage/venv/bin/activate
pip install -r sage/requirements/requirements-voice.txt
pip install -r sage/requirements/requirements-camera.txt
```

Notes
- Installing voice and camera requirements on Raspberry Pi may require system packages (portaudio, libasound2-dev, build tools).
