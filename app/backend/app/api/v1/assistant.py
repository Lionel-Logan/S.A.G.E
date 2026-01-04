from fastapi import APIRouter, Depends, HTTPException
from app.models.schemas import AssistantRequest, AssistantResponse
from app.services.gemini_service import GeminiService
from app.dependencies import get_current_user
from datetime import datetime

router = APIRouter(prefix="/assistant", tags=["AI Assistant"])

@router.post("/ask", response_model=AssistantResponse)
async def ask_assistant(
    request: AssistantRequest,
    current_user = Depends(get_current_user)
):
    """
    Ask the AI assistant a question
    
    Triggered by "Hey Glass" wake word
    User speech → Flutter STT → This endpoint → Gemini → Response
    """
    try:
        service = GeminiService()
        response_text = await service.ask(request.query, request.context)
        
        return AssistantResponse(
            response=response_text,
            timestamp=datetime.utcnow()
        )
    except Exception as e:
        raise HTTPException(500, f"Assistant error: {str(e)}")