"""
Location WebSocket endpoint for receiving continuous location updates
Used for real-time navigation with turn-by-turn instructions
"""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from typing import Dict, Optional, List
import json
import httpx
from datetime import datetime
from app.config import settings
from app.services.navigation_session import get_navigation_session_manager

router = APIRouter(prefix="/location", tags=["Location"])

# Store active WebSocket connections
active_connections: Dict[str, WebSocket] = {}


# HTTP Models for fallback endpoint
class LocationData(BaseModel):
    latitude: float
    longitude: float
    accuracy: Optional[float] = None
    speed: Optional[float] = None
    heading: Optional[float] = None
    timestamp: Optional[str] = None


class LocationUpdate(BaseModel):
    """Model for location update"""
    latitude: float
    longitude: float
    accuracy: Optional[float] = None
    altitude: Optional[float] = None
    speed: Optional[float] = None
    heading: Optional[float] = None
    timestamp: Optional[str] = None


async def _send_to_tts(text: str):
    """Send text to Pi server for TTS output"""
    try:
        async with httpx.AsyncClient(timeout=settings.PI_REQUEST_TIMEOUT) as client:
            await client.post(
                f"{settings.PI_SERVER_URL}/tts/speak",
                json={"text": text, "blocking": False}
            )
            print(f"🔊 TTS: {text}")
    except Exception as e:
        print(f"⚠️ TTS error: {e}")


@router.websocket("/ws/{device_id}")
async def location_websocket(websocket: WebSocket, device_id: str):
    """WebSocket endpoint for receiving continuous location updates"""
    
    await websocket.accept()
    active_connections[device_id] = websocket
    
    print(f"🔌 WebSocket connected: {device_id}")
    
    # Get navigation session manager
    nav_manager = get_navigation_session_manager()
    
    # Check and log current session status
    session_status = nav_manager.get_session_status()
    print(f"📊 Session status on connect: {session_status}")
    
    try:
        while True:
            # Receive location update from frontend
            data = await websocket.receive_text()
            message = json.loads(data)
            
            # Normalize message type to lowercase for comparison
            message_type = message.get("type", "").lower()
            print(f"📨 Received message: type={message.get('type')} (normalized: {message_type})")
            
            # Process location update
            if message_type == "location_update":
                location_data = message.get("data", {})
                
                # Extract coordinates
                lat = location_data.get("latitude")
                lon = location_data.get("longitude")
                speed = location_data.get("speed", 0)
                accuracy = location_data.get("accuracy", 0)
                altitude = location_data.get("altitude", 0)
                heading = location_data.get("heading", 0)
                timestamp = location_data.get("timestamp", datetime.now().isoformat())
                
                print(f"📍 Location received: ({lat:.6f}, {lon:.6f}) | Speed: {speed:.1f}m/s | Accuracy: {accuracy:.1f}m")
                
                # Validate coordinates (ignore invalid 0.0, 0.0)
                if lat is None or lon is None or (lat == 0.0 and lon == 0.0):
                    print(f"⚠️ Invalid coordinates received: ({lat}, {lon}) - ignoring")
                    await websocket.send_json({
                        "type": "error",
                        "message": "Invalid coordinates",
                        "status": "error"
                    })
                    continue
                
                # Check if there's an active navigation session
                has_session = nav_manager.has_active_session()
                print(f"🔍 Has active session: {has_session}")
                
                if has_session:
                    # Get current session (use property directly, not method)
                    session = nav_manager.active_session
                    
                    if session.status == "waiting_for_location":
                        print(f"📍 First location received for session: {session.destination}")
                        print(f"📍 Calculating route from ({lat:.6f}, {lon:.6f}) to {session.destination}")
                    
                    # Update location and get navigation instruction
                    nav_result = await nav_manager.update_location(lat, lon)
                    
                    print(f"🧭 Navigation result: {nav_result}")
                    
                    # Send navigation update back to frontend
                    response = {
                        "type": "navigation_update",
                        "status": "ok",
                        "navigation_active": True,
                        "navigation_status": session.status,
                        "destination": session.destination,
                        "current_step": session.current_step_index,
                        "total_steps": len(session.steps_with_coords) if session.steps_with_coords else 0,
                    }
                    
                    # Add navigation instruction if available
                    if nav_result and nav_result.get("instruction"):
                        response["instruction"] = nav_result["instruction"]
                        response["distance_to_next"] = nav_result.get("distance_to_next", 0)
                        response["duration_to_next"] = nav_result.get("duration_to_next", 0)
                        
                        # Send TTS instruction
                        await _send_to_tts(nav_result["instruction"])
                    
                    await websocket.send_json(response)
                    
                else:
                    # No active navigation, just acknowledge
                    await websocket.send_json({
                        "type": "ack",
                        "status": "ok",
                        "navigation_active": False,
                        "message": "Location received, no active navigation"
                    })
            
            elif message_type == "ping":
                # Respond to ping
                await websocket.send_json({
                    "type": "pong",
                    "timestamp": datetime.now().isoformat()
                })
                print(f"🏓 Ping received, pong sent")
            
            elif message_type == "pong":
                # Backend sent ping, frontend responded with pong
                print(f"🏓 Pong received")
            
            elif message_type == "get_status" or message_type == "status_response":
                # Frontend requesting status or sending status response
                session_status = nav_manager.get_session_status()
                await websocket.send_json({
                    "type": "status",
                    "data": session_status,
                    "timestamp": datetime.now().isoformat()
                })
                print(f"📊 Status requested/received, sent current status")
            
            else:
                print(f"⚠️ Unknown message type: {message.get('type')}")
                await websocket.send_json({
                    "type": "error",
                    "message": f"Unknown message type: {message.get('type')}",
                    "status": "error"
                })
    
    except WebSocketDisconnect:
        print(f"🔌 WebSocket disconnected: {device_id}")
        if device_id in active_connections:
            del active_connections[device_id]
    
    except Exception as e:
        print(f"❌ WebSocket error for {device_id}: {e}")
        import traceback
        traceback.print_exc()
        if device_id in active_connections:
            del active_connections[device_id]


