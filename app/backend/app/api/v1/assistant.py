from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any # Added Dict, Any for the new response field
from datetime import datetime
import re
import uuid
# Import Services
from app.services.intent_router import IntentRouter
from app.services.gemini_service import GeminiService
from app.services.vision_service import VisionService
from app.services.navigation_service import NavigationService
from app.services.translate_service import TranslateService
from app.services.object_detection_session import get_detection_session

router = APIRouter(prefix="/assistant", tags=["AI Assistant"])

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
        # 1. Predict Intent (Hybrid: Rule-based + Gemini fallback)
        intent = await intent_router.predict_intent(request.query)
        print(f"User said: {request.query} -> Detected Intent: {intent}")

        response_text = ""
        action_type = "chat"
        navigation_data = None # Default to None

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

        elif intent == "FACE_RECOGNITION":
            action_type = "vision"
            
            # Check if this is an enrollment request
            query_lower = request.query.lower()
            
            if "enroll" in query_lower or "register" in query_lower or "add" in query_lower:
                # Enrollment mode: extract name and optional description
                if not request.image_data:
                    response_text = "I need an image to enroll a new face."
                else:
                    # Extract name from query (simple pattern matching)
                    # Patterns: "enroll [name]", "register [name]", "add [name] as [description]"
                    import re
                    
                    # Try to extract name and description
                    # Pattern: "enroll John" or "enroll John as friend"
                    match = re.search(r"(?:enroll|register|add)\s+([\w\s]+?)(?:\s+as\s+([\w\s]+))?(?:\s*$|\.|,)", query_lower, re.IGNORECASE)
                    
                    if match:
                        name = match.group(1).strip()
                        description = match.group(2).strip() if match.group(2) else ""
                        
                        response_text = await vision_service.enroll_face(name, request.image_data, description)
                    else:
                        response_text = "Please specify a name to enroll. For example: 'Enroll John' or 'Enroll Sarah as colleague'."
            else:
                # Recognition mode
                if not request.image_data:
                    response_text = "I need to see to recognize faces. No image received."
                else:
                    response_text = await vision_service.recognize_face(request.image_data)

        elif intent == "OBJECT_DETECTION":
            action_type = "vision"
            
            # Check if this is a start/stop command
            query_lower = request.query.lower()
            
            detection_session = get_detection_session()
            
            if "start" in query_lower or "begin" in query_lower or "scanning" in query_lower:
                # Start continuous object detection
                session_id = f"od_{uuid.uuid4().hex[:8]}"
                result = await detection_session.start_detection(session_id)
                
                if "error" in result:
                    response_text = result["error"]
                else:
                    response_text = "Starting object detection. I'll tell you what I see every few seconds. Say 'stop object detection' when you're done."
            
            elif "stop" in query_lower or "end" in query_lower:
                # Stop continuous object detection
                result = await detection_session.stop_detection()
                
                if "error" in result:
                    response_text = result["error"]
                else:
                    response_text = "Object detection stopped."
            
            else:
                # Single-shot detection with provided image --not continuous scanning
                if not request.image_data:
                    response_text = "I need to see to detect objects. Please provide an image or say 'start object detection' for continuous scanning."
                else:
                    response_text = await vision_service.detect_objects(request.image_data)

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

        else:
            # Default to Gemini (Chat)
            action_type = "chat"
            response_text = await gemini_service.ask(request.query)

        return AssistantResponse(
            response_text=response_text,
            action_type=action_type,
            timestamp=datetime.utcnow(),
            navigation_data=navigation_data # <--- Sending the complex data back
        )

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))