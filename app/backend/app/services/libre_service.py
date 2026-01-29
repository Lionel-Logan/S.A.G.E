import httpx
from typing import Optional
from app.config import settings
from app.core.exceptions import TranslationError


class LibreTranslateService:
    """
    Client for LibreTranslate API
    Handles text translation using open-source LibreTranslate service
    Can be self-hosted or use public instance
    """
    
    def __init__(self):
        self.base_url = settings.LIBRETRANSLATE_URL.rstrip('/')
        self.timeout = 15
        self.client = httpx.AsyncClient(timeout=self.timeout)
    
    async def close(self):
        """Close the HTTP client"""
        await self.client.aclose()
    
    async def detect_language(self, text: str) -> str:
        """
        Detect the language of input text
        
        Args:
            text: Text to detect language for
            
        Returns:
            Language code (e.g., 'en', 'es', 'fr')
        """
        try:
            response = await self.client.post(
                f"{self.base_url}/detect",
                json={"q": text}
            )
            response.raise_for_status()
            result = response.json()
            
            if isinstance(result, list) and len(result) > 0:
                return result[0].get("language", "en")
            return "en"  # Default to English if detection fails
            
        except Exception as e:
            print(f"Language detection error: {e}")
            return "en"  # Fallback to English
    
    async def translate(
        self, 
        text: str, 
        target_lang: str, 
        source_lang: Optional[str] = None
    ) -> str:
        """
        Translate text using LibreTranslate
        
        Args:
            text: Text to translate
            target_lang: Target language code (e.g., 'es', 'fr', 'de', 'hi')
            source_lang: Source language code (auto-detect if None)
            
        Returns:
            Translated text
        """
        try:
            # Auto-detect source language if not provided
            if source_lang is None:
                source_lang = await self.detect_language(text)
            
            # Skip translation if source and target are the same
            if source_lang == target_lang:
                return text
            
            # Call LibreTranslate API
            response = await self.client.post(
                f"{self.base_url}/translate",
                json={
                    "q": text,
                    "source": source_lang,
                    "target": target_lang,
                    "format": "text"
                }
            )
            response.raise_for_status()
            result = response.json()
            
            return result.get("translatedText", text)
            
        except httpx.HTTPError as e:
            raise TranslationError(f"LibreTranslate API error: {str(e)}")
        except Exception as e:
            raise TranslationError(f"Translation failed: {str(e)}")
    
    async def get_supported_languages(self) -> list:
        """
        Get list of supported languages
        
        Returns:
            List of language dicts with 'code' and 'name'
        """
        try:
            response = await self.client.get(f"{self.base_url}/languages")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Error fetching supported languages: {e}")
            # Return common languages as fallback
            return [
                {"code": "en", "name": "English"},
                {"code": "es", "name": "Spanish"},
                {"code": "fr", "name": "French"},
                {"code": "de", "name": "German"},
                {"code": "hi", "name": "Hindi"},
                {"code": "zh", "name": "Chinese"},
                {"code": "ja", "name": "Japanese"},
                {"code": "ar", "name": "Arabic"}
            ]