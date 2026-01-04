from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from app.models.schemas import FaceRecognitionRequest, FaceRecognitionResponse
from app.services.model_client import FaceRecognitionClient
from app.dependencies import get_current_user
from datetime import datetime

router = APIRouter(prefix="/faces", tags=["Face Recognition"])

@router.post("/recognize", response_model=FaceRecognitionResponse)
async def recognize_faces(
    request: FaceRecognitionRequest,
    current_user = Depends(get_current_user)
):
    """
    Recognize faces in image
    
    Forwards to Nikhil's face recognition server
    Returns list of recognized faces with names and confidence
    """
    try:
        client = FaceRecognitionClient()
        result = await client.recognize_faces(request.image_base64)
        await client.close()
        
        return FaceRecognitionResponse(
            faces=result["faces"],
            timestamp=datetime.utcnow()
        )
    except Exception as e:
        raise HTTPException(500, f"Face recognition failed: {str(e)}")

@router.post("/enroll")
async def enroll_new_face(
    name: str,
    image_base64: str,
    current_user = Depends(get_current_user)
):
    """
    Add a new person to the recognition database
    
    User takes photo → Flutter sends here → Forwarded to Nikhil's server
    """
    # Forward to model server's enrollment endpoint
    pass