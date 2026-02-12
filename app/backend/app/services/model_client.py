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
    
    async def recognize_faces(self, image_base64: str, threshold: float = 0.5) -> Dict[str, Any]:
        """
        Send image to face recognition server for recognition
        
        Expected response:
        {
            "success": true,
            "faces_detected": 2,
            "faces": [
                {
                    "name": "John Doe",
                    "description": "Friend",
                    "confidence": 0.95,
                    "bounding_box": [x, y, w, h]
                }
            ]
        }
        """
        try:
            response = await self.client.post(
                f"{self.base_url}/recognize",
                json={
                    "image_base64": image_base64,
                    "threshold": threshold
                },
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as e:
            raise ModelServerError(f"Face recognition server error: {str(e)}")
    
    async def enroll_face(self, name: str, image_base64: str, description: str = "Person", threshold: float = 0.5) -> Dict[str, Any]:
        """
        Enroll a new face into the database
        
        Expected response:
        {
            "success": true,
            "message": "Face enrolled successfully",
            "face_id": "uuid"
        }
        """
        try:
            # Ensure description is not empty (ML server requires min_length=1)
            if not description or not description.strip():
                description = "Person"
            
            response = await self.client.post(
                f"{self.base_url}/enroll",
                json={
                    "name": name,
                    "description": description,
                    "image_base64": image_base64,
                    "threshold": threshold
                },
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as e:
            raise ModelServerError(f"Face enrollment server error: {str(e)}")

class ObjectDetectionClient(ModelClient):
    """Client for Ananya's object detection server"""
    
    def __init__(self):
        super().__init__(settings.OBJECT_DETECTION_URL, settings.MODEL_REQUEST_TIMEOUT)
    
    async def detect_objects(self, image_base64: str, confidence_threshold: float = 0.5) -> Dict[str, Any]:
        """
        Send image to object detection server (Ananya's YOLO service)
        
        Expected response:
        {
            "status": "success",
            "inference_time_ms": 45.23,
            "detected_objects": [
                {
                    "label": "person",
                    "confidence": 0.95,
                    "position_description": "person on the left side",
                    "bounding_box": {...},
                    "relative_position": {...}
                }
            ],
            "total_detections": 2
        }
        """
        try:
            response = await self.client.post(
                f"{self.base_url}/api/v1/objects/detect",
                json={
                    "image_base64": image_base64,
                    "confidence_threshold": confidence_threshold
                },
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as e:
            raise ModelServerError(f"Object detection server error: {str(e)}")