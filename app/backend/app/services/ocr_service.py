try:
    from google.cloud import vision
    VISION_AVAILABLE = True
except ImportError:
    VISION_AVAILABLE = False
    vision = None

import io
import os
import base64
from pathlib import Path
from app.config import settings

# Resolve backend root (the directory containing this package)
BACKEND_ROOT = Path(__file__).resolve().parent.parent.parent


class OCRError(Exception):
    """OCR processing error"""
    pass


class OCRService:
    def __init__(self):
        if not VISION_AVAILABLE:
            raise OCRError("Google Cloud Vision is not installed. Install with: pip install google-cloud-vision")
        
        # Resolve credentials path relative to backend root if not absolute
        creds_path = Path(settings.GOOGLE_VISION_CREDENTIALS)
        if not creds_path.is_absolute():
            creds_path = BACKEND_ROOT / creds_path
        
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = str(creds_path)
        
        self.client = vision.ImageAnnotatorClient()

    async def extract_text(self, image_base64: str) -> str:
        try:
            # Decode the base64 string to bytes
            content = base64.b64decode(image_base64)
            image = vision.Image(content=content)

            # Call Google Vision API
            response = self.client.text_detection(image=image)
            texts = response.text_annotations

            if response.error.message:
                raise OCRError(f"Google Vision API Error: {response.error.message}")

            if texts:
                # texts[0] contains the full text block
                return texts[0].description
            return ""
            
        except Exception as e:
            raise OCRError(f"OCR processing failed: {str(e)}")