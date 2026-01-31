# Wake Word Service (Porcupine)

Purpose
- Detects the configured wake-word ("Hey Sage") using a Porcupine `.ppn` model and Picovoice runtime.

Key methods
- `start_listening()` — blocking listen loop calling the configured callback when the wake word is detected.
- `stop_listening()` — stop the loop.

Configuration
- Ensure `PORCUPINE_ACCESS_KEY` is set in `config/voice_config.py`.
- Place your custom `.ppn` wake-word model at `models/hey-sage-wake-up-train.ppn` or update the path in `wake_word_service.py`.

Dependencies & licensing
- `pvporcupine` (Porcupine SDK) and `pyaudio`.
- Porcupine models and SDK usage are subject to Picovoice licensing. Do not distribute licensed `.ppn` files without complying with Picovoice terms.

Troubleshooting
- If Porcupine initialization fails, verify your access key and that the `.ppn` file exists and is compatible with the installed `pvporcupine` version.
