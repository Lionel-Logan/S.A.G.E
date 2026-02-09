import google.generativeai as genai
from app.config import settings
from app.core.utils import decode_image
import PIL.Image
import cv2

class GeminiService:
    def __init__(self):
        # Configure Gemini with API key
        genai.configure(api_key=settings.GEMINI_API_KEY)
        self.model_name = 'models/gemini-2.0-flash'
        self.model = genai.GenerativeModel(self.model_name)
        
        # System prompt defining S.A.G.E's personality and response style
        self.system_prompt = """You are S.A.G.E (Situational Awareness & Guidance Engine), an AI assistant for smartglasses.

Your role:
- Provide helpful, concise, voice-friendly responses
- Keep responses brief (2-3 sentences typically, more if the question requires detail)
- Use casual, friendly language - speak naturally like a helpful companion
- Avoid markdown, special formatting, or symbols that don't work well in speech
- Prioritize actionable information over explanations

Remember: The user is wearing smartglasses and will hear your response through audio. Be conversational and direct."""
    
    async def ask(self, query: str, context: str = None) -> str:
        """
        Ask Gemini a question with S.A.G.E personality and response optimization.
        
        Args:
            query: User's question
            context: Optional context (e.g., "User is looking at a restaurant menu")
        
        Returns:
            Gemini's response text
        """
        try:
            # Build the prompt with system instructions
            if context:
                prompt = f"""{self.system_prompt}

Context: {context}

User query: {query}

Respond naturally and concisely."""
            else:
                prompt = f"""{self.system_prompt}

User query: {query}

Respond naturally and concisely."""
            
            # Using async generation
            response = await self.model.generate_content_async(prompt)
            return response.text
        except Exception as e:
            # Print the actual error to the terminal so we can see it
            print(f"🔥 Gemini Error: {str(e)}")
            return "I'm having trouble connecting to my brain right now."

        # 👇 THIS IS THE METHOD YOU MUST HAVE FOR YOUR CODE TO WORK 👇
    async def ask_with_image(self, prompt: str, base64_image: str) -> str:
        """
        Ask Gemini about an image with S.A.G.E personality.
        
        Args:
            prompt: Question about the image
            base64_image: Base64 encoded image data
            
        Returns:
            Gemini's response text
        """
        try:
            cv_img = decode_image(base64_image)
            if cv_img is None:
                return "Error: Invalid image data."

            # Convert to PIL for Gemini
            color_converted = cv2.cvtColor(cv_img, cv2.COLOR_BGR2RGB)
            pil_image = PIL.Image.fromarray(color_converted)

            # Add S.A.G.E personality to image queries
            enhanced_prompt = f"""{self.system_prompt}

User query: {prompt}

Respond naturally and concisely."""

            response = await self.model.generate_content_async([enhanced_prompt, pil_image])
            return response.text
        except Exception as e:
            return f"AI Vision Error: {str(e)}"