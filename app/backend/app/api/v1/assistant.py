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
            
            # A. Check for GPS
            if request.lat is None or request.lon is None:
                response_text = "I need your GPS location to provide directions."
            
            else:
                # B. INTELLIGENT CLEANING (The Upgrade)
                # This pattern looks for:
                # 1. Any command verbs (navigate, go, take me, etc.)
                # 2. Optional prepositions (to, for)
                # 3. CAPTURES everything after that as 'destination'
                
                # Regex Explanation:
                # (?: ... ) -> Non-capturing group (just matches)
                # \s+       -> One or more spaces
                # (.+)      -> Capture everything else (The Destination)
                pattern = r"(?:navigate|go|take me|directions|route|find|head)(?:\s+to|\s+for)?\s+(.+)"
                
                match = re.search(pattern, request.query, re.IGNORECASE)
                
                if match:
                    destination = match.group(1).strip() # Extracts "Lulu Mall"
                else:
                    # Fallback: If the user just said "Lulu Mall" without "Navigate to"
                    destination = request.query.strip()

                # C. Call the Service
                if not destination:
                    response_text = "Where would you like to go?"
                else:
                    # Expecting a DICTIONARY response now (not just a string)
                    nav_result = await navigation_service.get_directions(
                        start_lon=request.lon,
                        start_lat=request.lat,
                        destination_query=destination
                    )

                    # D. Handle the Result
                    if "error" in nav_result:
                        response_text = nav_result["error"]
                    else:
                        # Success! Create a summary for voice using formatted data
                        time_text = nav_result.get('total_time_text', f"about {nav_result['total_time_min']} minutes")
                        distance_text = nav_result.get('distance_text', f"{nav_result['total_distance']} {nav_result['distance_unit']}")
                        eta = nav_result.get('eta', '')
                        
                        # The voice says this (natural and informative):
                        response_text = f"Route found to {destination}. It's {distance_text} away and will take {time_text}. You should arrive around {eta}. I've sent the step-by-step directions to your screen."
                        
                        # The app gets this (Step-by-Step data):
                        navigation_data = nav_result
            
            # Send navigation response to TTS
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
            
            # Extract target language from query (default to Spanish if not specified)
            query_lower = request.query.lower()
            
            # Simple language extraction: "translate to spanish", "translate this to french"
            target_lang = "es"  # Default: Spanish
            
            if "spanish" in query_lower or "español" in query_lower:
                target_lang = "es"
            elif "french" in query_lower or "français" in query_lower:
                target_lang = "fr"
            elif "german" in query_lower or "deutsch" in query_lower:
                target_lang = "de"
            elif "hindi" in query_lower:
                target_lang = "hi"
            elif "chinese" in query_lower or "mandarin" in query_lower:
                target_lang = "zh"
            elif "japanese" in query_lower:
                target_lang = "ja"
            elif "arabic" in query_lower:
                target_lang = "ar"
            elif "portuguese" in query_lower:
                target_lang = "pt"
            elif "russian" in query_lower:
                target_lang = "ru"
            elif "italian" in query_lower:
                target_lang = "it"
            elif "korean" in query_lower:
                target_lang = "ko"
            
            if request.image_data:
                # Image translation: Gemini OCR → LibreTranslate
                response_text = await translate_service.translate_image(request.image_data, target_lang)
            else:
                # Text translation: LibreTranslate only
                clean_query = request.query.replace("translate", "").replace("to spanish", "").replace("to french", "").replace("to german", "").strip()
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