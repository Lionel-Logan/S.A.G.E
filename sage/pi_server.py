#!/usr/bin/env python3
"""
SAGE Pi FastAPI Server
Main server running on Raspberry Pi for handling camera, audio, and HUD operations
"""

import logging
import sys
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn

# Import configuration
from config import pi_server_config as config

# Configure logging
logging.basicConfig(
    level=getattr(logging, config.LOG_LEVEL),
    format=config.LOG_FORMAT,
    handlers=[
        logging.StreamHandler(sys.stdout),
        # File handler will be added if log directory exists
    ]
)
logger = logging.getLogger(__name__)

# Add file handler if log directory exists
log_path = Path(config.LOG_FILE)
if log_path.parent.exists():
    file_handler = logging.FileHandler(config.LOG_FILE)
    file_handler.setFormatter(logging.Formatter(config.LOG_FORMAT))
    logger.addHandler(file_handler)
else:
    logger.warning(f"Log directory {log_path.parent} does not exist. Logging to console only.")

# Initialize FastAPI app
app = FastAPI(
    title=config.SERVER_NAME,
    version=config.SERVER_VERSION,
    description=config.DESCRIPTION,
    docs_url="/docs",
    redoc_url="/redoc"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables for service state
service_start_time = datetime.utcnow()


# ==================== STARTUP/SHUTDOWN EVENTS ====================

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    logger.info("=" * 60)
    logger.info(f"Starting {config.SERVER_NAME} v{config.SERVER_VERSION}")
    logger.info("=" * 60)
    logger.info(f"Host: {config.SERVER_HOST}")
    logger.info(f"Port: {config.SERVER_PORT}")
    logger.info("=" * 60)
    logger.info("✓ Server ready")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down SAGE Pi Server...")


# ==================== EXCEPTION HANDLERS ====================

@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    """Handle all uncaught exceptions"""
    logger.error(f"Unhandled exception: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "error": "InternalServerError",
            "message": "An unexpected error occurred",
            "timestamp": datetime.utcnow().isoformat()
        }
    )


# ==================== API ENDPOINTS ====================

@app.get("/")
async def root():
    """Root endpoint with service information"""
    return {
        "service": config.SERVER_NAME,
        "version": config.SERVER_VERSION,
        "status": "running",
        "timestamp": datetime.utcnow().isoformat(),
        "endpoints": {
            "ping": "/ping",
            "health": "/health",
            "docs": "/docs"
        }
    }


@app.get("/ping")
async def ping():
    """Simple connectivity test endpoint"""
    logger.info("Ping request received")
    return {
        "status": "ok",
        "timestamp": datetime.utcnow().isoformat(),
        "service": config.SERVER_NAME,
        "version": config.SERVER_VERSION
    }


@app.get("/health")
async def health_check():
    """Detailed health check endpoint"""
    uptime = (datetime.utcnow() - service_start_time).total_seconds()
    
    return {
        "status": "healthy",
        "uptime_seconds": uptime,
        "timestamp": datetime.utcnow().isoformat(),
        "service": config.SERVER_NAME,
        "version": config.SERVER_VERSION,
        "services": {
            "camera": "not_implemented",
            "audio": "not_implemented",
            "display": "not_implemented"
        }
    }


# ==================== MAIN ====================

if __name__ == "__main__":
    logger.info("Starting SAGE Pi Server in standalone mode...")
    
    uvicorn.run(
        "pi_server:app",
        host=config.SERVER_HOST,
        port=config.SERVER_PORT,
        reload=False,  # No auto-reload for production
        log_level=config.LOG_LEVEL.lower(),
        access_log=True
    )
