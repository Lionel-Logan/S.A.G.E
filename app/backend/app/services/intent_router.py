import spacy

# Load the lightweight English model
try:
    nlp = spacy.load("en_core_web_sm")
except:
    print("Spacy model not found. Run: python -m spacy download en_core_web_sm")
    nlp = None

class IntentRouter:
    def __init__(self):
        # 1. STRICT PHRASES (Multi-word triggers that are 100% certain)
        self.strict_rules = {
            "NAVIGATION": ["navigate to", "take me to", "directions to", "go to", "route to", "how do i get to"],
            "TRANSLATION": ["translate this", "read this", "what does this say", "scan text"],
            "FACE_RECOGNITION": ["who is this", "who is that", "recognize face", "identify person"],
            "OBJECT_DETECTION": ["what is this", "what object", "detect object", "scan item"]
        }

        # 2. KEYWORDS (Single words for fallback matching)
        self.keywords = {
            "TRANSLATION": ["translate", "translation", "decipher", "language"],
            "NAVIGATION": ["navigate", "navigation", "route", "direction", "map", "gps"],
            "FACE_RECOGNITION": ["face", "recognize", "identity", "person"],
            "OBJECT_DETECTION": ["detect", "scan", "object", "item"]
        }

    def predict_intent(self, text: str) -> str:
        """
        Robust prediction: Checks strict phrases first, then keywords.
        """
        clean_text = text.lower().strip()

        # --- STEP 1: Check Strict Phrases (Fast & Accurate) ---
        for intent, phrases in self.strict_rules.items():
            for phrase in phrases:
                if phrase in clean_text:
                    return intent

        # --- STEP 2: Keyword Matching (Fallback) ---
        # If strict rules fail, look for individual keywords
        
        # We process with Spacy if available to handle lemmas (running -> run)
        # But we DO NOT filter by POS tags anymore (too risky)
        if nlp:
            doc = nlp(clean_text)
            tokens = [token.lemma_ for token in doc]
        else:
            # Fallback if Spacy dies
            tokens = clean_text.split()

        # Check for keyword matches in priority order
        if any(w in self.keywords["TRANSLATION"] for w in tokens): return "TRANSLATION"
        if any(w in self.keywords["NAVIGATION"] for w in tokens): return "NAVIGATION"
        if any(w in self.keywords["FACE_RECOGNITION"] for w in tokens): return "FACE_RECOGNITION"
        if any(w in self.keywords["OBJECT_DETECTION"] for w in tokens): return "OBJECT_DETECTION"

        # --- STEP 3: Default to Assistant ---
        return "ASSISTANT"