"""Utility script to download and verify YOLO model."""
import sys
import os
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from src.services.yolo_service import YOLOService
from src.utils.logger import get_logger
from config import YOLO_MODEL_FILE, YOLO_MODEL_NAME

logger = get_logger(__name__)


def main():
    """Download YOLO model."""
    print("=" * 50)
    print("YOLO Model Download Utility")
    print("=" * 50)
    print()
    
    # Check if model already exists
    if YOLO_MODEL_FILE.exists():
        print(f"✓ Model already exists at: {YOLO_MODEL_FILE}")
        print(f"  File size: {YOLO_MODEL_FILE.stat().st_size / (1024*1024):.1f} MB")
        return
    
    print(f"Downloading {YOLO_MODEL_NAME} model...")
    print(f"Destination: {YOLO_MODEL_FILE}")
    print()
    
    try:
        # Create YOLO service (will download model automatically)
        yolo_service = YOLOService()
        
        if yolo_service.is_model_loaded():
            print()
            print("✓ Model downloaded and loaded successfully!")
            print(f"  File size: {YOLO_MODEL_FILE.stat().st_size / (1024*1024):.1f} MB")
            print()
            print("The model is ready for object detection.")
        else:
            print("✗ Model failed to load")
            return 1
    
    except Exception as e:
        print(f"✗ Error: {str(e)}")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())
