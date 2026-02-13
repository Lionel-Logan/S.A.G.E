from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime, timedelta
import re
import uuid
import httpx

# Import Services
from app.services.intent_router import IntentRouter
from app.services.gemini_service import GeminiService
from app.services.vision_service import VisionService
from app.services.navigation_service import NavigationService
from app.services.translate_service import TranslateService
from app.services.object_detection_session import get_detection_session
from app.services.navigation_session import get_navigation_session_manager
from app.config import settings

router = APIRouter(prefix="/assistant", tags=["AI Assistant"])

# ==================== ENROLLMENT CACHE ====================
# In-memory cache for face enrollment workflow
# Structure: {user_id: {image_base64: str, timestamp: datetime, state: str}}
enrollment_cache: Dict[str, Dict[str, Any]] = {}
ENROLLMENT_TIMEOUT = 90  # seconds (1.5 minutes)

def _cleanup_expired_cache():
    """Remove expired enrollment cache entries"""
    current_time = datetime.utcnow()
    expired_users = [
        user_id for user_id, data in enrollment_cache.items()
        if (current_time - data["timestamp"]).total_seconds() > ENROLLMENT_TIMEOUT
    ]
    for user_id in expired_users:
        del enrollment_cache[user_id]
        print(f"Cleaned up expired enrollment cache for user: {user_id}")

async def _capture_image_from_pi() -> Optional[str]:
    """Capture image from Pi server camera"""
    try:
        async with httpx.AsyncClient(timeout=settings.PI_REQUEST_TIMEOUT) as client:
            response = await client.post(f"{settings.PI_SERVER_URL}/camera/capture_photo_base64")
            response.raise_for_status()
            result = response.json()
            return result.get("image_base64")
    except Exception as e:
        print(f"Failed to capture image from Pi: {e}")
        return None

async def _send_to_tts(text: str):
    """Send text to Pi server for TTS output"""
    try:
        async with httpx.AsyncClient(timeout=settings.PI_REQUEST_TIMEOUT) as client:
            await client.post(
                f"{settings.PI_SERVER_URL}/tts/speak",
                json={"text": text, "blocking": False}
            )
    except Exception as e:
        print(f"TTS error: {e}")

# Define the Input Schema
class AssistantRequest(BaseModel):
    query: str
    user_id: str = "default_user"
    image_data: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None

# Define the Output Schema
class AssistantResponse(BaseModel):
    response_text: str
    action_type: str
    timestamp: datetime
    # This field holds the list of steps for the Flutter App
    navigation_data: Optional[Dict[str, Any]] = None 

# Initialize Services
intent_router = IntentRouter()
gemini_service = GeminiService()
vision_service = VisionService()
navigation_service = NavigationService()
translate_service = TranslateService() # <--- INITIALIZED THIS

