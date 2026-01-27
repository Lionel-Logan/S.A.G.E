#!/usr/bin/env python3
"""
SAGE Pi FastAPI Server
Main server running on Raspberry Pi for handling camera, audio, and HUD operations
"""

import logging
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
import uvicorn

# Import configuration
from config import pi_server_config as config
from utils.bluetooth_manager import BluetoothManager
from services.tts_service import TTSService

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
tts_service = None  # Will be initialized on startup


# ==================== STARTUP/SHUTDOWN EVENTS ====================

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    global tts_service
    
    logger.info("=" * 60)
    logger.info(f"Starting {config.SERVER_NAME} v{config.SERVER_VERSION}")
    logger.info("=" * 60)
    logger.info(f"Host: {config.SERVER_HOST}")
    logger.info(f"Port: {config.SERVER_PORT}")
    logger.info("=" * 60)
    
    # Initialize TTS service
    try:
        logger.info("Initializing TTS service...")
        tts_service = TTSService()
        logger.info("✓ TTS service ready")
    except Exception as e:
        logger.error(f"Failed to initialize TTS service: {e}")
        logger.warning("TTS endpoints will not be available")
        tts_service = None
    
    logger.info("✓ Server ready")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down SAGE Pi Server...")
    
    # Cleanup TTS service
    if tts_service:
        try:
            tts_service.cleanup()
        except Exception as e:
            logger.error(f"Error during TTS cleanup: {e}")


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
            "audio": "ready",
            "bluetooth": "ready",
            "tts": "ready" if tts_service else "not_available"
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


# ==================== TEXT-TO-SPEECH ENDPOINTS ====================

@app.post("/tts/speak")
async def tts_speak(
    text: str = Body(..., embed=True),
    blocking: bool = Body(True, embed=True)
):
    """
    Convert text to speech and play through audio output
    
    Args:
        text: Text to speak
        blocking: If True, wait for speech to complete; if False, return immediately
        
    Returns:
        JSON response with success status
    """
    if not tts_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "TTS service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        logger.info(f"TTS speak request: '{text[:50]}{'...' if len(text) > 50 else ''}'")
        
        success = tts_service.speak(text, blocking=blocking)
        
        return {
            "success": success,
            "message": "Speech started" if not blocking else "Speech completed",
            "text_length": len(text),
            "blocking": blocking,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"TTS speak error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "TTSError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.post("/tts/stop")
async def tts_stop():
    """
    Stop current TTS speech immediately
    
    Returns:
        JSON response with success status
    """
    if not tts_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "TTS service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        success = tts_service.stop()
        return {
            "success": success,
            "message": "TTS stopped",
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"TTS stop error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "TTSError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.get("/tts/config")
async def get_tts_config():
    """
    Get current TTS configuration
    
    Returns:
        JSON response with current TTS settings
    """
    if not tts_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "TTS service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        config_data = tts_service.get_config()
        return {
            "config": config_data,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Get TTS config error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "TTSError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.post("/tts/config")
async def update_tts_config(
    voice_speed: Optional[int] = Body(None),
    voice_volume: Optional[float] = Body(None),
    voice_gender: Optional[str] = Body(None),
    voice_id: Optional[str] = Body(None),
    voice_language: Optional[str] = Body(None)
):
    """
    Update TTS configuration
    
    Args:
        voice_speed: Speech speed in words per minute (100-300)
        voice_volume: Volume level (0.0-1.0)
        voice_gender: Voice gender preference (male/female/neutral)
        voice_id: Specific system voice ID
        voice_language: Language code (e.g., en-US)
        
    Returns:
        JSON response with updated configuration
    """
    if not tts_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "TTS service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        # Build settings dictionary from provided parameters
        settings = {}
        if voice_speed is not None:
            settings['voice_speed'] = voice_speed
        if voice_volume is not None:
            settings['voice_volume'] = voice_volume
        if voice_gender is not None:
            settings['voice_gender'] = voice_gender
        if voice_id is not None:
            settings['voice_id'] = voice_id
        if voice_language is not None:
            settings['voice_language'] = voice_language
        
        if not settings:
            return JSONResponse(
                status_code=400,
                content={
                    "error": "InvalidRequest",
                    "message": "No settings provided",
                    "timestamp": datetime.utcnow().isoformat()
                }
            )
        
        # Update configuration
        updated_config = tts_service.update_config(settings)
        
        return {
            "success": True,
            "message": "TTS configuration updated",
            "config": updated_config,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Update TTS config error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "TTSError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.get("/tts/voices")
async def get_tts_voices():
    """
    Get list of available system voices
    
    Returns:
        JSON response with list of available voices
    """
    if not tts_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "TTS service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        voices = tts_service.get_available_voices()
        return {
            "voices": voices,
            "count": len(voices),
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Get TTS voices error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "TTSError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.post("/tts/test")
async def test_tts(text: Optional[str] = Body(None, embed=True)):
    """
    Test TTS with current configuration
    
    Args:
        text: Optional test text (default: standard test message)
        
    Returns:
        JSON response with test result
    """
    if not tts_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "TTS service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        success = tts_service.test_speech(text)
        return {
            "success": success,
            "message": "TTS test completed",
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"TTS test error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "TTSError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.get("/tts/status")
async def get_tts_status():
    """
    Get current TTS service status
    
    Returns:
        JSON response with TTS service status
    """
    if not tts_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "TTS service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        status = tts_service.get_status()
        return {
            "status": status,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Get TTS status error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "TTSError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


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
