# STT Service (Vosk)

Purpose
- Provides offline speech-to-text functionality using the Vosk library and a downloaded model.

Key methods
- `process_audio_chunk(audio_chunk)` — streaming transcription, returns (partial_text, is_final).
- `get_final_result()` — finalize and return final transcribed text.
- `transcribe_audio_bytes(bytes)` and `transcribe_audio_file(path)`.

Configuration
- `config/voice_config.py` contains `VOSK_MODEL_PATH` and `VOSK_MODEL_URL`.
- Download and extract the Vosk model to the configured `VOSK_MODEL_PATH` before starting the voice assistant.

Dependencies
- `vosk` Python package and the corresponding model files.

Troubleshooting
- Model not found: follow the URL in `voice_config.py` to download and extract the model.
- Sample-rate mismatch: ensure `AudioManager` records at the configured `SAMPLE_RATE`.
