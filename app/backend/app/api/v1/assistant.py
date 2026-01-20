from fastapi import APIRouter, Depends, HTTPException
from app.models.schemas import AssistantRequest, AssistantResponse
from app.services.gemini_service import GeminiService
from app.services.intent_router import IntentRouter # <-- Import the new router
from app.dependencies import get_current_user
from datetime import datetime

router = APIRouter(prefix="/assistant", tags=["AI Assistant"])

@router.post("/ask", response_model=AssistantResponse)
async def ask_assistant(request: AssistantRequest):
    try:
        # 1. Identify what the user wants
        router_service = IntentRouter()
        intent = router_service.predict_intent(request.query)
        
        response_text = ""
        
        # 2. Route the logic
        if intent == "SCAN":
            # In the future, this could trigger the object detection module directly
            response_text = "I am switching to Object Detection mode. Please look at the object."
            
        elif intent == "READ":
            response_text = "I am switching to Reading mode. Please hold the text steady."
            
        else: # Intent is "CHAT"
            # 3. Only call Gemini if it's a chat question
            gemini = GeminiService()
            response_text = await gemini.ask(request.query, request.context)
        
        return AssistantResponse(
            response=response_text,
            timestamp=datetime.utcnow()
        )
            
    except Exception as e:
        raise HTTPException(500, f"Error: {str(e)}")
