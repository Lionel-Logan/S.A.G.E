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
import requests

from fastapi import FastAPI, Body, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
import uvicorn

# Import configuration
from config import pi_server_config as config
from config import camera_config
from utils.bluetooth_manager import BluetoothManager
from services.tts_service import TTSService
from services.camera_service import CameraService

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
camera_service = None  # Will be initialized on startup


# ==================== STARTUP/SHUTDOWN EVENTS ====================

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    global tts_service, camera_service
    
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
    
    # Initialize Camera service
    try:
        logger.info("Initializing Camera service...")
        camera_service = CameraService()
        logger.info("✓ Camera service ready")
    except Exception as e:
        logger.error(f"Failed to initialize Camera service: {e}")
        logger.warning("Camera endpoints will not be available")
        camera_service = None
    
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
    # Cleanup Camera service
    if camera_service:
        try:
            camera_service.cleanup()
        except Exception as e:
            logger.error(f"Error during Camera cleanup: {e}")


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
            "camera": "ready" if camera_service else "not_available",
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


# ==================== CAMERA ENDPOINTS ====================

@app.post("/camera/capture_photo")
async def capture_photo():
    """
    Capture a single photo and return as JPEG file
    
    Returns:
        JPEG image file
    """
    if not camera_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "Camera service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        image_bytes = camera_service.capture_photo()
        
        from fastapi import Response
        return Response(
            content=image_bytes,
            media_type="image/jpeg",
            headers={
                "Content-Disposition": f"attachment; filename=photo_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.jpg"
            }
        )
        
    except Exception as e:
        logger.error(f"Capture photo error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "CameraError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.post("/camera/capture_photo_base64")
async def capture_photo_base64():
    """
    Capture a single photo and return as base64 JSON
    
    Returns:
        JSON response with base64 encoded image and metadata
    """
    if not camera_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "Camera service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        result = camera_service.capture_photo_base64()
        return {
            "success": True,
            **result
        }
        
    except Exception as e:
        logger.error(f"Capture photo base64 error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "CameraError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.post("/camera/continuous/start")
async def start_continuous_capture(
    interval_seconds: Optional[float] = Body(None, embed=True)
):
    """
    Start continuous photo capture at intervals
    
    Args:
        interval_seconds: Time between captures (default: from config)
        
    Returns:
        JSON response with capture status
    """
    if not camera_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "Camera service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        result = camera_service.start_continuous_capture(interval_seconds)
        return {
            **result,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Start continuous capture error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "CameraError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.post("/camera/continuous/stop")
async def stop_continuous_capture():
    """
    Stop continuous photo capture
    
    Returns:
        JSON response with stop status
    """
    if not camera_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "Camera service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        result = camera_service.stop_continuous_capture()
        return {
            **result,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Stop continuous capture error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "CameraError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


# ==================== FACIAL RECOGNITION SUPPORT ====================

@app.post("/request_name")
async def request_name():
    """
    Request user to provide name and description for unrecognized person.
    Used in facial recognition workflow when person is not found in database.
    
    Workflow:
    1. Play TTS prompt asking for name and relationship
    2. Call voice_assistant service to record and transcribe
    3. Return transcribed text to backend
    
    Returns:
        JSON response with transcription and metadata
    """
    # Check if TTS service is available
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
        logger.info("Request name endpoint called - starting facial recognition name request flow")
        
        # Step 1: Play TTS prompt
        prompt_text = "I am not able to recognize this person. Can you give me more details, name and how this person is related to you"
        logger.info(f"Playing TTS prompt: '{prompt_text}'")
        
        tts_success = tts_service.speak(prompt_text, blocking=True)
        if not tts_success:
            logger.warning("TTS prompt failed, but continuing with recording")
        
        # Step 2: Call voice assistant service for recording and transcription
        logger.info("Calling voice assistant service for recording...")
        
        try:
            response = requests.post(
                "http://127.0.0.1:8002/record_and_transcribe",
                timeout=60  # 60 seconds timeout - includes TTS + recording + transcription
            )
            
            if response.status_code == 200:
                data = response.json()
                
                if data.get("success"):
                    logger.info(f"✓ Transcription successful: '{data.get('transcription')}'")
                    return {
                        "success": True,
                        "transcription": data.get("transcription"),
                        "duration": data.get("duration"),
                        "prompt": prompt_text,
                        "timestamp": datetime.utcnow().isoformat()
                    }
                else:
                    logger.warning(f"Voice assistant returned error: {data.get('error')}")
                    return JSONResponse(
                        status_code=400,
                        content={
                            "error": data.get("error", "VoiceAssistantError"),
                            "message": data.get("message", "Recording or transcription failed"),
                            "timestamp": datetime.utcnow().isoformat()
                        }
                    )
            else:
                logger.error(f"Voice assistant HTTP error: {response.status_code}")
                return JSONResponse(
                    status_code=503,
                    content={
                        "error": "VoiceAssistantError",
                        "message": f"Voice assistant returned status {response.status_code}",
                        "timestamp": datetime.utcnow().isoformat()
                    }
                )
                
        except requests.exceptions.Timeout:
            logger.error("Voice assistant request timed out")
            return JSONResponse(
                status_code=504,
                content={
                    "error": "Timeout",
                    "message": "Recording timed out",
                    "timestamp": datetime.utcnow().isoformat()
                }
            )
        except requests.exceptions.ConnectionError:
            logger.error("Could not connect to voice assistant service")
            return JSONResponse(
                status_code=503,
                content={
                    "error": "ServiceUnavailable",
                    "message": "Voice assistant service not available. Ensure voice_assistant.py is running.",
                    "timestamp": datetime.utcnow().isoformat()
                }
            )
        
    except Exception as e:
        logger.error(f"Request name error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "RequestNameError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


# ==================== VIDEO RECORDING ENDPOINTS ====================

@app.post("/camera/video/start")
async def start_video_recording(
    max_duration_seconds: Optional[int] = Body(None, embed=True)
):
    """
    Start video recording
    
    Args:
        max_duration_seconds: Maximum recording duration (default: 120s)
        
    Returns:
        JSON response with video_id and recording status
    """
    if not camera_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "Camera service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        result = camera_service.start_video_recording(max_duration_seconds)
        return {
            **result,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Start video recording error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "CameraError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.post("/camera/video/stop")
async def stop_video_recording(
    video_id: Optional[str] = Body(None, embed=True),
    send_to_backend: bool = Body(True, embed=True)
):
    """
    Stop video recording and optionally send to backend
    
    Args:
        video_id: Video identifier (optional, uses current recording)
        send_to_backend: Whether to upload to backend (default: True)
        
    Returns:
        JSON response with video info and upload status
    """
    if not camera_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "Camera service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        result = camera_service.stop_video_recording(send_to_backend)
        return {
            **result,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Stop video recording error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "CameraError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.get("/camera/video/status/{video_id}")
async def get_video_status(video_id: str):
    """
    Get status of a video recording
    
    Args:
        video_id: Video identifier
        
    Returns:
        JSON response with video status
    """
    if not camera_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "Camera service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        result = camera_service.get_video_status(video_id)
        return {
            **result,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Get video status error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "CameraError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.get("/camera/videos")
async def list_videos():
    """
    List all locally stored videos
    
    Returns:
        JSON response with list of videos
    """
    if not camera_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "Camera service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        videos = camera_service.video_storage.get_videos()
        storage_info = camera_service.video_storage.get_storage_info()
        
        return {
            "videos": videos,
            "storage": storage_info,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"List videos error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "CameraError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.delete("/camera/video/{video_id}")
async def delete_video(video_id: str):
    """
    Delete a local video file
    
    Args:
        video_id: Video identifier
        
    Returns:
        JSON response with deletion status
    """
    if not camera_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "Camera service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        success = camera_service.video_storage.delete_video(video_id)
        
        if success:
            return {
                "success": True,
                "video_id": video_id,
                "message": "Video deleted",
                "timestamp": datetime.utcnow().isoformat()
            }
        else:
            return JSONResponse(
                status_code=404,
                content={
                    "error": "NotFound",
                    "message": f"Video not found: {video_id}",
                    "timestamp": datetime.utcnow().isoformat()
                }
            )
        
    except Exception as e:
        logger.error(f"Delete video error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "CameraError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.get("/camera/stream")
async def stream_camera():
    """
    MJPEG video stream for live camera preview
    
    Returns:
        MJPEG stream (multipart/x-mixed-replace)
    """
    if not camera_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "Camera service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        return StreamingResponse(
            camera_service.stream_mjpeg(),
            media_type="multipart/x-mixed-replace; boundary=frame",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
            }
        )
        
    except Exception as e:
        logger.error(f"Camera stream error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "CameraError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.get("/camera/config")
async def get_camera_config():
    """
    Get current camera configuration
    
    Returns:
        JSON response with camera settings in Flutter-compatible format
    """
    if not camera_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "Camera service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        config_data = camera_service.get_config()
        
        # Convert to Flutter-compatible format
        # Convert shutter_speed_us (microseconds) to milliseconds
        flutter_config = {
            "photo_resolution": config_data.get("resolution", [1920, 1080]),
            "photo_shutter_speed": config_data.get("shutter_speed_us", 0) / 1000.0,  # Convert µs to ms
            "photo_iso": config_data.get("iso", 0),
            "photo_brightness": config_data.get("brightness", 0.0),
            "photo_contrast": config_data.get("contrast", 1.0),
            "photo_sharpness": config_data.get("sharpness", 1.0),
            "video_max_duration": camera_config.VIDEO_MAX_DURATION,
            "last_videos_stored": camera_config.VIDEO_KEEP_LAST_N
        }
        
        return flutter_config
        
    except Exception as e:
        logger.error(f"Get camera config error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "CameraError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.post("/camera/config/reset")
async def reset_camera_config():
    """
    Reset camera configuration to default values
    
    Returns:
        JSON response with default configuration
    """
    if not camera_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "Camera service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        config = camera_service.reset_to_defaults()
        
        # Convert to Flutter-compatible format
        flutter_config = {
            "photo_resolution": config["resolution"],
            "photo_shutter_speed": config["shutter_speed_us"] / 1000,  # Convert to ms
            "photo_iso": config["iso"],
            "photo_brightness": config["brightness"],
            "photo_contrast": config["contrast"],
            "photo_sharpness": config["sharpness"]
        }
        
        return {
            "success": True,
            "message": "Camera configuration reset to defaults",
            "config": flutter_config
        }
        
    except Exception as e:
        logger.error(f"Failed to reset camera config: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "InternalServerError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )

@app.put("/camera/config")
async def update_camera_config(request: Request):
    """
    Update camera configuration
    
    Accepts JSON body with any of:
        photo_resolution: [width, height] e.g., [1920, 1080]
        photo_shutter_speed: Shutter speed in milliseconds (0 = auto)
        photo_iso: ISO value 100-800 (0 = auto)
        photo_brightness: Brightness -1.0 to 1.0
        photo_contrast: Contrast 0.0 to 2.0
        photo_sharpness: Sharpness 0.0 to 2.0
        video_max_duration: Max video duration in seconds
        last_videos_stored: Number of videos to keep
        
    Returns:
        JSON response with updated configuration
    """
    if not camera_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "Camera service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        # Parse JSON body
        body = await request.json()
        
        # Map Flutter app parameter names to camera service names
        param_mapping = {
            'photo_resolution': 'resolution',
            'photo_shutter_speed': 'shutter_speed_ms',
            'photo_iso': 'iso',
            'photo_brightness': 'brightness',
            'photo_contrast': 'contrast',
            'photo_sharpness': 'sharpness',
            'video_max_duration': 'video_max_duration',
            'last_videos_stored': 'last_videos_stored'
        }
        
        # Build settings dict
        settings = {}
        for flutter_key, service_key in param_mapping.items():
            if flutter_key in body:
                settings[service_key] = body[flutter_key]
        
        if not settings:
            return JSONResponse(
                status_code=400,
                content={
                    "error": "InvalidRequest",
                    "message": "No settings provided",
                    "timestamp": datetime.utcnow().isoformat()
                }
            )
        
        updated_config = camera_service.update_config(settings)
        
        return {
            "success": True,
            "message": "Camera configuration updated",
            "config": updated_config,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Update camera config error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "CameraError",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.get("/camera/status")
async def get_camera_status():
    """
    Get camera service status and capabilities
    
    Returns:
        JSON response with camera status
    """
    if not camera_service:
        return JSONResponse(
            status_code=503,
            content={
                "error": "ServiceUnavailable",
                "message": "Camera service not available",
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    try:
        status = camera_service.get_status()
        return {
            **status,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Get camera status error: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={
                "error": "CameraError",
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
