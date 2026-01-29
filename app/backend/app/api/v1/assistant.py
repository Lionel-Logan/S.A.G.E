from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any # Added Dict, Any for the new response field
from datetime import datetime
import re
# Import Services
from app.services.intent_router import IntentRouter
from app.services.gemini_service import GeminiService
from app.services.vision_service import VisionService
from app.services.navigation_service import NavigationService
from app.services.translate_service import TranslateService # <--- ADDED THIS

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
            if not request.image_data:
                response_text = "I need to see to recognize faces. No image received."
            else:
                response_text = await vision_service.recognize_face(request.image_data)

        elif intent == "OBJECT_DETECTION":
            action_type = "vision"
            if not request.image_data:
                 response_text = "I need to see to detect objects. No image received."
            else:
                response_text = await vision_service.detect_objects(request.image_data)

        elif intent == "TRANSLATION":
            action_type = "translation"
            target_lang = "fr" # You can make this dynamic later
            
            if request.image_data:
                response_text = await translate_service.translate_image(request.image_data, target_lang)
            else:
                clean_query = request.query.replace("translate", "").strip()
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