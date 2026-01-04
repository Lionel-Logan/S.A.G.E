from fastapi import APIRouter, Depends, HTTPException
from app.models.schemas import TranslationRequest, TranslationResponse
from app.services.ocr_service import OCRService
from app.services.translate_service import TranslateService
from app.dependencies import get_current_user
from datetime import datetime

router = APIRouter(prefix="/translation", tags=["Translation"])

@router.post("/translate", response_model=TranslationResponse)
async def translate_image_text(
    request: TranslationRequest,
    current_user = Depends(get_current_user)
):
    """
    Complete translation workflow:
    1. Extract text from image (OCR)
    2. Translate to target language
    3. Return both original and translated text
    
    This is what the Pi Camera captures → Flutter sends here
    """
    try:
        # Step 1: OCR
        ocr_service = OCRService()
        original_text = await ocr_service.extract_text(request.image_base64)
        
        if not original_text:
            raise HTTPException(400, "No text detected in image")
        
        # Step 2: Translate
        translate_service = TranslateService()
        translated_text = await translate_service.translate(
            original_text,
            request.source_lang,
            request.target_lang
        )
        
        return TranslationResponse(
            original_text=original_text,
            translated_text=translated_text,
            confidence=0.95,  # Would come from OCR in real impl
            source_lang=request.source_lang,
            target_lang=request.target_lang
        )
    except Exception as e:
        raise HTTPException(500, f"Translation failed: {str(e)}")