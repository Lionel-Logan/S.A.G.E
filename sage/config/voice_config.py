"""
Configuration for SAGE Voice Assistant
"""

# Voice Assistant Configuration
VOICE_ASSISTANT_NAME = "SAGE Voice Assistant"
VOICE_ASSISTANT_VERSION = "1.0.0"

# Wake Word Configuration
WAKE_WORD = "hey sage"
PORCUPINE_ACCESS_KEY = "MPQU+Qpmxw5HtjxH1x4a6qcKQWKZIW6snoB7D6Lu5P717cT/GXVq4g=="
PORCUPINE_SENSITIVITY = 0.5  # 0.0 to 1.0 (higher = more sensitive, more false positives)

# Audio Configuration
SAMPLE_RATE = 16000  # Hz (standard for speech recognition)
CHANNELS = 1  # Mono
CHUNK_SIZE = 512  # Frames per buffer
AUDIO_FORMAT = "wav"  # File format for recordings

# Recording Configuration
SILENCE_THRESHOLD = 500  # Amplitude threshold for silence detection (adjust based on testing)
SILENCE_DURATION = 2.0  # Seconds of silence before stopping recording
MAX_RECORDING_DURATION = 30  # Maximum recording length in seconds (safety limit)
MIN_RECORDING_DURATION = 0.5  # Minimum recording length in seconds (filter out accidental triggers)

# Audio Tone Files (Placeholders - you will provide these later)
WAKE_TONE_FILE = "/home/sage/audio/wake_tone.wav"  # Played when "Hey Sage" is detected
END_TONE_FILE = "/home/sage/audio/end_tone.wav"  # Played when user stops speaking

# Speech-to-Text Configuration (Vosk)
VOSK_MODEL_PATH = "/home/sage/vosk-model-small-en-us-0.15"  # Download from https://alphacephei.com/vosk/models
VOSK_MODEL_URL = "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"  # Auto-download if missing

# Backend API Configuration
BACKEND_API_URL = "http://localhost:8000/api/v1/assistant/ask"  # Mobile app backend endpoint
# BACKEND_API_URL = "http://192.168.1.100:8000/api/v1/assistant/ask"  # Update with actual backend IP
BACKEND_TIMEOUT = 10  # Seconds to wait for backend response
BACKEND_RETRY_ATTEMPTS = 2  # Number of retry attempts if backend fails

# Logging Configuration
LOG_LEVEL = "INFO"  # DEBUG, INFO, WARNING, ERROR, CRITICAL
LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
LOG_FILE = "/var/log/sage/voice_assistant.log"

# Status File (for monitoring by other services)
STATUS_FILE = "/tmp/sage_voice_status.json"

# PulseAudio Device Configuration
# Based on your system output: alsa_input.usb-Apple__USB.MIC_LTJPXDJ9LD-00.analog-stereo
PULSEAUDIO_SOURCE = "alsa_input.usb-Apple__USB.MIC_LTJPXDJ9LD-00.analog-stereo"
# Set to None to use default microphone
# PULSEAUDIO_SOURCE = None

# Feature Flags
ENABLE_WAKE_TONE = True  # Play tone when wake word detected
ENABLE_END_TONE = True  # Play tone when recording stops
ENABLE_STATUS_FILE = True  # Write status to file for monitoring
ENABLE_LOCAL_LOGGING = True  # Save audio recordings locally for debugging

# Debug Configuration
DEBUG_AUDIO_DIR = "/home/sage/voice_recordings"  # Directory to save recordings for debugging
SAVE_RECORDINGS = False  # Set to True to save all recordings (for testing/debugging)
