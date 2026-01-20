import google.generativeai as genai
import os
from dotenv import load_dotenv

# 1. Load your API key from the .env file
load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")

if not api_key:
    print("❌ Error: I couldn't find your API Key.")
else:
    print(f"✅ Key found: {api_key[:5]}...")

    # 2. Connect to Google
    genai.configure(api_key=api_key)

    print("\n🔍 Asking Google for available models...")
    try:
        # 3. List everything available to you
        for m in genai.list_models():
            # We only care about models that can generate text (generateContent)
            if 'generateContent' in m.supported_generation_methods:
                print(f"   - {m.name}")
    except Exception as e:
        print(f"❌ Error talking to Google: {e}")