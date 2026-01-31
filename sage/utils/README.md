# utils — Utilities

Purpose
- Low-level utilities used across services for audio I/O, Bluetooth management, and local storage.

Files
- `audio_manager.py` — Recording, playback, TTS locking and silence detection.
- `bluetooth_manager.py` — Device scanning, pairing, connection management and sink selection (uses `bluetoothctl`, `pactl` / `wpctl`).
- `image_storage.py` — Local image and video storage helpers and cleanup policies.

Notes
- `AudioManager` provides a class-level lock to prevent TTS and microphone conflicts — respect that when integrating custom audio code.
- `BluetoothManager` relies on system CLI tools and expects PulseAudio/pipewire compatibility layers.
