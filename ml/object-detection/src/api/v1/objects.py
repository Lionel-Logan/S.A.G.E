"""Object detection API endpoints."""
import time
from fastapi import APIRouter, HTTPException
from starlette.requests import Request

from src.models import DetectionRequest, DetectionResponse, ErrorResponse
from src.exceptions import ObjectDetectionException
from src.utils.logger import get_logger

logger = get_logger(__name__)

router = APIRouter(prefix="/objects", tags=["detection"])


@router.post(
    "/detect",
    response_model=DetectionResponse,
    responses={
        400: {"model": ErrorResponse, "description": "Bad Request"},
        422: {"model": ErrorResponse, "description": "Validation Error"},
        500: {"model": ErrorResponse, "description": "Internal Server Error"}
    }
)
async def detect_objects(request: Request, detection_request: DetectionRequest):
    """Detect objects in a Base64-encoded image.
    
    This endpoint accepts a Base64-encoded image and returns detected objects
    with their labels and relative spatial positions.
    
    Args:
        detection_request: Request body containing Base64 image and optional confidence threshold
        
    Returns:
        DetectionResponse with detected objects and inference time
        
    Raises:
        HTTPException: If detection fails
    """
    logger.info("Received object detection request")
    
    try:
        # Get detection service from app state
        detection_service = request.app.state.detection_service
        
        # Run detection
        start_time = time.time()
        detected_objects = detection_service.detect_objects(
            image_base64=detection_request.image_base64,
            confidence_threshold=detection_request.confidence_threshold
        )
        inference_time_ms = (time.time() - start_time) * 1000
        
        # Create response
        response = DetectionResponse(
            status="success",
            inference_time_ms=round(inference_time_ms, 2),
            detected_objects=detected_objects,
            total_detections=len(detected_objects)
        )
        
        logger.info(f"Detection request completed: {len(detected_objects)} objects detected")
        return response
        
    except ObjectDetectionException as e:
        logger.error(f"Detection error: {type(e).__name__}: {str(e)}")
        
        # Return appropriate HTTP status based on exception type
        status_code = 400
        error_type = type(e).__name__
        
        raise HTTPException(
            status_code=status_code,
            detail={
                "status": "error",
                "error_type": error_type,
                "message": str(e)
            }
        )
    
    except Exception as e:
        logger.error(f"Unexpected error during detection: {type(e).__name__}: {str(e)}")
        
        raise HTTPException(
            status_code=500,
            detail={
                "status": "error",
                "error_type": "InternalServerError",
                "message": "An unexpected error occurred during object detection"
            }
        )


@router.get("/health")
async def health_check(request: Request):
    """Health check endpoint.
    
    Returns:
        Health status and model information
    """
    yolo_service = request.app.state.yolo_service
    model_loaded = yolo_service.is_model_loaded()
    
    status = "healthy" if model_loaded else "unhealthy"
    status_code = 200 if model_loaded else 503
    
    return {
        "status": status,
        "model_loaded": model_loaded,
        "model_name": "yolov8s"
    }
