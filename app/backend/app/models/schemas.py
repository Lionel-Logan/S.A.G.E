from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from datetime import datetime

# Auth Schemas
class UserCreate(BaseModel):
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=8)

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

class UserResponse(BaseModel):
    id: int
    email: str
    username: str
    preferred_language: str
    created_at: datetime
    
    class Config:
        from_attributes = True

# Translation Schemas
class TranslationRequest(BaseModel):
    image_base64: str
    source_lang: str = "auto"
    target_lang: str
    
class TranslationResponse(BaseModel):
    original_text: str
    translated_text: str
    confidence: float
    source_lang: str
    target_lang: str

# Face Recognition Schemas
class FaceRecognitionRequest(BaseModel):
    image_base64: str
    
class FaceResult(BaseModel):
    person_id: Optional[str]
    name: Optional[str]
    confidence: float
    bounding_box: List[int]  # [x, y, width, height]

class FaceRecognitionResponse(BaseModel):
    faces: List[FaceResult]
    timestamp: datetime

# Object Detection Schemas
class ObjectDetectionRequest(BaseModel):
    image_base64: str
    confidence_threshold: float = 0.5
    
class DetectedObject(BaseModel):
    label: str
    confidence: float
    bounding_box: List[int]

class ObjectDetectionResponse(BaseModel):
    objects: List[DetectedObject]
    timestamp: datetime

# Assistant Schemas
class AssistantRequest(BaseModel):
    query: str
    context: Optional[str] = None
    
class AssistantResponse(BaseModel):
    response: str
    timestamp: datetime