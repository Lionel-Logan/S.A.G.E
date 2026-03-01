from google import genai
from google.oauth2 import service_account
from app.config import settings

def _load_vertex_credentials():
    """Load Vertex AI credentials from service account JSON."""
    return service_account.Credentials.from_service_account_file(
        settings.GOOGLE_VISION_CREDENTIALS,
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )

class IntentRouter:
    def __init__(self):
        # Authenticate using service account credentials
        self.client = genai.Client(
            vertexai=True,
            project=settings.GOOGLE_CLOUD_PROJECT,
            location=settings.GOOGLE_CLOUD_LOCATION,
            credentials=_load_vertex_credentials()
        )
        self.model_name = 'gemini-2.5-flash'
        
        # Load keyword patterns from config
        self.temporal_keywords = settings.TEMPORAL_KEYWORDS
        self.position_keywords = settings.POSITION_KEYWORDS

    async def _classify_with_gemini(self, text: str) -> str:
        """
        AI-powered classification using Gemini for ambiguous cases.
        
        Returns:
            Intent classification
        """
        prompt = f"""Classify the following user query into EXACTLY ONE of these categories:
- NAVIGATION (for directions, routes, navigation requests, starting navigation)
- STOP_NAVIGATION (for stopping, canceling, or ending active navigation)
- TRANSLATION (for reading text, translating, OCR requests)
- FACE_RECOGNITION (for identifying people, faces)
- OBJECT_DETECTION (for identifying objects, things in view, starting object detection or scanning)
- STOP_OBJECT_DETECTION (for stopping, canceling, or ending active object detection or environment scanning)
- ASSISTANT (for general chat, questions, other requests)

User query: "{text}"

Response format: Return ONLY the category name, nothing else."""

        try:
            response = await self.client.aio.models.generate_content(
                model=self.model_name, contents=prompt
            )
            intent = response.text.strip().upper()
            
            # Validate response
            valid_intents = ["NAVIGATION", "STOP_NAVIGATION", "TRANSLATION", "FACE_RECOGNITION", "OBJECT_DETECTION", "STOP_OBJECT_DETECTION", "ASSISTANT"]
            if intent in valid_intents:
                return intent
            else:
                print(f"⚠️ Gemini returned invalid intent: {intent}, defaulting to ASSISTANT")
                return "ASSISTANT"
        except Exception as e:
            print(f"⚠️ Gemini classification failed: {e}, using rule-based fallback")
            return "ASSISTANT"

    async def predict_intent(self, text: str) -> str:
        """
        Classify user intent using Gemini.
        """
        return await self._classify_with_gemini(text)

    def has_temporal_keywords(self, text: str) -> bool:
        """
        Layer 1: Check for temporal keywords (time-sensitive indicators).
        Fast pattern matching using keyword list.
        
        Examples:
        - "What's the latest AI news?" → True
        - "Tell me current weather" → True
        - "How do I cook rice?" → False
        """
        text_lower = text.lower()
        for keyword in self.temporal_keywords:
            if keyword.lower() in text_lower:
                print(f"📅 Temporal keyword detected: '{keyword}'")
                return True
        return False
    
    def has_position_keywords(self, text: str) -> bool:
        """
        Layer 2: Check for position/role keywords (who is X).
        Fast pattern matching for queries about positions/roles.
        
        Examples:
        - "Who is the PM of India?" → True
        - "Who is the CM of Maharashtra?" → True
        - "What is gravity?" → False
        """
        text_lower = text.lower()
        for keyword in self.position_keywords:
            if keyword.lower() in text_lower:
                print(f"👤 Position keyword detected: '{keyword}'")
                return True
        return False
    
    async def _classify_needs_search(self, text: str) -> bool:
        """
        Layer 3: Use Gemini to classify if uncertain cases need web search.
        Only called if Layers 1 & 2 didn't match.
        
        This handles edge cases like:
        - "What is the current population of India?"
        - "How much is Bitcoin worth right now?"
        - "Is Corona still spreading?"
        """
        prompt = f"""Determine if this query requires real-time web information to answer accurately.
Return YES if the question needs current/real-time data, NO if it's general knowledge.

Query: "{text}"

Examples of YES: "What's Bitcoin's current price?" "Is it raining in Delhi?" "Current US President?"
Examples of NO: "How do I cook rice?" "What is photosynthesis?" "Explain quantum mechanics"

Response: Return ONLY 'YES' or 'NO'"""

        try:
            response = await self.client.aio.models.generate_content(
                model=self.model_name, contents=prompt
            )
            answer = response.text.strip().upper()
            is_needed = "YES" in answer
            if is_needed:
                print(f"🔍 Layer 3 (Gemini): Web search needed for: {text[:50]}...")
            return is_needed
        except Exception as e:
            print(f"⚠️ Layer 3 classification failed: {e}, defaulting to NO")
            return False
    
    async def needs_web_search(self, query: str) -> bool:
        """
        Main method: Determine if query needs web search using 3-layer detection.
        
        Flow:
        1. Check temporal keywords (fast)
        2. Check position keywords (fast)
        3. Ask Gemini for uncertain cases (slower)
        
        Returns:
            True if web search needed, False otherwise
        """
        print(f"\n🔎 [WebSearch Check] Analyzing query: {query}")
        
        # Layer 1: Temporal keywords
        layer1_match = self.has_temporal_keywords(query)
        if layer1_match:
            print(f"✅ [Layer 1] Temporal keywords detected → Web search NEEDED")
            return True
        else:
            print(f"❌ [Layer 1] No temporal keywords")
        
        # Layer 2: Position/role keywords
        layer2_match = self.has_position_keywords(query)
        if layer2_match:
            print(f"✅ [Layer 2] Position keywords detected → Web search NEEDED")
            return True
        else:
            print(f"❌ [Layer 2] No position keywords")
        
        # Layer 3: Gemini classification for uncertain cases
        print(f"🔄 [Layer 3] Asking Gemini if this needs web search...")
        layer3_result = await self._classify_needs_search(query)
        
        if layer3_result:
            print(f"✅ [Layer 3] Gemini says YES → Web search NEEDED\n")
        else:
            print(f"❌ [Layer 3] Gemini says NO → Direct Gemini only\n")
        
        return layer3_result