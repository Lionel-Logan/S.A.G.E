"""
SAGE Pi Runtime Server (Windows Emulator)
==========================================
Simulates Raspberry Pi Zero 2 W behavior with enforced constraints.
This is NOT a mock - it's a real server that will run on actual Pi later.

Constraints enforced:
- Request/response only (no streaming)
- One camera frame per request
- No background threads
- Explicit pairing state machine
- No internet access
- Minimal processing
"""

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, Literal
import uvicorn
import logging
from datetime import datetime
import json
from pathlib import Path
import base64
import cv2
import numpy as np

# ============================================================================
# LOGGING SETUP
# ============================================================================
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] [PI-SERVER] %(levelname)s: %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger(__name__)

# ============================================================================
# CONFIGURATION
# ============================================================================
PI_CONFIG = {
    "device_id": "SAGE-PI-001",
    "device_name": "SAGE Glass",
    "version": "1.0.0",
    "hardware": "Raspberry Pi Zero 2 W (Emulated on Windows)",
    "capabilities": ["camera", "microphone", "speaker", "hud"],
    "max_frame_size": 640 * 480,  # 640x480 max resolution
    "port": 8001
}

# Persistent state file (simulates Pi's local storage)
STATE_FILE = Path("pi_state.json")

# ============================================================================
# DATA MODELS
# ============================================================================

class PairingRequest(BaseModel):
    app_id: str
    app_name: str
    timestamp: str

class PairingConfirm(BaseModel):
    app_id: str
    confirm: bool

class WiFiCredentials(BaseModel):
    ssid: str
    password: str

class HUDTextRequest(BaseModel):
    text: str
    duration_ms: Optional[int] = 3000
    position: Optional[Literal["top", "center", "bottom"]] = "center"

class AudioRequest(BaseModel):
    text: str  # Text to speak

# ============================================================================
# PI STATE MANAGER
# ============================================================================

class PiState:
    """Manages Pi state with persistence (simulates EEPROM/SD card storage)"""
    
    def __init__(self):
        self.paired_app_id: Optional[str] = None
        self.paired_app_name: Optional[str] = None
        self.pairing_pending: bool = False
        self.pending_app_id: Optional[str] = None
        self.wifi_ssid: Optional[str] = None
        self.hud_text: str = ""
        self.last_frame_time: Optional[datetime] = None
        
        self.load_state()
    
    def load_state(self):
        """Load state from file"""
        if STATE_FILE.exists():
            try:
                with open(STATE_FILE, 'r') as f:
                    data = json.load(f)
                    self.paired_app_id = data.get("paired_app_id")
                    self.paired_app_name = data.get("paired_app_name")
                    self.wifi_ssid = data.get("wifi_ssid")
                    logger.info(f"State loaded: Paired={self.paired_app_id is not None}")
            except Exception as e:
                logger.error(f"Failed to load state: {e}")
    
    def save_state(self):
        """Persist state to file"""
        try:
            data = {
                "paired_app_id": self.paired_app_id,
                "paired_app_name": self.paired_app_name,
                "wifi_ssid": self.wifi_ssid,
                "saved_at": datetime.now().isoformat()
            }
            with open(STATE_FILE, 'w') as f:
                json.dump(data, f, indent=2)
            logger.info("State saved successfully")
        except Exception as e:
            logger.error(f"Failed to save state: {e}")
    
    def is_paired(self) -> bool:
        return self.paired_app_id is not None
    
    def start_pairing(self, app_id: str):
        self.pairing_pending = True
        self.pending_app_id = app_id
        logger.info(f"Pairing initiated with app: {app_id}")
    
    def confirm_pairing(self, app_id: str, app_name: str):
        if self.pending_app_id != app_id:
            raise ValueError("App ID mismatch")
        
        self.paired_app_id = app_id
        self.paired_app_name = app_name
        self.pairing_pending = False
        self.pending_app_id = None
        self.save_state()
        logger.info(f"✓ Pairing confirmed with: {app_name} ({app_id})")
    
    def cancel_pairing(self):
        self.pairing_pending = False
        self.pending_app_id = None
        logger.info("Pairing cancelled")
    
    def reset_pairing(self):
        self.paired_app_id = None
        self.paired_app_name = None
        self.pairing_pending = False
        self.pending_app_id = None
        self.save_state()
        logger.info("⚠ Pairing reset - device unpaired")

# ============================================================================
# GLOBAL STATE
# ============================================================================
pi_state = PiState()

# Global camera instance (keep camera open for faster captures)
camera = None

def init_camera():
    """Initialize camera once at startup"""
    global camera
    try:
        logger.info("Initializing camera...")
        camera = cv2.VideoCapture(0, cv2.CAP_DSHOW)
        camera.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        camera.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        
        if camera.isOpened():
            logger.info("✅ Camera initialized successfully")
            # Warm up camera
            camera.grab()
            camera.retrieve()
        else:
            logger.warning("⚠️ Camera not available, will use test pattern")
            camera = None
    except Exception as e:
        logger.error(f"❌ Camera initialization failed: {e}")
        camera = None
