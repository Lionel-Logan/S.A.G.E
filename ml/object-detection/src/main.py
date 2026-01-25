"""FastAPI application factory and configuration."""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.services.yolo_service import YOLOService
from src.services.detection_service import DetectionService
from src.api.v1 import objects
from src.utils.logger import get_logger
from config import API_TITLE, API_VERSION, API_DESCRIPTION, API_PREFIX, DEBUG

logger = get_logger(__name__)

# Global service instances
yolo_service: YOLOService = None
detection_service: DetectionService = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan context manager for startup and shutdown events.
    
    Handles:
    - Loading YOLO model on startup
    - Cleanup on shutdown
    """
    # Startup
    logger.info("=== Object Detection Service Starting ===")
    
    try:
        global yolo_service, detection_service
        
        logger.info("Initializing YOLO service...")
        yolo_service = YOLOService()
        
        logger.info("Initializing Detection service...")
        detection_service = DetectionService(yolo_service)
        
        # Store in app state for route access
        app.state.yolo_service = yolo_service
        app.state.detection_service = detection_service
        
        logger.info("✓ All services initialized successfully")
        
    except Exception as e:
        logger.error(f"Failed to initialize services: {str(e)}")
        raise
    
    yield
    
    # Shutdown
    logger.info("=== Object Detection Service Shutting Down ===")
    logger.info("Cleanup completed")


def create_app() -> FastAPI:
    """Create and configure FastAPI application.
    
    Returns:
        Configured FastAPI application instance
    """
    logger.info("Creating FastAPI application")
    
    # Create app with lifespan
    app = FastAPI(
        title=API_TITLE,
        version=API_VERSION,
        description=API_DESCRIPTION,
        debug=DEBUG,
        lifespan=lifespan
    )
    
    # Add CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # Allow all origins for local development
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    # Include API routes
    app.include_router(objects.router, prefix=API_PREFIX)
    
    # Root endpoint
    @app.get("/", tags=["info"])
    async def root():
        """Root endpoint with API information."""
        return {
            "name": API_TITLE,
            "version": API_VERSION,
            "description": API_DESCRIPTION,
            "endpoints": {
                "detect": f"POST {API_PREFIX}/objects/detect",
                "health": f"GET {API_PREFIX}/objects/health",
                "docs": "/docs",
                "openapi": "/openapi.json"
            }
        }
    
    logger.info("FastAPI application created successfully")
    
    return app


# Create application instance
app = create_app()

if __name__ == "__main__":
    import uvicorn
    from config import HOST, PORT
    
    logger.info(f"Starting server on {HOST}:{PORT}")
    uvicorn.run(
        "src.main:app",
        host=HOST,
        port=PORT,
        reload=DEBUG
    )
