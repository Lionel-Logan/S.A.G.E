import spacy

# Load the lightweight English model
nlp = spacy.load("en_core_web_sm")

class IntentRouter:
    def __init__(self):
        self.commands = {
            "SCAN": ["scan", "detect", "look", "see", "find", "identify", "what is"],
            "READ": ["read", "translate", "decipher", "text"],
            "NAVIGATE": ["go", "navigate", "direction", "where"],
        }

    def predict_intent(self, text: str) -> str:
        """
        Analyzes text and returns one of: 'SCAN', 'READ', 'NAVIGATE', or 'CHAT'
        """
        doc = nlp(text.lower())
        
        # 1. Extract verbs and nouns (Lemmatization handles "scanning" -> "scan")
        # We look at the 'root' of the sentence to find the main action
        verbs = [token.lemma_ for token in doc if token.pos_ == "VERB"]
        nouns = [token.lemma_ for token in doc if token.pos_ == "NOUN"]
        
        # 2. Check for matches in our command dictionary
        for intent, keywords in self.commands.items():
            # Check if any verb or noun matches our keywords
            if any(word in keywords for word in verbs + nouns):
                return intent
                
        # 3. Default fallback: If no command found, it's a chat question
        return "CHAT"