app = FastAPI(title="SAGE Pi Runtime Server", version="1.0.0")

# ============================================================================
# MIDDLEWARE - PAIRING CHECK
# ============================================================================

@app.middleware("http")
async def verify_pairing(request: Request, call_next):
    """Enforce pairing for protected endpoints"""
    
    # Public endpoints (no pairing required)
    public_paths = ["/", "/identity", "/pairing/request", "/pairing/confirm", 
                    "/pairing/reset", "/docs", "/openapi.json"]
    
    if request.url.path in public_paths:
        response = await call_next(request)
        return response
    
    # Protected endpoints require pairing
    if not pi_state.is_paired():
        return JSONResponse(
            status_code=403,
            content={
                "error": "device_not_paired",
                "message": "Pi is not paired with any app. Complete pairing first."
            }
        )
    
    response = await call_next(request)
    return response

# ============================================================================
# ENDPOINTS - IDENTITY & STATUS
# ============================================================================

@app.get("/")
async def root():
    """Root endpoint - device discovery"""
    return {
        "status": "online",
        "device": PI_CONFIG["device_name"],
        "device_id": PI_CONFIG["device_id"],
        "message": "SAGE Pi Runtime Server is running"
    }

@app.get("/identity")
async def get_identity():
    """Device identity - used for discovery by Flutter app"""
    return {
        "device_id": PI_CONFIG["device_id"],
        "device_name": PI_CONFIG["device_name"],
        "version": PI_CONFIG["version"],
        "hardware": PI_CONFIG["hardware"],
        "capabilities": PI_CONFIG["capabilities"],
        "paired": pi_state.is_paired(),
        "paired_to": pi_state.paired_app_name if pi_state.is_paired() else None,
        "pairing_available": not pi_state.is_paired()
    }

@app.get("/status")
async def get_status():
    """Detailed device status (requires pairing)"""
    return {
        "device_id": PI_CONFIG["device_id"],
        "paired": True,
        "paired_app": pi_state.paired_app_name,
        "uptime_seconds": 0,  # Would track actual uptime on real Pi
        "temperature": 45.2,  # Would read actual temp on real Pi
        "hud_active": len(pi_state.hud_text) > 0,
        "hud_text": pi_state.hud_text,
        "last_frame_captured": pi_state.last_frame_time.isoformat() if pi_state.last_frame_time else None
    }

# ============================================================================
# ENDPOINTS - PAIRING STATE MACHINE
# ============================================================================

@app.post("/pairing/request")
async def request_pairing(request: PairingRequest):
    """Step 1: App requests to pair with Pi"""
    
    if pi_state.is_paired():
        raise HTTPException(
            status_code=409,
            detail="Device already paired. Reset pairing first."
        )
    
    if pi_state.pairing_pending:
        raise HTTPException(
            status_code=409,
            detail="Pairing already in progress"
        )
    
    pi_state.start_pairing(request.app_id)
    
    logger.info(f"📱 Pairing request from: {request.app_name}")
    
    return {
        "status": "pairing_initiated",
        "device_id": PI_CONFIG["device_id"],
        "message": "Pairing request received. Confirm to complete.",
        "expires_in_seconds": 60
    }

