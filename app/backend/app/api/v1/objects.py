from fastapi import APIRouter, Depends, HTTPException
from app.models.schemas import ObjectDetectionRequest, ObjectDetectionResponse
from app.services.model_client import ObjectDetectionClient
from app.dependencies import get_current_user
from datetime import datetime

router = APIRouter(prefix="/objects", tags=["Object Detection"])

@router.post("/detect", response_model=ObjectDetectionResponse)
async def detect_objects(
    request: ObjectDetectionRequest,
    current_user = Depends(get_current_user)
):
    """
    Detect objects in image
    
    Called when user says "Hey Glass, start scanning environment"
    Pi samples frames → Flutter sends here → Forwarded to Ananya's server
    """
    try:
        client = ObjectDetectionClient()
        result = await client.detect_objects(
            request.image_base64,
            request.confidence_threshold
        )
        await client.close()
        
        return ObjectDetectionResponse(
            objects=result["objects"],
            timestamp=datetime.utcnow()
        )
    except Exception as e:
        raise HTTPException(500, f"Object detection failed: {str(e)}")

        