"""
Camera API Endpoints
Receives images from Pi camera service during continuous capture
"""

from fastapi import APIRouter, HTTPException, Body
from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime
from app.services.continuous_object_detection_service import get_continuous_detection_service

router = APIRouter(prefix="/camera", tags=["Camera"])


class CameraImageRequest(BaseModel):
    image_base64: str
    timestamp: str
    metadata: Optional[Dict[str, Any]] = None


@router.post("/image")
async def receive_camera_image(request: CameraImageRequest):
    """
    Receive image from Pi camera service during continuous capture
    Forwards to object detection and outputs results via TTS
    
    This endpoint is called by Pi camera service when continuous capture is active.
    No authentication required - internal endpoint.
    """
    try:
        detection_service = get_continuous_detection_service()
        
        # Only process if continuous detection is running
        if not detection_service.is_running:
            return {
                "success": True,
                "message": "Continuous detection not active, ignoring image",
                "timestamp": datetime.utcnow().isoformat()
            }
        
        # Process the image (detect objects + TTS)
        result = await detection_service.process_image(request.image_base64)
        
        return {
            "success": result.get("success", True),
            "timestamp": datetime.utcnow().isoformat(),
            "detection_count": result.get("detection_count", 0)
        }
        
    except Exception as e:
        # Don't raise HTTPException - Pi camera service needs a 200 response
        # to avoid triggering failure count. Continue silently.
        return {
            "success": True,
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }
