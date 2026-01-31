# services — Service Implementations

This folder contains the service modules used by the Pi server and voice assistant. Each module encapsulates one major capability.

Files
- `camera_service.py` — Photo capture, video recording, MJPEG streaming, upload and storage management.
- `stt_service.py` — Offline speech-to-text (Vosk) with streaming helpers.
- `tts_service.py` — Text-to-speech using `pyttsx3`/`espeak` with robust audio output handling for Bluetooth.
- `wake_word_service.py` — Porcupine-based wake-word detection using a custom `.ppn` model.

How they are used
- `pi_server.py` instantiates `CameraService` and `TTSService` to expose HTTP endpoints.
- `voice_assistant.py` orchestrates `WakeWordService`, `STTService`, and the `AudioManager` to implement the voice flow.

Per-service READMEs are provided for implementation, configuration and troubleshooting details.
