import spacy
from typing import Tuple
import google.generativeai as genai
from app.config import settings

# Load the lightweight English model
try:
    nlp = spacy.load("en_core_web_sm")
except:
    print("Spacy model not found. Run: python -m spacy download en_core_web_sm")
    nlp = None

# Configure Gemini for fallback classification
genai.configure(api_key=settings.GEMINI_API_KEY, transport="rest")

class IntentRouter:
    def __init__(self):
        # 1. STRICT PHRASES (Multi-word triggers that are 100% certain)
        self.strict_rules = {
            "NAVIGATION": [
                "navigate to", "take me to", "directions to", "go to", "route to", 
                "how do i get to", "show me the way to", "guide me to", 
                "find a route to", "drive to", "walk to", "how far is"
            ],
            "TRANSLATION": [
                "translate this", "read this", "what does this say", "scan text",
                "what's this saying", "what does that say", "read that",
                "translate that", "what language is this", "read the sign",
                "what's written", "decipher this"
            ],
            "FACE_RECOGNITION": [
                "who is this", "who is that", "recognize face", "identify person",
                "is that", "do you know who", "who's this person", "who am i looking at",
                "identify this person", "is this", "recognize this person",
                "tell me who this is", "do you recognize this person"
            ],
            # FACE_ENROLLMENT disabled - All enrollment happens through failed recognition flow
            # "FACE_ENROLLMENT": [
            #     "enroll face", "register face", "add face", "save face", 
            #     "remember this person", "add this person", "register this person",
            #     "enroll this face", "save this person", "remember this face",
            #     "add new face", "register new person", "enroll new face",
            #     "save new person", "add new person"
            # ],
            "OBJECT_DETECTION": [
                "what is this", "what object", "detect object", "scan item",
                "what am i looking at", "what's in front of me", "what's that object",
                "identify this object", "what do you see", "describe what you see",
                "scan this", "what's this thing", "what objects do you see",
                "tell me what you see", "what are you seeing", "look around",
                "start object detection", "begin object detection", "start scanning",
                "stop object detection", "end object detection", "stop scanning"
            ]
        }

        # 2. KEYWORDS (Single words for fallback matching)
        self.keywords = {
            "TRANSLATION": ["translate", "translation", "decipher", "language", "read", "written"],
            "NAVIGATION": ["navigate", "navigation", "route", "direction", "map", "gps", "guide", "way"],
            "FACE_RECOGNITION": ["face", "recognize", "identity", "person", "who"],
            # "FACE_ENROLLMENT": ["enroll", "register", "remember", "save", "add"],  # Disabled
            "OBJECT_DETECTION": ["detect", "scan", "object", "item", "thing", "see", "describe"]
        }
        
        # Gemini model for fallback classification
        self.gemini_model = genai.GenerativeModel('gemini-2.5-flash')

    def _classify_with_rules(self, text: str) -> Tuple[str, bool]:
        """
        Rule-based classification with uncertainty detection.
        
        Returns:
            Tuple of (intent, is_uncertain)
            - intent: The predicted intent
            - is_uncertain: True if confidence is low
        """
        clean_text = text.lower().strip()

        # --- STEP 1: Check Strict Phrases (High Confidence) ---
        for intent, phrases in self.strict_rules.items():
            for phrase in phrases:
                if phrase in clean_text:
                    return intent, False  # High confidence match

        # --- STEP 2: Keyword Matching (Lower Confidence) ---
        if nlp:
            doc = nlp(clean_text)
            tokens = [token.lemma_ for token in doc]
        else:
            tokens = clean_text.split()

        # Count keyword matches for each intent
        match_counts = {}
        for intent_name, keywords in self.keywords.items():
            count = sum(1 for w in tokens if w in keywords)
            if count > 0:
                match_counts[intent_name] = count

        # If we have matches, pick the highest
        if match_counts:
            best_intent = max(match_counts, key=match_counts.get)
            
            # Uncertain if multiple intents have similar scores
            max_count = match_counts[best_intent]
            competing_intents = [i for i, c in match_counts.items() if c == max_count]
            
            if len(competing_intents) > 1:
                return "UNCERTAIN", True  # Multiple matches - ambiguous
            else:
                return best_intent, False  # Clear winner

        # --- STEP 3: No matches - might need Gemini ---
        return "ASSISTANT", False  # Default to assistant (not uncertain, just chat)

    async def _classify_with_gemini(self, text: str) -> str:
        """
        AI-powered classification using Gemini for ambiguous cases.
        
        Returns:
            Intent classification
        """
        prompt = f"""Classify the following user query into EXACTLY ONE of these categories:
- NAVIGATION (for directions, routes, navigation requests)
- TRANSLATION (for reading text, translating, OCR requests)
- FACE_RECOGNITION (for identifying people, faces)
- OBJECT_DETECTION (for identifying objects, things in view)
- ASSISTANT (for general chat, questions, other requests)

User query: "{text}"

Response format: Return ONLY the category name, nothing else."""

        try:
            response = self.gemini_model.generate_content(prompt)
            intent = response.text.strip().upper()
            
            # Validate response
            valid_intents = ["NAVIGATION", "TRANSLATION", "FACE_RECOGNITION", "OBJECT_DETECTION", "ASSISTANT"]
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
        HYBRID APPROACH: Fast rule-based classification with Gemini fallback.
        
        Flow:
        1. Try rule-based classification (~10ms)
        2. If uncertain, use Gemini (~800ms)
        3. Return final intent
        """
        # Fast path: Rule-based classification
        intent, is_uncertain = self._classify_with_rules(text)
        
        # Slow path: Only for uncertain cases
        if is_uncertain:
            print(f"🤔 Uncertain classification for: '{text}', asking Gemini...")
            intent = await self._classify_with_gemini(text)
        
        return intent