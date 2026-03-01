# STT Service (Google Cloud Speech-to-Text)

## Purpose
Provides speech-to-text using Google Cloud Speech-to-Text API (batch mode).
Audio is recorded locally and sent as a single request after recording completes.

## Key methods
- `reset_recognizer()` — clear the internal audio buffer before a new recording session.
- `process_audio_chunk(chunk)` — accumulate a raw PCM chunk into the buffer; always returns `(None, False)`.
- `get_final_result()` — concatenate the buffer and send one `SpeechClient.recognize()` call; returns the transcript string.
- `transcribe_audio_bytes(bytes)` — one-shot transcription from raw bytes.
- `transcribe_audio_file(path)` — one-shot transcription from a WAV file.

## Configuration (`config/voice_config.py`)
| Key | Default | Notes |
|-----|---------|-------|
| `GOOGLE_APPLICATION_CREDENTIALS` | `/home/sage/service_account.json` | GCP service account key |
| `GOOGLE_STT_LANGUAGE_CODE` | `en-US` | BCP-47 language tag |
| `GOOGLE_STT_MODEL` | `command_and_search` | Optimised for short voice commands |
| `GOOGLE_STT_MAX_ALTERNATIVES` | `1` | Number of transcript alternatives |
| `SAMPLE_RATE` | `16000` | Must match `AudioManager` recording rate |

## Dependencies
- `google-cloud-speech>=2.21.0`
- Service account JSON at the configured path with **Speech-to-Text API** enabled.

## Troubleshooting
- *AuthError / 403*: ensure the Speech-to-Text API is enabled in the Google Cloud Console for the service account's project.
- *Empty transcript*: check that audio is being recorded at 16 kHz mono; increase `SILENCE_THRESHOLD` if the microphone is too sensitive.
