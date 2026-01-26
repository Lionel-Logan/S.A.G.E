import httpx
from app.config import settings

class LibreService:
    def __init__(self):
        # Public mirror (limit 15 req/minute) or your local instance
        # If running locally via Docker: "http://localhost:5000"
        self.base_url = "https://libretranslate.com" 

    async def translate(self, text: str, target_lang: str = "es") -> str:
        """
        Sends text to LibreTranslate.
        """
        url = f"{self.base_url}/translate"
        
        payload = {
            "q": text,
            "source": "auto", # Auto-detect language
            "target": target_lang,
            "format": "text"
        }
        
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(url, json=payload, timeout=10.0)
                
            if resp.status_code == 200:
                return resp.json().get("translatedText", "Translation failed.")
            else:
                return f"LibreTranslate Error: {resp.status_code}"
                
        except Exception as e:
            return f"Translation Service Error: {str(e)}"