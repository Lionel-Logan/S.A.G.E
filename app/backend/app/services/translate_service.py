import httpx
from typing import Optional
from app.config import settings

class TranslateService:
    """
    Client for LibreTranslate API
    Uses the free public API or your self-hosted instance
    """
    
    def __init__(self):
        self.base_url = settings.LIBRETRANSLATE_URL
        self.api_key = getattr(settings, 'LIBRETRANSLATE_API_KEY', None)
    
    async def translate(
        self, 
        text: str, 
        source_lang: str = "auto", 
        target_lang: str = "en"
    ) -> dict:
        """
        Translate text using LibreTranslate API
        
        Args:
            text: Text to translate
            source_lang: Source language code (e.g., "en", "hi", "es") or "auto"
            target_lang: Target language code
        
        Returns:
            dict with 'translatedText' and 'detectedLanguage' (if source was auto)
        """
        async with httpx.AsyncClient(timeout=30.0) as client:
            payload = {
                "q": text,
                "source": source_lang,
                "target": target_lang,
                "format": "text"
            }
            
            # Add API key if available (for higher rate limits)
            if self.api_key:
                payload["api_key"] = self.api_key
            
            try:
                response = await client.post(
                    f"{self.base_url}/translate",
                    json=payload,
                    headers={"Content-Type": "application/json"}
                )
                response.raise_for_status()
                return response.json()
            
            except httpx.HTTPStatusError as e:
                raise Exception(f"Translation API error: {e.response.status_code} - {e.response.text}")
            except Exception as e:
                raise Exception(f"Translation failed: {str(e)}")
    
    async def get_supported_languages(self) -> list:
        """Get list of supported languages"""
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"{self.base_url}/languages")
            response.raise_for_status()
            return response.json()