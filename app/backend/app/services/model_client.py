import httpx
import base64
from typing import Dict, Any
from app.config import settings
from app.core.exceptions import ModelServerError

class ModelClient:
    """Base client for communicating with model servers"""
    
    def __init__(self, base_url: str, timeout: int = 30):
        self.base_url = base_url
        self.timeout = timeout
        self.client = httpx.AsyncClient(timeout=timeout)
    
    async def close(self):
        await self.client.aclose()
    
    async def health_check(self) -> bool:
        """Check if model server is responsive"""
        try:
            response = await self.client.get(f"{self.base_url}/health")
            return response.status_code == 200
        except Exception:
            return False

class FaceRecognitionClient(ModelClient):
    """Client for Nikhil's face recognition server"""
    
    def __init__(self):
        super().__init__(settings.FACE_RECOGNITION_URL, settings.MODEL_REQUEST_TIMEOUT)
    
    async def recognize_faces(self, image_base64: str) -> Dict[str, Any]:
        """
        Send image to face recognition server
        
        Expected response:
        {
            "faces": [
                {
                    "person_id": "john_doe",
                    "name": "John Doe",
                    "confidence": 0.95,
                    "bounding_box": [100, 150, 200, 250]
                }
            ]
        }
        """
        try:
            response = await self.client.post(
                f"{self.base_url}/recognize",
                json={"image": image_base64},
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as e:
            raise ModelServerError(f"Face recognition server error: {str(e)}")

class ObjectDetectionClient(ModelClient):
    """Client for Ananya's object detection server"""
    
    def __init__(self):
        super().__init__(settings.OBJECT_DETECTION_URL, settings.MODEL_REQUEST_TIMEOUT)
    
    async def detect_objects(self, image_base64: str, confidence_threshold: float = 0.5) -> Dict[str, Any]:
        """
        Send image to object detection server
        
        Expected response:
        {
            "objects": [
                {
                    "label": "person",
                    "confidence": 0.92,
                    "bounding_box": [50, 100, 300, 400]
                }
            ]
        }
        """
        try:
            response = await self.client.post(
                f"{self.base_url}/detect",
                json={
                    "image": image_base64,
                    "confidence_threshold": confidence_threshold
                },
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as e:
            raise ModelServerError(f"Object detection server error: {str(e)}")