@router.post("/ask", response_model=AssistantResponse)
async def ask_assistant(request: AssistantRequest):
    try:
        # Cleanup expired cache entries first
        _cleanup_expired_cache()
        
        response_text = ""
        action_type = "chat"
        navigation_data = None # Default to None
        
        # PRIORITY: Check enrollment flow BEFORE intent routing
        # This handles "yes/no" and "name" responses during face enrollment
        if request.user_id in enrollment_cache:
            cache_data = enrollment_cache[request.user_id]
            
            # State: awaiting_confirmation ("yes" or "no")
            if cache_data["state"] == "awaiting_confirmation":
                query_lower = request.query.lower().strip()
                
                if "yes" in query_lower or "yeah" in query_lower or "sure" in query_lower or "ok" in query_lower:
                    # User confirmed enrollment - move to name collection
                    enrollment_cache[request.user_id]["state"] = "awaiting_name"
                    enrollment_cache[request.user_id]["timestamp"] = datetime.utcnow()
                    response_text = "What is their name and relation? Say it like 'John as colleague', or just say the name."
                else:
                    # User declined enrollment
                    del enrollment_cache[request.user_id]
                    response_text = "Okay, not enrolling this person."
                
                action_type = "vision"
                await _send_to_tts(response_text)
                return AssistantResponse(
                    response_text=response_text,
                    action_type=action_type,
                    timestamp=datetime.utcnow(),
                    navigation_data=None
                )
            
            # State: awaiting_name (extract name and description)
            elif cache_data["state"] == "awaiting_name":
                # Extract name and optional description from query
                # Pattern: "John as colleague" or just "John"
                match = re.search(r"^([\w\s]+?)(?:\s+as\s+([\w\s]+))?$", request.query.strip(), re.IGNORECASE)
                
                if match:
                    name = match.group(1).strip()
                    description = match.group(2).strip() if match.group(2) else "Person"
                    
                    # Retrieve cached image
                    cached_image = cache_data["image_base64"]
                    
                    # Enroll the face
                    response_text = await vision_service.enroll_face(name, cached_image, description)
                    
                    # Clear cache after enrollment
                    del enrollment_cache[request.user_id]
                else:
                    response_text = "I didn't catch that. Please say the person's name, like 'John' or 'John as colleague'."
                
                action_type = "vision"
                await _send_to_tts(response_text)
                return AssistantResponse(
                    response_text=response_text,
                    action_type=action_type,
                    timestamp=datetime.utcnow(),
                    navigation_data=None
                )
        
        # 1. Predict Intent (Hybrid: Rule-based + Gemini fallback)
        intent = await intent_router.predict_intent(request.query)
        print(f"User said: {request.query} -> Detected Intent: {intent}")

        if intent == "NAVIGATION":
            action_type = "navigation"
            
            # Extract destination from query
            # Pattern matches: "navigate to X", "go to X", "take me to X", etc.
            pattern = r"(?:navigate|go|take me|directions|route|find|head)(?:\s+to|\s+for)?\s+(.+)"
            match = re.search(pattern, request.query, re.IGNORECASE)
            
            if match:
                destination = match.group(1).strip()
            else:
                # Fallback: use entire query as destination
                destination = request.query.strip()

            if not destination:
                response_text = "Where would you like to go?"
            else:
                # Create navigation session
                nav_manager = get_navigation_session_manager()
                nav_manager.start_navigation(destination)
                
                # Validate if location coordinates are valid and provided in the request
                # Coordinates must be non-zero and within valid GPS ranges
                has_valid_location = (
                    request.lat is not None and 
                    request.lon is not None and
                    (request.lat != 0.0 or request.lon != 0.0) and  # Exclude (0,0) which is likely null/default
                    -90 <= request.lat <= 90 and
                    -180 <= request.lon <= 180
                )
                
                if has_valid_location:
                    print(f"📍 Using provided location: ({request.lat}, {request.lon})")
                    
                    # Calculate route immediately with provided coordinates
                    result = await nav_manager.set_route(request.lat, request.lon)
                    
                    if result and "error" not in result:
                        # Route calculated successfully
                        route_data = nav_manager.active_session.route_data if nav_manager.active_session else None
                        
                        if route_data:
                            response_text = f"Navigation started to {destination}. {route_data.get('total_distance_text', '')} away. {result.get('instruction', '')}"
                            navigation_data = route_data
                        else:
                            response_text = f"Starting navigation to {destination}."
                    else:
                        # Route calculation failed
                        error_msg = result.get("error", "Could not calculate route") if result else "Could not calculate route"
                        response_text = f"Sorry, {error_msg}"
                        navigation_data = None
                else:
                    # No valid location provided - wait for WebSocket location updates
                    if request.lat == 0.0 and request.lon == 0.0:
                        print("⏳ Received (0.0, 0.0) coordinates - ignoring and waiting for real location via WebSocket/polling...")
                    else:
                        print("⏳ No valid location provided in request, waiting for location via WebSocket/polling...")
                    response_text = f"Starting navigation to {destination}. Waiting for your location..."
                    navigation_data = None
            
            # Send navigation response to TTS
            await _send_to_tts(response_text)

        elif intent == "STOP_NAVIGATION":
            action_type = "navigation"
            
            # Stop active navigation session
            nav_manager = get_navigation_session_manager()
            nav_manager.stop_navigation()
            
            response_text = "Navigation stopped."
            navigation_data = None
            
            # Send response to TTS
            await _send_to_tts(response_text)

        elif intent == "FACE_RECOGNITION":
            action_type = "vision"
            
            # Regular face recognition flow (enrollment state already handled above)
            # Capture image from Pi if not provided
            image_data = request.image_data
            if not image_data:
                image_data = await _capture_image_from_pi()
                if not image_data:
                    response_text = "I couldn't capture an image. Please try again."
                    await _send_to_tts(response_text)
                    return AssistantResponse(
                        response_text=response_text,
                        action_type=action_type,
                        timestamp=datetime.utcnow(),
                        navigation_data=None
                    )
            
            # Recognize faces
            result = await vision_service.recognize_face(image_data)
            
            # Check if face was not recognized (Unknown)
            if "don't recognize" in result or "unrecognized" in result:
                # Cache the image and prompt for enrollment
                enrollment_cache[request.user_id] = {
                    "image_base64": image_data,
                    "timestamp": datetime.utcnow(),
                    "state": "awaiting_confirmation"
                }
                response_text = result + " Would you like me to enroll them? Say yes or no."
            else:
                # Face was recognized successfully
                response_text = result
            
            # Send face recognition response to TTS
            await _send_to_tts(response_text)

        # elif intent == "OBJECT_DETECTION":
        #     action_type = "vision"
            
        #     # Check if this is a start/stop command
        #     query_lower = request.query.lower()
            
        #     detection_session = get_detection_session()
            
        #     if "start" in query_lower or "begin" in query_lower or "scanning" in query_lower:
        #         # Start continuous object detection
        #         session_id = f"od_{uuid.uuid4().hex[:8]}"
        #         result = await detection_session.start_detection(session_id)
                
        #         if "error" in result:
        #             response_text = result["error"]
        #         else:
        #             response_text = "Starting object detection. I'll tell you what I see every few seconds. Say 'stop object detection' when you're done."
            
        #     elif "stop" in query_lower or "end" in query_lower:
        #         # Stop continuous object detection
        #         result = await detection_session.stop_detection()
                
        #         if "error" in result:
        #             response_text = result["error"]
        #         else:
        #             response_text = "Object detection stopped."
            
        #     else:
        #         # Single-shot detection
        #         # Auto-capture from Pi if no image provided
        #         image_data = request.image_data
        #         if not image_data:
        #             image_data = await _capture_image_from_pi()
        #             if not image_data:
        #                 response_text = "I couldn't capture an image. Please try again or say 'start object detection' for continuous scanning."
        #                 await _send_to_tts(response_text)
        #                 return AssistantResponse(
        #                     response_text=response_text,
        #                     action_type=action_type,
        #                     timestamp=datetime.utcnow(),
        #                     navigation_data=None
        #                 )
                
        #         # Detect objects in image
        #         response_text = await vision_service.detect_objects(image_data)
            
        #     # Send object detection response to TTS (both continuous control and single-shot)
        #     await _send_to_tts(response_text)

        elif intent == "OBJECT_DETECTION":
            action_type = "vision"
            
            # Check if this is a start/stop command
            query_lower = request.query.lower()
            
            # Import continuous detection service
            from app.services.continuous_object_detection_service import get_continuous_detection_service
            detection_service = get_continuous_detection_service()
            
            if "stop" in query_lower or "end" in query_lower:
                # Stop continuous object detection
                result = await detection_service.stop_continuous_detection()
                
                if result.get("success"):
                    images_processed = result.get("images_processed", 0)
                    response_text = f"Object detection stopped. I processed {images_processed} images."
                else:
                    response_text = f"Failed to stop object detection: {result.get('error', 'Unknown error')}"
            
            elif "start" in query_lower or "begin" in query_lower or "scanning" in query_lower:
                # Start continuous object detection
                result = await detection_service.start_continuous_detection(interval_seconds=2.0)
                
                if result.get("success"):
                    response_text = "Starting object detection. I'll tell you what I see every few seconds. Say 'stop object detection' when you're done."
                else:
                    response_text = f"Failed to start object detection: {result.get('error', 'Unknown error')}"
            
            # else:
            #     # Single-shot detection (capture one image and detect)
            #     image_data = request.image_data
            #     if not image_data:
            #         image_data = await _capture_image_from_pi()
            #         if not image_data:
            #             response_text = "I couldn't capture an image. Please try again or say 'start object detection' for continuous scanning."
            #             await _send_to_tts(response_text)
            #             return AssistantResponse(
            #                 response_text=response_text,
            #                 action_type=action_type,
            #                 timestamp=datetime.utcnow(),
            #                 navigation_data=None
            #             )
                
            #     # Use the detection service for single-shot too
            #     result = await detection_service.process_image(image_data)
            #     response_text = result.get("speech_text", "I couldn't detect any objects.")
            
            # Send response to TTS
            await _send_to_tts(response_text)


        elif intent == "TRANSLATION":
            action_type = "translation"
            
            # ALWAYS translate to English (TTS can only read English properly)
            target_lang = "en"
            
            if request.image_data:
                # Image translation: Gemini OCR → LibreTranslate
                response_text = await translate_service.translate_image(request.image_data, target_lang)
            else:
                # Text translation: LibreTranslate only
                # Extract text to translate by removing common translation command patterns
                clean_query = request.query
                clean_query = clean_query.replace("translate this:", "").replace("translate this", "")
                clean_query = clean_query.replace("translate:", "").replace("translate", "")
                clean_query = clean_query.replace("this:", "").replace("this", "")
                clean_query = clean_query.strip()
                response_text = await translate_service.translate_text(clean_query, target_lang)
            
            # Send translation response to TTS
            await _send_to_tts(response_text)

        else:
            # Default to Gemini (Chat)
            action_type = "chat"
            response_text = await gemini_service.ask(request.query)
            
            # Send chat response to TTS
            await _send_to_tts(response_text)

        return AssistantResponse(
            response_text=response_text,
            action_type=action_type,
            timestamp=datetime.utcnow(),
            navigation_data=navigation_data # <--- Sending the complex data back
        )

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))