"""
Location WebSocket endpoint for receiving continuous location updates
Used for real-time navigation with turn-by-turn instructions
"""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Dict
import json
import httpx
from app.config import settings
from app.services.navigation_session import get_navigation_session_manager

router = APIRouter(prefix="/location", tags=["Location"])

# Store active WebSocket connections
active_connections: Dict[str, WebSocket] = {}


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
    """
    WebSocket endpoint for receiving continuous location updates
    
    Frontend sends location every 3 seconds:
    {
        "type": "location_update",
        "data": {
            "latitude": 40.7589,
            "longitude": -73.9851,
            "accuracy": 10.5,
            "speed": 1.2,
            "heading": 45.0,
            "timestamp": "2026-02-10T14:30:45Z"
        }
    }
    
    Backend responds with:
    {
        "type": "ack",
        "status": "ok"
    }
    """
    await websocket.accept()
    active_connections[device_id] = websocket
    
    print(f"🔌 WebSocket connected: {device_id}")
    
    # Get navigation session manager
    nav_manager = get_navigation_session_manager()
    
    try:
        while True:
            # Receive location update from frontend
            data = await websocket.receive_text()
            message = json.loads(data)
            
            # Process location update
            if message.get("type") == "location_update":
                location_data = message.get("data", {})
                lat = location_data.get("latitude")
                lon = location_data.get("longitude")
                speed = location_data.get("speed", 0)
                accuracy = location_data.get("accuracy", 0)
                
                print(f"📍 Location received: ({lat:.6f}, {lon:.6f}) | Speed: {speed:.1f}m/s | Accuracy: {accuracy:.1f}m")
                
                # Check if there's an active navigation session
                if nav_manager.has_active_session():
                    # Update navigation with new location
                    result = await nav_manager.update_location(lat, lon)
                    
                    if result:
                        # Send TTS if instruction should be spoken
                        if result.get("should_speak"):
                            await _send_to_tts(result["instruction"])
                        
                        # Send response to frontend
                        await websocket.send_json({
                            "type": "navigation_update",
                            "status": result.get("status", "active"),
                            "instruction": result.get("instruction", ""),
                            "distance_to_next": result.get("distance_to_next", 0)
                        })
                    else:
                        # No navigation instruction, just acknowledge
                        await websocket.send_json({
                            "type": "ack",
                            "status": "ok"
                        })
                else:
                    # No navigation active, just acknowledge receipt
                    await websocket.send_json({
                        "type": "ack",
                        "status": "ok"
                    })
            
            # Handle ping
            elif message.get("type") == "ping":
                await websocket.send_json({
                    "type": "pong",
                    "status": "ok"
                })
            
            # Handle status request
            elif message.get("type") == "get_status":
                session_status = nav_manager.get_session_status()
                await websocket.send_json({
                    "type": "status_response",
                    "session": session_status
                })
            
    except WebSocketDisconnect:
        print(f"🔌 WebSocket disconnected: {device_id}")
        if device_id in active_connections:
            del active_connections[device_id]
    
    except Exception as e:
        print(f"❌ WebSocket error: {e}")
        if device_id in active_connections:
            del active_connections[device_id]
        await websocket.close()
