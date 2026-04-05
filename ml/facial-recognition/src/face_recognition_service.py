"""
S.A.G.E Face Recognition Service
FastAPI server for face recognition and enrollment
"""
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import logging
import uvicorn
from datetime import datetime

# Import configurations and models
import config
from api_models import (
    RecognizeRequest, RecognizeResponse, FaceMatch,
    EnrollRequest, EnrollResponse,
    ErrorResponse, HealthResponse,
    PersonRecord, ListPeopleResponse, DeletePersonResponse,
    UpdatePersonRequest, UpdatePersonResponse
)
import asyncio
from face_matcher import FaceMatcher, FaceMatcherError
from utils.image_utils import decode_base64_image, validate_image, preprocess_image, ImageProcessingError

# Configure logging
logging.basicConfig(
    level=getattr(logging, config.LOG_LEVEL),
    format=config.LOG_FORMAT,
    datefmt=config.LOG_DATE_FORMAT
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title=config.SERVICE_NAME,
    version=config.SERVICE_VERSION,
    description="Face recognition and enrollment service for S.A.G.E smartglasses",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global face matcher instance (None while model is still loading)
face_matcher: FaceMatcher = None


def _require_model():
    """Raise 503 if the model hasn't finished loading yet."""
    if face_matcher is None:
        raise HTTPException(
            status_code=503,
            detail="Model is still loading — please retry in a few seconds"
        )


# ==================== STARTUP/SHUTDOWN EVENTS ====================

@app.on_event("startup")
async def startup_event():
    """Bind the port immediately, then load the model in a background thread.

    Render (and other PaaS) scan for an open port immediately after the
    process starts.  If model loading blocks the event loop the port never
    opens in time and the deploy fails with "No open ports detected".
    Loading in run_in_executor releases the event loop so uvicorn can accept
    connections while the model is still initialising.
    """
    global face_matcher
    logger.info("=" * 60)
    logger.info(f"Starting {config.SERVICE_NAME} v{config.SERVICE_VERSION}")
    logger.info("=" * 60)
    logger.info("Port bound — loading InsightFace model in background thread...")

    loop = asyncio.get_event_loop()

    async def _load_model():
        global face_matcher
        try:
            fm = await loop.run_in_executor(None, FaceMatcher)
            face_matcher = fm
            stats = face_matcher.get_database_stats()
            logger.info(f"Database: {stats['total_faces']} faces registered")
            logger.info("=" * 60)
            logger.info(f"✓ Service ready on http://{config.SERVICE_HOST}:{config.SERVICE_PORT}")
            logger.info(f"✓ API Docs: http://{config.SERVICE_HOST}:{config.SERVICE_PORT}/docs")
            logger.info("=" * 60)
        except Exception as e:
            logger.error(f"Failed to load model: {str(e)}", exc_info=True)

    asyncio.create_task(_load_model())


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down Face Recognition Service...")


# ==================== EXCEPTION HANDLERS ====================

@app.exception_handler(ImageProcessingError)
async def image_processing_exception_handler(request: Request, exc: ImageProcessingError):
    """Handle image processing errors"""
    logger.error(f"Image processing error: {str(exc)}")
    return JSONResponse(
        status_code=400,
        content=ErrorResponse(
            error="ImageProcessingError",
            message=str(exc),
            timestamp=datetime.utcnow()
        ).dict()
    )


@app.exception_handler(FaceMatcherError)
async def face_matcher_exception_handler(request: Request, exc: FaceMatcherError):
    """Handle face matcher errors"""
    logger.error(f"Face matcher error: {str(exc)}")
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error="FaceMatcherError",
            message=str(exc),
            timestamp=datetime.utcnow()
        ).dict()
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle all other exceptions"""
    logger.error(f"Unexpected error: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error="InternalServerError",
            message="An unexpected error occurred",
            timestamp=datetime.utcnow()
        ).dict()
    )


# ==================== API ENDPOINTS ====================

@app.get("/", response_model=dict)
async def root():
    """Root endpoint"""
    return {
        "service": config.SERVICE_NAME,
        "version": config.SERVICE_VERSION,
        "status": "running",
        "endpoints": {
            "ping": "/ping",
            "health": "/health",
            "recognize": "/recognize",
            "enroll": "/enroll",
            "people_list": "GET /people",
            "people_update": "PUT /people/{person_id}",
            "people_delete": "DELETE /people/{person_id}",
            "stats": "/stats",
            "docs": "/docs"
        }
    }


@app.get("/ping")
async def ping():
    """
    Lightweight keep-alive endpoint (no model inference).
    Used by UptimeRobot every 5 minutes to prevent Render free-tier spin-down.
    """
    return {"status": "ok"}


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    is_healthy = face_matcher.is_healthy() if face_matcher else False
    stats = face_matcher.get_database_stats() if face_matcher else {"total_faces": 0}
    
    return HealthResponse(
        status="healthy" if is_healthy else "unhealthy",
        service=config.SERVICE_NAME,
        version=config.SERVICE_VERSION,
        model_loaded=face_matcher is not None and face_matcher.model is not None,
        database_connected=is_healthy,
        timestamp=datetime.utcnow()
    )


@app.post("/recognize", response_model=RecognizeResponse)
async def recognize_faces(request: RecognizeRequest):
    """
    Recognize faces in an image
    
    - Detects all faces in the image
    - Matches each face against the database
    - Returns list of recognized faces with names, descriptions, and confidence scores
    - Returns "Unknown" for faces not in database
    """
    _require_model()
    logger.info(f"POST /recognize - threshold: {request.threshold}")
    
    try:
        # Decode image
        image = decode_base64_image(request.image_base64)
        
        # Validate image
        is_valid, error_msg = validate_image(image)
        if not is_valid:
            raise ImageProcessingError(error_msg)
        
        # Preprocess image
        image = preprocess_image(image)
        
        # Recognize faces
        result = face_matcher.recognize_faces(image, request.threshold)
        
        # Build response
        if result["faces_detected"] == 0:
            return RecognizeResponse(
                success=True,
                message=config.MSG_NO_FACE_DETECTED,
                faces_detected=0,
                faces=[],
                timestamp=datetime.utcnow()
            )
        
        # Convert to FaceMatch objects
        face_matches = [
            FaceMatch(
                name=face["name"],
                description=face["description"],
                confidence=face["confidence"],
                bounding_box=face["bounding_box"]
            )
            for face in result["faces"]
        ]
        
        # Count recognized vs unknown faces
        recognized_count = sum(1 for face in result["faces"] if face["name"] != "Unknown")
        
        message = config.MSG_RECOGNITION_SUCCESS
        if recognized_count == 0:
            message = config.MSG_NO_MATCH
        elif recognized_count < result["faces_detected"]:
            message = f"Recognized {recognized_count} of {result['faces_detected']} faces"
        
        logger.info(f"✓ Recognized {recognized_count}/{result['faces_detected']} faces")
        
        return RecognizeResponse(
            success=True,
            message=message,
            faces_detected=result["faces_detected"],
            faces=face_matches,
            timestamp=datetime.utcnow()
        )
        
    except ImageProcessingError:
        raise
    except FaceMatcherError:
        raise
    except Exception as e:
        logger.error(f"Recognition failed: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/enroll", response_model=EnrollResponse)
async def enroll_face(request: EnrollRequest):
    """
    Enroll a new face into the database
    
    - Only accepts images with a single face
    - Checks for duplicates before enrolling
    - Returns error if multiple faces or duplicate detected
    - Saves face embedding with name and description (relation)
    """
    _require_model()
    logger.info(f"POST /enroll - name: {request.name}, threshold: {request.threshold}")
    
    try:
        # Decode image
        image = decode_base64_image(request.image_base64)
        
        # Validate image
        is_valid, error_msg = validate_image(image)
        if not is_valid:
            raise ImageProcessingError(error_msg)
        
        # Preprocess image
        image = preprocess_image(image)
        
        # Enroll face
        result = face_matcher.enroll_face(
            image,
            request.name,
            request.description,
            request.threshold
        )
        
        # Build response
        if not result["success"]:
            logger.warning(f"Enrollment failed: {result['message']}")
            return EnrollResponse(
                success=False,
                message=result["message"],
                timestamp=datetime.utcnow()
            )
        
        logger.info(f"✓ Enrolled {request.name} (ID: {result['person_id']})")
        
        return EnrollResponse(
            success=True,
            message=result["message"],
            person_id=result["person_id"],
            name=request.name,
            confidence=result["confidence"],
            timestamp=datetime.utcnow()
        )
        
    except ImageProcessingError:
        raise
    except FaceMatcherError:
        raise
    except Exception as e:
        logger.error(f"Enrollment failed: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/people", response_model=ListPeopleResponse)
async def list_people():
    """
    List all registered people in the database

    - Returns id, name, and description for every enrolled person
    - App uses the returned id to identify who to delete
    - Returns an empty list (not an error) when no one is enrolled
    """
    _require_model()
    logger.info("GET /people")
    try:
        people = face_matcher.list_people()
        return ListPeopleResponse(
            success=True,
            total=len(people),
            people=[PersonRecord(**p) for p in people],
            timestamp=datetime.utcnow()
        )
    except FaceMatcherError:
        raise
    except Exception as e:
        logger.error(f"Failed to list people: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/people/{person_id}", response_model=DeletePersonResponse)
async def delete_person(person_id: int):
    """
    Delete a registered person from the database by their ID

    - The ID comes from the GET /people response
    - Returns 404 if no person with that ID exists
    - Permanently removes the face embedding from the database
    """
    _require_model()
    logger.info(f"DELETE /people/{person_id}")
    try:
        deleted = face_matcher.delete_person_by_id(person_id)

        if not deleted:
            raise HTTPException(
                status_code=404,
                detail=f"No person found with ID {person_id}"
            )

        logger.info(f"✓ Deleted person ID {person_id}")
        return DeletePersonResponse(
            success=True,
            message=f"Person with ID {person_id} deleted successfully",
            person_id=person_id,
            timestamp=datetime.utcnow()
        )
    except HTTPException:
        raise
    except FaceMatcherError:
        raise
    except Exception as e:
        logger.error(f"Deletion failed: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/people/{person_id}", response_model=UpdatePersonResponse)
async def update_person(person_id: int, request: UpdatePersonRequest):
    """
    Update the name and description of a registered person

    - Identified by person_id from the GET /people response
    - Both name and description must be provided (pre-fill from existing values)
    - Returns 404 if no person with that ID exists
    - Face embedding is unchanged — only metadata is updated
    """
    _require_model()
    logger.info(f"PUT /people/{person_id} - name: {request.name}, description: {request.description}")
    try:
        updated = face_matcher.update_person_by_id(person_id, request.name, request.description)

        if not updated:
            raise HTTPException(
                status_code=404,
                detail=f"No person found with ID {person_id}"
            )

        logger.info(f"✓ Updated person ID {person_id}")
        return UpdatePersonResponse(
            success=True,
            message=f"Person with ID {person_id} updated successfully",
            person_id=person_id,
            name=request.name,
            description=request.description,
            timestamp=datetime.utcnow()
        )
    except HTTPException:
        raise
    except FaceMatcherError:
        raise
    except Exception as e:
        logger.error(f"Update failed: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/stats")
async def get_stats():
    """Get database statistics"""
    _require_model()
    stats = face_matcher.get_database_stats()
    return {
        "total_faces": stats["total_faces"],
        "registered_names": stats["names"],
        "timestamp": datetime.utcnow()
    }


# ==================== MAIN ====================

if __name__ == "__main__":
    uvicorn.run(
        "face_recognition_service:app",
        host=config.SERVICE_HOST,
        port=config.SERVICE_PORT,
        reload=False,  # Set to True for development
        log_level=config.LOG_LEVEL.lower()
    )