@app.post("/pairing/confirm")
async def confirm_pairing(confirm: PairingConfirm):
    """Step 2: App confirms pairing"""
    
    if not pi_state.pairing_pending:
        raise HTTPException(
            status_code=400,
            detail="No pairing in progress"
        )
    
    if not confirm.confirm:
        pi_state.cancel_pairing()
        return {
            "status": "pairing_cancelled",
            "message": "Pairing cancelled by app"
        }
    
    try:
        pi_state.confirm_pairing(confirm.app_id, "SAGE Flutter App")
        
        return {
            "status": "paired",
            "device_id": PI_CONFIG["device_id"],
            "device_name": PI_CONFIG["device_name"],
            "message": "Pairing successful! Device is now connected.",
            "capabilities": PI_CONFIG["capabilities"]
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/pairing/reset")
async def reset_pairing():
    """Factory reset - unpair device"""
    pi_state.reset_pairing()
    
    return {
        "status": "unpaired",
        "message": "Device has been unpaired and reset"
    }

# ============================================================================
# ENDPOINTS - CAMERA (I/O TEST)
# ============================================================================

@app.get("/camera/capture")
async def capture_frame():
    """
    Capture single frame from camera
    Constraint: ONE frame per request (no streaming)
    """
    global camera
    
    try:
        # Use global camera instance for faster capture
        if camera is not None and camera.isOpened():
            # Grab latest frame from buffer
            camera.grab()
            ret, frame = camera.retrieve()
            
            if not ret or frame is None:
                logger.warning("Failed to retrieve frame, using test pattern")
                frame = np.zeros((480, 640, 3), dtype=np.uint8)
                cv2.putText(frame, "SAGE - CAPTURE FAILED", (120, 240), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
            else:
                # Resize to Pi camera resolution (640x480)
                frame = cv2.resize(frame, (640, 480))
                logger.info("✅ Frame captured from webcam")
        else:
            # No camera available, use test pattern
            logger.warning("Camera not available, using test pattern")
            frame = np.zeros((480, 640, 3), dtype=np.uint8)
            cv2.putText(frame, "SAGE - NO CAMERA", (150, 240), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)
        
        # Show preview window (for development/testing)
        preview_frame = frame.copy()
        cv2.putText(preview_frame, "SAGE - Camera Capture", (10, 30),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
        cv2.imshow('SAGE Camera Capture', preview_frame)
        cv2.waitKey(1)  # Show for 1ms (non-blocking)
        
        # Encode to JPEG
        _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
        frame_base64 = base64.b64encode(buffer).decode('utf-8')
        
        pi_state.last_frame_time = datetime.now()
        
        logger.info(f"📷 Frame captured: {len(frame_base64)} bytes")
        
        return {
            "status": "success",
            "timestamp": pi_state.last_frame_time.isoformat(),
            "resolution": "640x480",
            "format": "jpeg",
            "frame": frame_base64,
            "size_bytes": len(frame_base64)
        }
    
    except Exception as e:
        logger.error(f"Camera error: {e}")
        raise HTTPException(status_code=500, detail=f"Camera error: {str(e)}")

# ============================================================================
# ENDPOINTS - MICROPHONE (I/O TEST)
# ============================================================================

@app.post("/microphone/capture")
async def capture_audio(duration_seconds: int = 3):
    """
    Capture audio from microphone
    Returns base64 encoded WAV audio
    """
    
    if duration_seconds > 10:
        raise HTTPException(status_code=400, detail="Max duration is 10 seconds")
    
    logger.info(f"🎤 Audio capture requested: {duration_seconds}s")
    
    # On real Pi, this would capture actual audio
    # For emulator, return dummy audio metadata
    return {
        "status": "success",
        "duration_seconds": duration_seconds,
        "format": "wav",
        "sample_rate": 16000,
        "channels": 1,
        "audio": "DUMMY_AUDIO_BASE64_DATA",  # Would be real audio on Pi
        "note": "Audio capture simulated - real implementation uses MEMS mic"
    }

# ============================================================================
# ENDPOINTS - HUD DISPLAY (I/O TEST)
# ============================================================================

@app.post("/hud/display")
async def display_on_hud(request: HUDTextRequest):
    """
    Display text on HUD
    Constraint: Text only, no complex rendering
    """
    
    if len(request.text) > 200:
        raise HTTPException(status_code=400, detail="Text too long (max 200 chars)")
    
    pi_state.hud_text = request.text
    
    logger.info(f"🔷 HUD Display: '{request.text}' (pos={request.position}, duration={request.duration_ms}ms)")
    
    # On real Pi, this would render to TFT screen
    # For emulator, we just log and store
    
    return {
        "status": "displayed",
        "text": request.text,
        "position": request.position,
        "duration_ms": request.duration_ms,
        "note": "HUD display simulated - real implementation uses TFT screen"
    }

@app.post("/hud/clear")
async def clear_hud():
    """Clear HUD display"""
    pi_state.hud_text = ""
    logger.info("🔷 HUD cleared")
    
    return {
        "status": "cleared",
        "message": "HUD display cleared"
    }

# ============================================================================
# ENDPOINTS - SPEAKER (I/O TEST)
# ============================================================================

@app.post("/speaker/speak")
async def speak_text(request: AudioRequest):
    """
    Speak text through speaker
    On real Pi, this would use TTS + speaker
    """
    
    logger.info(f"🔊 Speaker: '{request.text}'")
    
    return {
        "status": "spoken",
        "text": request.text,
        "note": "Audio playback simulated - real implementation uses mini speaker"
    }

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("SAGE Pi Runtime Server Starting...")
    logger.info("=" * 60)
    logger.info(f"Device ID: {PI_CONFIG['device_id']}")
    logger.info(f"Device Name: {PI_CONFIG['device_name']}")
    logger.info(f"Paired: {pi_state.is_paired()}")
    if pi_state.is_paired():
        logger.info(f"Paired to: {pi_state.paired_app_name}")
    logger.info("=" * 60)
    
    # Initialize camera
    init_camera()
    
    logger.info("=" * 60)
    logger.info("Server ready!")
    logger.info("=" * 60)
    
    uvicorn.run(
        app,
        host="0.0.0.0",  # Listen on all interfaces
        port=PI_CONFIG["port"],
        log_level="info"
    )