# TTS Service (Google Cloud Text-to-Speech)

## Purpose
Text-to-speech service using Google Cloud TTS (Neural2 voices by default).
Synthesised audio is written to a temporary WAV file and played through `aplay`,
preserving the existing Bluetooth/PulseAudio routing.

## Key methods
- `speak(text, blocking)` — speak synchronously or asynchronously.
- `stop()` — immediately kill the active `aplay` subprocess.
- `get_available_voices()` — list Google Cloud TTS voices for the configured language.
- `update_config(settings)` — update and persist runtime settings.
- `save_audio(text, path)` — synthesise to a file without playback.

## Configuration (`config/tts_config.py`)
| Key | Default | Notes |
|-----|---------|-------|
| `GOOGLE_APPLICATION_CREDENTIALS` | `/home/sage/service_account.json` | GCP service account key |
| `GOOGLE_TTS_VOICE_NAME` | `en-US-Neural2-F` | Default voice; overridable via `voice_id` in runtime config |
| `GOOGLE_TTS_LANGUAGE_CODE` | `en-US` | BCP-47 language tag |
| `DEFAULT_VOICE_SPEED` | `175` WPM | Maps to `speaking_rate = speed / 175.0` |
| `DEFAULT_VOICE_VOLUME` | `0.9` | Maps to `volume_gain_db = (vol - 1.0) * 6.0` |

## Dependencies
- `google-cloud-texttospeech>=2.16.0`
- `aplay` (ALSA utils) on the Pi.
- Service account JSON with **Cloud Text-to-Speech API** enabled.

## Troubleshooting
- *AuthError / 403*: enable the Text-to-Speech API in the GCP Console.
- *No audio from Bluetooth*: verify `pactl info` shows the BT sink as default and that `XDG_RUNTIME_DIR`/`PULSE_SERVER` are accessible from the `sage` service user.
