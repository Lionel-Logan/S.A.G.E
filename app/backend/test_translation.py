import requests

BASE_URL = "http://127.0.0.1:8000"

def test_text_translation():
    """Test 1: Ask it to translate text (Should use LibreTranslate)"""
    print("\n--- TEST 1: TEXT TRANSLATION ---")
    payload = {
        "query": "translate Hello, how are you?",
        "user_id": "test_user"
    }
    try:
        response = requests.post(f"{BASE_URL}/assistant/ask", json=payload)
        data = response.json()
        # DEBUG: Print whatever the server sent back
        print(f"👉 Server Status: {response.status_code}")
        print(f"👉 Raw Response: {data}")

        if response.status_code == 200:
            print(f"✅ Response: {data['response_text']}")
        else:
            print("❌ Server returned an error!")
        # print(f"👉 Input: {payload['query']}")
        # print(f"✅ Response: {data['response_text']}")
    except Exception as e:
        print(f"❌ Error: {e}")

def test_image_translation():
    """Test 2: Ask it to read an image (Should use Gemini -> Libre)"""
    print("\n--- TEST 2: IMAGE TRANSLATION ---")
    
    # A tiny Base64 image of the letter "A" (Just to trigger the vision pipeline)
    # In a real test, this would be a photo of a menu.
    dummy_image = "iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg=="
    
    payload = {
        "query": "translate this image",
        "image_data": dummy_image,
        "user_id": "test_user"
    }
    try:
        response = requests.post(f"{BASE_URL}/assistant/ask", json=payload)
        data = response.json()
        print(f"👉 Input: [IMAGE DATA]")
        print(f"✅ Response: {data['response_text']}")
        print("(Note: Since the image is just pixels, Gemini might say 'No text found', but check your SERVER LOGS to see it tried!)")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    test_text_translation()
    test_image_translation()