#!/usr/bin/env python3
"""
SAGE Pi FastAPI Server
Main server running on Raspberry Pi for handling camera, audio, and HUD operations
"""

import logging
import sys
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
import uvicorn

# Import configuration
from config import pi_server_config as config
from utils.bluetooth_manager import BluetoothManager

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
bluetooth_manager = BluetoothManager()


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
            "bluetooth": "ready"
        }
    }


# ==================== BLUETOOTH ENDPOINTS ====================

@app.get("/bluetooth/scan")
async def scan_bluetooth_devices():
    """
    Start continuous Bluetooth scan (SSE stream)
    Scan continues until /bluetooth/scan/stop is called
        
    Returns:
        Server-Sent Events stream of discovered devices
    """
    async def event_stream():
        try:
            async for device in bluetooth_manager.scan_devices():
                # Send as SSE event
                import json
                data = json.dumps(device)
                yield f"data: {data}\n\n"
        except Exception as e:
            logger.error(f"Scan stream error: {e}")
            import json
            error_data = json.dumps({"error": str(e)})
            yield f"data: {error_data}\n\n"
    
    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        }
    )


@app.post("/bluetooth/scan/stop")
async def stop_bluetooth_scan():
    """
    Stop the current Bluetooth scan
    
    Returns:
        JSON response with success status
    """
    success = await bluetooth_manager.stop_scan()
    return {"success": success}


@app.post("/bluetooth/pair")
async def pair_bluetooth_device(
    mac: str = Body(..., embed=True),
    name: str = Body(..., embed=True)
):
    """
    Pair with a Bluetooth audio device (SSE stream)
    
    Args:
        mac: Device MAC address
        name: Device name
        
    Returns:
        Server-Sent Events stream of pairing progress
    """
    async def event_stream():
        try:
            async for status in bluetooth_manager.pair_device(mac, name):
                # Send as SSE event
                import json
                data = json.dumps(status)
                yield f"data: {data}\n\n"
        except Exception as e:
            logger.error(f"Pairing stream error: {e}")
            import json
            error_data = json.dumps({
                "status": "failed",
                "progress": 0,
                "message": f"Error: {str(e)}",
                "timestamp": datetime.utcnow().isoformat()
            })
            yield f"data: {error_data}\n\n"
    
    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        }
    )


@app.post("/bluetooth/disconnect")
async def disconnect_bluetooth_device(mac: str = Body(..., embed=True)):
    """
    Disconnect and remove a Bluetooth device
    
    Args:
        mac: Device MAC address
        
    Returns:
        JSON response with success status
    """
    result = await bluetooth_manager.disconnect_device(mac)
    return result


@app.get("/bluetooth/status")
async def get_bluetooth_status():
    """
    Get current Bluetooth audio device status
    
    Returns:
        JSON response with connected device info
    """
    status = await bluetooth_manager.get_status()
    return status


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
