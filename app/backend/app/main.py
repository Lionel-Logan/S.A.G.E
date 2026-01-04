from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.api.v1 import auth, translation, faces, objects, assistant

# Initialize FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.VERSION,
    description="Backend orchestration layer for SAGE smartglasses"
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
app.include_router(auth.router, prefix=settings.API_V1_PREFIX)
app.include_router(translation.router, prefix=settings.API_V1_PREFIX)
app.include_router(faces.router, prefix=settings.API_V1_PREFIX)
app.include_router(objects.router, prefix=settings.API_V1_PREFIX)
app.include_router(assistant.router, prefix=settings.API_V1_PREFIX)

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

# Startup event
@app.on_event("startup")
async def startup_event():
    # Initialize database
    # Start Redis connection
    # Warm up model server connections
    print(f"🚀 {settings.APP_NAME} started successfully")

# Shutdown event
@app.on_event("shutdown")
async def shutdown_event():
    # Close database connections
    # Close Redis connection
    print("👋 Shutting down gracefully")