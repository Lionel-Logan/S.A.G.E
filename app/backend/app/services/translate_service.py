from app.services.gemini_service import GeminiService
from app.services.libre_service import LibreTranslateService


class TranslateService:
    """
    Hybrid Translation Service:
    - Text translation: LibreTranslate (fast, free, offline-capable)
    - Image translation: Gemini OCR → LibreTranslate translation
    """
    
    def __init__(self):
        self.ocr_engine = GeminiService()  # For reading text from images
        self.translator = LibreTranslateService()  # For actual translation
    
    async def close(self):
        """Cleanup clients"""
        await self.translator.close()
    
    def _get_language_name(self, lang_code: str) -> str:
        """Convert language code to readable name for voice output"""
        lang_map = {
            "en": "English",
            "es": "Spanish",
            "fr": "French",
            "de": "German",
            "hi": "Hindi",
            "zh": "Chinese",
            "ja": "Japanese",
            "ar": "Arabic",
            "pt": "Portuguese",
            "ru": "Russian",
            "it": "Italian",
            "ko": "Korean"
        }
        return lang_map.get(lang_code.lower(), lang_code)

    async def translate_text(self, text: str, target_lang: str = "es") -> str:
        """
        Translate plain text using LibreTranslate
        
        Args:
            text: Text to translate
            target_lang: Target language code (default: Spanish)
            
        Returns:
            Voice-friendly translation result
        """
        try:
            # Detect source language
            source_lang = await self.translator.detect_language(text)
            
            # Translate using LibreTranslate
            translated = await self.translator.translate(text, target_lang, source_lang)
            
            # Voice-friendly output
            if source_lang == target_lang:
                return f"That's already in {self._get_language_name(target_lang)}."
            
            return translated
            
        except Exception as e:
            print(f"Translation error: {e}")
            return f"Translation failed: {str(e)}"

    async def translate_image(self, image_data: str, target_lang: str = "es") -> str:
        """
        Hybrid Pipeline for image translation:
        1. Use Gemini to extract text from image (OCR)
        2. Use LibreTranslate to translate the extracted text
        
        Args:
            image_data: Base64 encoded image
            target_lang: Target language code (default: Spanish)
            
        Returns:
            Voice-friendly format with original and translation
        """
        try:
            # Step 1: OCR using Gemini
            ocr_prompt = "Read all the text you see in this image. Output ONLY the raw text, exactly as it appears. Do not translate or interpret it."
            extracted_text = await self.ocr_engine.ask_with_image(ocr_prompt, image_data)
            
            # Check if OCR was successful
            if not extracted_text or len(extracted_text.strip()) < 3:
                return "I don't see any readable text in this image."
            
            if "error" in extracted_text.lower() or "cannot" in extracted_text.lower():
                return "I could not read the text in that image."
            
            # Clean up extracted text
            extracted_text = extracted_text.strip()
            
            # Step 2: Detect source language
            source_lang = await self.translator.detect_language(extracted_text)
            
            # Step 3: Translate using LibreTranslate
            if source_lang == target_lang:
                return f"The text says: {extracted_text}. It's already in {self._get_language_name(target_lang)}."
            
            translated_text = await self.translator.translate(extracted_text, target_lang, source_lang)
            
            # Voice-friendly output format
            return f"Original text: {extracted_text}. In {self._get_language_name(target_lang)}: {translated_text}."
            
        except Exception as e:
            print(f"Image translation error: {e}")
            return f"Image translation failed: {str(e)}"