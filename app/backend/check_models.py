from google import genai
import os
from dotenv import load_dotenv

# 1. Load your API key from the .env file
load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")

if not api_key:
    print("❌ Error: I couldn't find your API Key.")
else:
    print(f"✅ Key found: {api_key[:5]}...")

    # 2. Create Gemini client
    client = genai.Client(api_key=api_key)

    print("\n🔍 Asking Google for available models...")
    try:
        # 3. List available models
        models = client.models.list()
        for model in models:
            print(f"   - {model.name}")
    except Exception as e:
        print(f"❌ Error talking to Google: {e}")