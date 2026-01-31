# Camera Service

Purpose
- Manages Pi camera operations: single photo capture, continuous capture, video recording, MJPEG streaming, and upload to backend.

Key methods / endpoints
- `capture_photo()` → returns JPEG bytes (exposed at `/camera/capture_photo`).
- `capture_photo_base64()` → returns base64 JSON (exposed at `/camera/capture_photo_base64`).
- `start_continuous_capture(interval)` and `stop_continuous_capture()`.
- `start_video_recording(max_duration)` and `stop_video_recording(send_to_backend)`.
- `stream_mjpeg()` → async generator used by `/camera/stream` endpoint.

Configuration
- See `config/camera_config.py` for resolution presets, storage paths, backend endpoints and streaming parameters.
- Ensure `VIDEO_STORAGE_PATH` and `IMAGE_STORAGE_PATH` exist and are writable by the `sage` user.

Dependencies
- `picamera2`, `Pillow`, `ffmpeg`, `requests`.

Troubleshooting
- ffmpeg conversion failure: install `ffmpeg` (`sudo apt install ffmpeg`).
- Camera not found: ensure camera interface is enabled (raspi-config) and that the current user has permission to access the device.
