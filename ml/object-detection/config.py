"""Configuration management for the object detection service."""
import os
from pathlib import Path

# Project paths
BASE_DIR = Path(__file__).parent
MODELS_DIR = BASE_DIR / "models"
SRC_DIR = BASE_DIR / "src"

# Create models directory if it doesn't exist
MODELS_DIR.mkdir(parents=True, exist_ok=True)

# YOLO Model Configuration
YOLO_MODEL_NAME = "yolov8s"
YOLO_MODEL_FILE = MODELS_DIR / f"{YOLO_MODEL_NAME}.pt"
YOLO_MODEL_URL = f"https://github.com/ultralytics/assets/releases/download/v0.0.0/{YOLO_MODEL_NAME}.pt"

# Detection Parameters
DEFAULT_CONFIDENCE_THRESHOLD = 0.5
DEFAULT_IOU_THRESHOLD = 0.45  # Non-Maximum Suppression (NMS) threshold
DEFAULT_IMG_SIZE = 640

# Image Processing
MAX_IMAGE_SIZE_MB = 10
SUPPORTED_IMAGE_FORMATS = {"jpeg", "jpg", "png", "bmp", "webp"}

# API Configuration
API_TITLE = "Object Detection Service"
API_VERSION = "1.0.0"
API_DESCRIPTION = "YOLO-based object detection service with spatial reasoning"
API_PREFIX = "/api/v1"

# Server Configuration
HOST = os.getenv("OD_HOST", "127.0.0.1")
PORT = int(os.getenv("OD_PORT", "8001"))
DEBUG = os.getenv("DEBUG", "False").lower() == "true"

# Spatial Grid Configuration (3x3)
SPATIAL_ZONES = {
    "horizontal": {
        0: "left",      # 0-0.33
        1: "center",    # 0.33-0.66
        2: "right"      # 0.66-1.0
    },
    "vertical": {
        0: "top",       # 0-0.33
        1: "middle",    # 0.33-0.66
        2: "bottom"     # 0.66-1.0
    }
}

# Logging Configuration
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