# ============================================================================
# HTTP FALLBACK ENDPOINTS
# ============================================================================

@router.post("/update")
async def post_location_update(location: LocationData):
    """
    HTTP endpoint for posting location updates (fallback if WebSocket unavailable)
    
    Used for polling-based location updates
    """
    print(f"📍 HTTP Location received: ({location.latitude:.6f}, {location.longitude:.6f})")
    
    # Get navigation session manager
    nav_manager = get_navigation_session_manager()
    
    # Check if there's an active navigation session
    if nav_manager.has_active_session():
        # Update navigation with new location
        result = await nav_manager.update_location(location.latitude, location.longitude)
        
        if result:
            # Send TTS if instruction should be spoken
            if result.get("should_speak"):
                await _send_to_tts(result["instruction"])
            
            return {
                "status": "ok",
                "navigation_active": True,
                "navigation_status": result.get("status", "active"),
                "instruction": result.get("instruction", ""),
                "distance_to_next": result.get("distance_to_next", 0)
            }
        else:
            return {
                "status": "ok",
                "navigation_active": True,
                "navigation_status": "active"
            }
    else:
        return {
            "status": "ok",
            "navigation_active": False
        }


@router.post("/batch")
async def post_location_batch(locations: List[LocationData]):
    """
    HTTP endpoint for posting batch location updates
    
    Processes the most recent location only for navigation
    """
    if not locations:
        return {"status": "error", "message": "No locations provided"}
    
    # Use the most recent location (last in the list)
    latest = locations[-1]
    
    print(f"📍 HTTP Batch received: {len(locations)} locations, processing latest: ({latest.latitude:.6f}, {latest.longitude:.6f})")
    
    # Get navigation session manager
    nav_manager = get_navigation_session_manager()
    
    # Check if there's an active navigation session
    if nav_manager.has_active_session():
        # Update navigation with new location
        result = await nav_manager.update_location(latest.latitude, latest.longitude)
        
        if result:
            # Send TTS if instruction should be spoken
            if result.get("should_speak"):
                await _send_to_tts(result["instruction"])
            
            return {
                "status": "ok",
                "locations_received": len(locations),
                "navigation_active": True,
                "navigation_status": result.get("status", "active"),
                "instruction": result.get("instruction", ""),
                "distance_to_next": result.get("distance_to_next", 0)
            }
        else:
            return {
                "status": "ok",
                "locations_received": len(locations),
                "navigation_active": True,
                "navigation_status": "active"
            }
    else:
        return {
            "status": "ok",
            "locations_received": len(locations),
            "navigation_active": False
        }


@router.get("/current")
async def get_current_location():
    """
    Get current location from active navigation session
    
    Returns the last known location if navigation is active
    """
    nav_manager = get_navigation_session_manager()
    
    if nav_manager.has_active_session() and nav_manager.active_session:
        session = nav_manager.active_session
        
        if session.origin_coords:
            return {
                "status": "ok",
                "has_location": True,
                "latitude": session.origin_coords[0],
                "longitude": session.origin_coords[1],
                "destination": session.destination,
                "navigation_status": session.status
            }
    
    return {
        "status": "ok",
        "has_location": False,
        "message": "No active navigation session or location not yet available"
    }


@router.get("/session/status")
async def get_session_status():
    """
    Get current navigation session status for debugging
    
    Returns detailed session information
    """
    nav_manager = get_navigation_session_manager()
    
    session_status = nav_manager.get_session_status()
    
    return {
        "status": "ok",
        "session": session_status,
        "has_active_session": nav_manager.has_active_session()
    }
