from google import genai
from google.oauth2 import service_account
from app.config import settings
from app.core.utils import decode_image
import PIL.Image
import cv2

def _load_vertex_credentials():
    """Load Vertex AI credentials from service account JSON."""
    return service_account.Credentials.from_service_account_file(
        settings.GOOGLE_VISION_CREDENTIALS,
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )

class GeminiService:
    def __init__(self):
        # Authenticate using service account credentials
        self.client = genai.Client(
            vertexai=True,
            project=settings.GOOGLE_CLOUD_PROJECT,
            location=settings.GOOGLE_CLOUD_LOCATION,
            credentials=_load_vertex_credentials()
        )
        self.model_name = 'gemini-2.5-flash'
        print(f"✅ Gemini initialized via Vertex AI (project={settings.GOOGLE_CLOUD_PROJECT}, location={settings.GOOGLE_CLOUD_LOCATION})")
        print(f"🔑 Auth: Service account ({settings.GOOGLE_VISION_CREDENTIALS})")
        
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
            response = await self.client.aio.models.generate_content(
                model=self.model_name, contents=prompt
            )
            response_text = response.text
            
            # Log successful response
            print(f"🤖 Gemini Response: {response_text[:200]}{'...' if len(response_text) > 200 else ''}")
            
            return response_text
        except Exception as e:
            error_str = str(e)
            # Print the actual error to the terminal so we can see it
            print(f"🔥 Gemini Error: {error_str}")
            
            # Handle rate limit errors specifically
            if "429" in error_str or "quota" in error_str.lower() or "rate limit" in error_str.lower():
                return "I've reached my thinking limit for now. Please try again in a minute, or ask me about navigation, translation, or object detection instead."
            elif "401" in error_str or "invalid" in error_str.lower():
                return "My API key seems to have an issue. Please contact support."
            else:
                return "I'm having trouble connecting to my brain right now. Try again in a moment."

    async def ask_with_search(self, query: str, search_results: list) -> str:
        """
        Ask Gemini a question using real-time web search results.
        Synthesizes answer based on latest information from search results.
        
        Args:
            query: User's question
            search_results: List of search result dicts with keys: title, snippet, url, published_date
        
        Returns:
            Gemini's synthesized response with citations
        """
        try:
            # Format search results into a readable string
            sources_text = "Recent sources:\n"
            for i, result in enumerate(search_results, 1):
                date_str = f" ({result.get('published_date', 'N/A')})" if result.get('published_date') != 'N/A' else ""
                sources_text += f"{i}. {result.get('title', 'No title')}{date_str}\n"
                sources_text += f"   URL: {result.get('url', '')}\n"
                sources_text += f"   Snippet: {result.get('snippet', '')}\n\n"
            
            # Build prompt with search results
            prompt = f"""{self.system_prompt}

You have access to recent web search results. Use these to provide the most current and accurate answer.

{sources_text}

User query: {query}

Based on the sources above, provide a helpful and accurate answer. Be conversational and cite the sources when relevant.
Keep your answer brief (2-3 sentences) and suitable for voice output."""

            # Generate response using Gemini
            response = await self.client.aio.models.generate_content(
                model=self.model_name, contents=prompt
            )
            response_text = response.text
            
            # Log successful response
            print(f"🤖 Gemini Response (with search): {response_text[:200]}{'...' if len(response_text) > 200 else ''}")
            
            return response_text
        except Exception as e:
            error_str = str(e)
            print(f"🔥 Gemini Search Error: {error_str}")
            
            # Handle errors similarly to ask()
            if "429" in error_str or "quota" in error_str.lower() or "rate limit" in error_str.lower():
                return "I've reached my thinking limit for now. Please try again in a minute."
            elif "401" in error_str or "invalid" in error_str.lower():
                return "My API key seems to have an issue. Please contact support."
            else:
                return "I'm having trouble connecting my search results to my brain. Try again in a moment."

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

            response = await self.client.aio.models.generate_content(
                model=self.model_name, contents=[enhanced_prompt, pil_image]
            )
            response_text = response.text
            
            # Log successful vision response
            print(f"🤖 Gemini Vision Response: {response_text[:200]}{'...' if len(response_text) > 200 else ''}")
            
            return response_text
        except Exception as e:
            return f"AI Vision Error: {str(e)}"