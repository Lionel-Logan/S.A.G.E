from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.config import settings
from app.api.v1 import  translation, faces, objects, assistant, camera, location
from app.core.tts_handler import get_tts_client, close_tts_client
import logging

# Configure logging to print to console
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage app lifecycle - startup and shutdown"""
    # Startup
    print("\n" + "="*60)
    print("LIFESPAN STARTUP TRIGGERED")
    print("="*60)
    try:
        print("🚀 Starting SAGE Backend...")
        logger.info("🚀 Starting SAGE Backend...")
        print("About to call get_tts_client()...")
        client = await get_tts_client()
        print(f"✅ Got TTS client: {client}")
        print("✅ Backend startup complete - TTS Client initialized with connection pooling")
        logger.info("✅ Backend startup complete")
    except Exception as e:
        print(f"❌ STARTUP ERROR: {e}")     
        logger.error(f"❌ STARTUP ERROR: {e}", exc_info=True)
        raise

    yield

    # Shutdown
    print("\n" + "="*60)
    print("LIFESPAN SHUTDOWN TRIGGERED")
    print("="*60)
    try:
        print("🛑 Shutting down SAGE Backend...")
        logger.info("🛑 Shutting down SAGE Backend...")
        await close_tts_client()
        print("✅ Backend shutdown complete")
        logger.info("✅ Backend shutdown complete")
    except Exception as e:
        print(f"❌ SHUTDOWN ERROR: {e}")
        logger.error(f"❌ SHUTDOWN ERROR: {e}", exc_info=True)

# Initialize FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.VERSION,
    description="Backend orchestration layer for SAGE smartglasses",
    lifespan=lifespan
)

# CORS - Allow Flutter app to make requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify Flutter app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(translation.router, prefix=settings.API_V1_PREFIX)
app.include_router(faces.router, prefix=settings.API_V1_PREFIX)
app.include_router(objects.router, prefix=settings.API_V1_PREFIX)
app.include_router(assistant.router, prefix=settings.API_V1_PREFIX)
app.include_router(camera.router, prefix=settings.API_V1_PREFIX)
app.include_router(location.router, prefix=settings.API_V1_PREFIX)

@app.get("/")
async def root():
    return {
        "message": "SAGE Backend API",
        "version": settings.VERSION,
        "docs": "/docs"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring"""
    return {"status": "healthy"}