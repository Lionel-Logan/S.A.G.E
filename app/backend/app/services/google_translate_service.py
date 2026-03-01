import httpx
from typing import Optional
from app.config import settings
from app.core.exceptions import TranslationError


class GoogleTranslateService:
    """
    Client for Google Cloud Translation API (v2 REST)
    Uses API key authentication via direct REST calls.
    """
    
    BASE_URL = "https://translation.googleapis.com/language/translate/v2"
    
    def __init__(self):
        self.api_key = settings.GOOGLE_TRANSLATE_API_KEY
        self.client = httpx.AsyncClient(timeout=15)
    
    async def close(self):
        """Close the HTTP client"""
        await self.client.aclose()
    
    async def detect_language(self, text: str) -> str:
        """
        Detect the language of input text using Google Translate REST API.
        
        Args:
            text: Text to detect language for
            
        Returns:
            Language code (e.g., 'en', 'es', 'fr')
        """
        try:
            response = await self.client.post(
                f"{self.BASE_URL}/detect",
                params={"key": self.api_key},
                json={"q": text}
            )
            response.raise_for_status()
            data = response.json()
            detections = data.get("data", {}).get("detections", [[]])
            if detections and detections[0]:
                return detections[0][0].get("language", "en")
            return "en"
            
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
        Translate text using Google Translate REST API.
        
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
            
            payload = {
                "q": text,
                "target": target_lang,
                "format": "text"
            }
            if source_lang:
                payload["source"] = source_lang

            response = await self.client.post(
                self.BASE_URL,
                params={"key": self.api_key},
                json=payload
            )
            response.raise_for_status()
            data = response.json()
            
            translations = data.get("data", {}).get("translations", [])
            if translations:
                return translations[0].get("translatedText", text)
            return text
            
        except httpx.HTTPStatusError as e:
            raise TranslationError(f"Google Translate API error {e.response.status_code}: {e.response.text}")
        except Exception as e:
            raise TranslationError(f"Translation failed: {str(e)}")
    
    async def get_supported_languages(self) -> list:
        """
        Get list of supported languages from Google Translate.
        
        Returns:
            List of language dicts with 'code' and 'name'
        """
        try:
            response = await self.client.get(
                f"{self.BASE_URL}/languages",
                params={"key": self.api_key, "target": "en"}
            )
            response.raise_for_status()
            data = response.json()
            languages = data.get("data", {}).get("languages", [])
            return [{"code": lang["language"], "name": lang.get("name", lang["language"])} 
                    for lang in languages]
        except Exception as e:
            print(f"Error fetching supported languages: {e}")
            return [
                {"code": "en", "name": "English"},
                {"code": "es", "name": "Spanish"},
                {"code": "fr", "name": "French"},
                {"code": "de", "name": "German"},
                {"code": "hi", "name": "Hindi"},
                {"code": "zh", "name": "Chinese"},
                {"code": "ja", "name": "Japanese"},
                {"code": "ar", "name": "Arabic"},
                {"code": "pt", "name": "Portuguese"},
                {"code": "ru", "name": "Russian"},
                {"code": "it", "name": "Italian"},
                {"code": "ko", "name": "Korean"}
            ]

