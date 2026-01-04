from google.cloud import vision
import base64
from app.config import settings

class OCRService:
    def __init__(self):
        self.client = vision.ImageAnnotatorClient()
    
    async def extract_text(self, image_base64: str) -> str:
        """
        Extract text from image using Google Vision OCR
        
        Returns:
            Extracted text as string
        """
        try:
            image_bytes = base64.b64decode(image_base64)
            image = vision.Image(content=image_bytes)
            
            response = self.client.text_detection(image=image)
            texts = response.text_annotations
            
            if texts:
                return texts[0].description  # Full text
            return ""
        except Exception as e:
            raise Exception(f"OCR error: {str(e)}")