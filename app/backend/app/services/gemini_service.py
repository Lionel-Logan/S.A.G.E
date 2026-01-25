import google.generativeai as genai
from app.config import settings
from app.core.utils import decode_image # Make sure utils.py exists
import PIL.Image
import cv2

# OLD LINE: genai.configure(api_key=settings.GEMINI_API_KEY)

# NEW LINE: Force "rest" transport to stop the crashes
genai.configure(api_key=settings.GEMINI_API_KEY, transport="rest")
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
            # Using async generation
            response = self.model.generate_content(prompt)
            return response.text
        except Exception as e:
            # Print the actual error to the terminal so we can see it
            print(f"🔥 Gemini Error: {str(e)}")
            return "I'm having trouble connecting to my brain right now."

        # 👇 THIS IS THE METHOD YOU MUST HAVE FOR YOUR CODE TO WORK 👇
    async def ask_with_image(self, prompt: str, base64_image: str) -> str:
        try:
            cv_img = decode_image(base64_image)
            if cv_img is None:
                return "Error: Invalid image data."

            # Convert to PIL for Gemini
            color_converted = cv2.cvtColor(cv_img, cv2.COLOR_BGR2RGB)
            pil_image = PIL.Image.fromarray(color_converted)

            response = self.model.generate_content([prompt, pil_image])
            return response.text
        except Exception as e:
            return f"AI Vision Error: {str(e)}"