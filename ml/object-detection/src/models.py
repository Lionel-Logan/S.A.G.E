"""Pydantic models for request/response data validation."""
from typing import List, Optional
from pydantic import BaseModel, Field


class BoundingBox(BaseModel):
    """Bounding box coordinates."""
    x: float = Field(..., ge=0, description="X coordinate of top-left corner")
    y: float = Field(..., ge=0, description="Y coordinate of top-left corner")
    width: float = Field(..., gt=0, description="Width of bounding box")
    height: float = Field(..., gt=0, description="Height of bounding box")


class RelativePosition(BaseModel):
    """Relative position of an object in the image."""
    horizontal: str = Field(..., description="Horizontal position: left, center, or right")
    vertical: str = Field(..., description="Vertical position: top, middle, or bottom")


class DetectedObject(BaseModel):
    """A single detected object with metadata."""
    label: str = Field(..., description="Object class label (e.g., 'person', 'car')")
    confidence: float = Field(..., ge=0, le=1, description="Detection confidence score (0-1)")
    position_description: str = Field(..., description="Human-readable position (e.g., 'person on the left side')")
    bounding_box: BoundingBox = Field(..., description="Bounding box coordinates")
    relative_position: RelativePosition = Field(..., description="Relative position in the image")


class DetectionRequest(BaseModel):
    """Request body for object detection."""
    image_base64: str = Field(..., description="Base64-encoded image data")
    confidence_threshold: Optional[float] = Field(
        default=0.5,
        ge=0,
        le=1,
        description="Confidence threshold for detections (0-1)"
    )


class DetectionResponse(BaseModel):
    """Response containing detected objects."""
    status: str = Field(default="success", description="Response status")
    inference_time_ms: float = Field(..., description="Inference time in milliseconds")
    detected_objects: List[DetectedObject] = Field(..., description="List of detected objects")
    total_detections: int = Field(..., description="Total number of objects detected")


class ErrorResponse(BaseModel):
    """Error response."""
    status: str = Field(default="error", description="Error status")
    error_type: str = Field(..., description="Type of error")
    message: str = Field(..., description="Error message")
    details: Optional[str] = Field(default=None, description="Additional error details")
