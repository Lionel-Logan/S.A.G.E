"""
Configuration file for Face Recognition Service
"""
import os
from pathlib import Path

# Service Configuration
SERVICE_HOST = "0.0.0.0"  # Bind to all interfaces
SERVICE_PORT = 8002  # Different from backend (8000) and Pi (8001)
SERVICE_NAME = "S.A.G.E Face Recognition Service"
SERVICE_VERSION = "1.0.0"

# Model Configuration
INSIGHTFACE_MODEL = "buffalo_l"  # High accuracy model
DETECTION_SIZE = (640, 640)  # Detection resolution
PROVIDERS = ['CPUExecutionProvider']  # Use CPU (change to CUDA if GPU available)

# Face Recognition Settings
DEFAULT_THRESHOLD = 0.5  # Standard threshold for buffalo_l model
MIN_THRESHOLD = 0.3  # Minimum allowed threshold
MAX_THRESHOLD = 0.9  # Maximum allowed threshold

# Database Configuration
SCRIPT_DIR = Path(__file__).parent.absolute()
DB_PATH = SCRIPT_DIR / "models" / "face_data.db"
DB_TABLE = "people"

# Image Processing
MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10MB max image size
SUPPORTED_FORMATS = ['.jpg', '.jpeg', '.png', '.bmp']

# Logging
LOG_LEVEL = "INFO"  # DEBUG, INFO, WARNING, ERROR
LOG_FORMAT = "[%(asctime)s] [%(levelname)s] %(message)s"
LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

# API Response Messages
MSG_NO_FACE_DETECTED = "No face detected in the image"
MSG_MULTIPLE_FACES = "Multiple faces detected. Please provide an image with a single face for enrollment"
MSG_DUPLICATE_FACE = "Face already exists in database"
MSG_ENROLLMENT_SUCCESS = "Face enrolled successfully"
MSG_RECOGNITION_SUCCESS = "Face recognition completed"
MSG_NO_MATCH = "Face not in database"
