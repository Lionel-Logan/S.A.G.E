import google.generativeai as genai
from app.config import settings

genai.configure(api_key=settings.GEMINI_API_KEY)

class GeminiService:
    def __init__(self):
        self.model = genai.GenerativeModel('gemini-2.5-flash')
    
    async def ask(self, query: str, context: str = None) -> str:
        """
        Ask Gemini a question
        
        Args:
            query: User's question
            context: Optional context (e.g., "User is looking at a restaurant menu")
        
        Returns:
            Gemini's response text
        """
        try:
            prompt = query
            if context:
                prompt = f"Context: {context}\n\nQuestion: {query}"
            
            response = self.model.generate_content(prompt)
            return response.text
        except Exception as e:
            raise Exception(f"Gemini API error: {str(e)}")