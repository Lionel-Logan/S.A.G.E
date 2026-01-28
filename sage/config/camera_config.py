"""
Configuration for SAGE Pi Camera System
"""

# Camera Hardware
CAMERA_TYPE = "ov5647"  # Pi Camera v1
CAMERA_NAME = "Pi Camera v1 (OV5647)"

# Default Photo Settings
DEFAULT_PHOTO_RESOLUTION = (1920, 1080)  # 1080p
PHOTO_JPEG_QUALITY = 85  # 1-100, 85 is good balance

# Resolution Presets (available in mobile app)
RESOLUTION_PRESETS = {
    "2592x1944": {"width": 2592, "height": 1944, "name": "5MP Max", "video_bitrate": 15000000},
    "1920x1080": {"width": 1920, "height": 1080, "name": "1080p", "video_bitrate": 10000000},
    "1280x720": {"width": 1280, "height": 720, "name": "720p", "video_bitrate": 5000000},
    "640x480": {"width": 640, "height": 480, "name": "480p", "video_bitrate": 2500000},
}

# Configurable Camera Settings (Exposed to Mobile App)
# These are default values - can be changed via /camera/config endpoint
CAMERA_SETTINGS = {
    "resolution": [1920, 1080],           # Default: 1080p
    "shutter_speed_us": 0,                # 0 = auto, otherwise 1-6000000 microseconds
    "iso": 0,                             # 0 = auto, otherwise 100-800
    "brightness": 0.0,                    # -1.0 to 1.0
    "contrast": 1.0,                      # 0.0 to 2.0
    "sharpness": 1.0,                     # 0.0 to 2.0
}

# Continuous Capture Settings
CONTINUOUS_INTERVAL_SECONDS = 2.0       # Default interval between captures
CONTINUOUS_MAX_FAILURES = 5             # Stop after N consecutive backend failures

# Video Recording Settings
VIDEO_DEFAULT_FPS = 30
VIDEO_MAX_DURATION = 120                # 2 minutes max
VIDEO_STORAGE_PATH = "/home/sage/.sage/videos"
VIDEO_MAX_STORAGE_MB = 1000             # Max 1 GB for videos
VIDEO_AUTO_DELETE_AFTER_UPLOAD = True   # Delete after successful upload
VIDEO_KEEP_LAST_N = 5                   # Keep last 5 videos as backup

# MJPEG Streaming Settings (for live preview)
STREAM_JPEG_QUALITY = 70                # Lower quality for faster streaming
STREAM_FPS = 20                         # Target FPS for preview stream

# Backend Communication
BACKEND_BASE_URL = "http://localhost:8000"  # Update with actual backend IP
BACKEND_IMAGE_ENDPOINT = "/api/v1/camera/image"
BACKEND_VIDEO_ENDPOINT = "/api/v1/camera/video"
BACKEND_TIMEOUT = 30                    # Seconds to wait for backend response

# Local Storage
IMAGE_STORAGE_PATH = "/home/sage/.sage/camera_images"
IMAGE_KEEP_LAST_N = 10                  # Keep last 10 images for debugging
CONFIG_STORAGE_PATH = "/home/sage/.sage/camera_config.json"

# Logging
CAMERA_LOG_LEVEL = "INFO"
