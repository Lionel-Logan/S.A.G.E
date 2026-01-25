"""
Pydantic models for Face Recognition API
"""
from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime
import config


# ==================== REQUEST MODELS ====================

class RecognizeRequest(BaseModel):
    """Request model for face recognition endpoint"""
    image_base64: str = Field(..., description="Base64 encoded image string")
    threshold: Optional[float] = Field(
        default=config.DEFAULT_THRESHOLD,
        ge=config.MIN_THRESHOLD,
        le=config.MAX_THRESHOLD,
        description="Similarity threshold for face matching (0.3-0.9)"
    )
    
    @validator('image_base64')
    def validate_image_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError("image_base64 cannot be empty")
        return v


class EnrollRequest(BaseModel):
    """Request model for face enrollment endpoint"""
    image_base64: str = Field(..., description="Base64 encoded image string")
    name: str = Field(..., min_length=1, max_length=100, description="Person's name")
    description: str = Field(
        ..., 
        min_length=1, 
        max_length=200, 
        description="Relation or description (e.g., 'Friend', 'Colleague')"
    )
    threshold: Optional[float] = Field(
        default=config.DEFAULT_THRESHOLD,
        ge=config.MIN_THRESHOLD,
        le=config.MAX_THRESHOLD,
        description="Threshold for duplicate detection (0.3-0.9)"
    )
    
    @validator('image_base64')
    def validate_image_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError("image_base64 cannot be empty")
        return v
    
    @validator('name')
    def validate_name(cls, v):
        if not v.strip():
            raise ValueError("name cannot be empty or whitespace")
        return v.strip()
    
    @validator('description')
    def validate_description(cls, v):
        if not v.strip():
            raise ValueError("description cannot be empty or whitespace")
        return v.strip()


# ==================== RESPONSE MODELS ====================

class FaceMatch(BaseModel):
    """Model for a single matched face"""
    name: str = Field(..., description="Name of the recognized person")
    description: str = Field(..., description="Relation or description")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Match confidence score (0-1)")
    bounding_box: List[int] = Field(..., description="Face bounding box [x1, y1, x2, y2]")


class RecognizeResponse(BaseModel):
    """Response model for face recognition endpoint"""
    success: bool = Field(..., description="Whether the operation was successful")
    message: str = Field(..., description="Status message")
    faces_detected: int = Field(..., ge=0, description="Number of faces detected in the image")
    faces: List[FaceMatch] = Field(default=[], description="List of recognized faces")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Response timestamp")
    
    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "message": "Face recognition completed",
                "faces_detected": 2,
                "faces": [
                    {
                        "name": "John Doe",
                        "description": "Friend",
                        "confidence": 0.87,
                        "bounding_box": [100, 150, 300, 400]
                    },
                    {
                        "name": "Jane Smith",
                        "description": "Colleague",
                        "confidence": 0.92,
                        "bounding_box": [400, 150, 600, 400]
                    }
                ],
                "timestamp": "2026-01-25T10:30:00"
            }
        }


class EnrollResponse(BaseModel):
    """Response model for face enrollment endpoint"""
    success: bool = Field(..., description="Whether enrollment was successful")
    message: str = Field(..., description="Status message")
    person_id: Optional[int] = Field(None, description="Database ID of enrolled person")
    name: Optional[str] = Field(None, description="Name of enrolled person")
    confidence: Optional[float] = Field(None, description="Embedding quality confidence")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Response timestamp")
    
    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "message": "Face enrolled successfully",
                "person_id": 13,
                "name": "John Doe",
                "confidence": 0.95,
                "timestamp": "2026-01-25T10:30:00"
            }
        }


class ErrorResponse(BaseModel):
    """Response model for errors"""
    success: bool = Field(default=False, description="Always False for errors")
    error: str = Field(..., description="Error type")
    message: str = Field(..., description="Detailed error message")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Error timestamp")
    
    class Config:
        json_schema_extra = {
            "example": {
                "success": False,
                "error": "ValidationError",
                "message": "Invalid image format",
                "timestamp": "2026-01-25T10:30:00"
            }
        }


class HealthResponse(BaseModel):
    """Response model for health check endpoint"""
    status: str = Field(..., description="Service status")
    service: str = Field(..., description="Service name")
    version: str = Field(..., description="Service version")
    model_loaded: bool = Field(..., description="Whether the model is loaded")
    database_connected: bool = Field(..., description="Whether database is accessible")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Health check timestamp")
