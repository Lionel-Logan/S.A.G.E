from google.cloud import vision
import io
import os
import base64
from app.core.exceptions import OCRError
from app.config import settings

# Explicitly tell Google where the key is
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = settings.GOOGLE_VISION_CREDENTIALS

class OCRService:
    def __init__(self):
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