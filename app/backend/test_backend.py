import requests
import base64

# URL of your local server
# MAKE SURE THIS MATCHES YOUR URL FROM THE BROWSER (e.g. /api/v1 prefix)
BASE_URL = "http://127.0.0.1:8000" 

DUMMY_IMAGE = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII="

def test_root():
    """Checks if the server is ALIVE"""
    print("\n[1] Testing Root Endpoint...")
    try:
        response = requests.get(f"{BASE_URL}/")
        if response.status_code == 200:
            print("✅ [PASS] Server is online!")
        else:
            print(f"❌ [FAIL] Server returned {response.status_code}")
    except Exception as e:
        print(f"❌ [FAIL] Could not connect: {e}")

def test_chat():
    """Checks if Gemini/Chat intent is working"""
    print("\n[2] Testing Chat Intent...")
    payload = {
        "query": "Hello, whats the time and weather in kochi?",
        "user_id": "test_user"
    }
    try:
        # Note: Added /api/v1 prefix based on your previous error logs
        response = requests.post(f"{BASE_URL}/api/v1/assistant/ask", json=payload)
        data = response.json()
        if response.status_code == 200 and data['action_type'] == 'chat':
            print(f"✅ [PASS] Chat Intent works!")
            print(f"   Response: {data['response_text'][:100]}...")
        else:
            print(f"❌ [FAIL] Chat Intent failed: {data}")
    except Exception as e:
        print(f"❌ [FAIL] Chat Error: {e}")

def test_vision():
    """Checks if Vision Intent + Image Decoding is working"""
    print("\n[3] Testing Vision Intent...")
    payload = {
        "query": "scan this object",
        "user_id": "test_user",
        # KEY FIX: The model in assistant.py expects 'image_data', not 'image_base64'
        "image_data": DUMMY_IMAGE 
    }
    try:
        response = requests.post(f"{BASE_URL}/api/v1/assistant/ask", json=payload)
        data = response.json()
        
        if response.status_code == 200 and data['action_type'] == 'vision':
            print(f"✅ [PASS] Vision Intent works!")
            print(f"   Response: {data['response_text']}")
        else:
            print(f"❌ [FAIL] Vision Intent failed: {data}")
    except Exception as e:
        print(f"❌ [FAIL] Vision Error: {e}")

def test_navigation():
    """Checks if Navigation (OSM/Nominatim) returns Step-by-Step data"""
    print("\n[4] Testing Navigation Intent...")
    
    # Mock User Location: Edappally, Kochi
    payload = {
        "query": "navigate to Thrikkakara temple",
        "user_id": "test_user",
        "lat": 10.0273, 
        "lon": 76.3295
    }
    
    try:
        response = requests.post(f"{BASE_URL}/api/v1/assistant/ask", json=payload)
        data = response.json()
        
        if response.status_code == 200 and data['action_type'] == 'navigation':
            print(f"✅ [PASS] Navigation works!")
            print(f"   🗣️ Voice Summary: {data['response_text']}")
            
            # CHECK FOR THE NEW DATA FIELD
            if data.get('navigation_data'):
                steps = data['navigation_data']['steps']
                print(f"   🗺️  Detailed Steps Received: {len(steps)} steps found.")
                # Print the first 3 steps as proof
                for i, step in enumerate(steps[:3]):
                    print(f"      Step {i+1}: {step['instruction']} ({step['distance_meters']}m)")
            else:
                print("   ⚠️ [WARN] 'navigation_data' is missing/null!")
                
        else:
            print(f"❌ [FAIL] Navigation failed. Status: {response.status_code}")
            print(f"   Error: {data}")
            
    except Exception as e:
        print(f"❌ [FAIL] Navigation Error: {e}")

if __name__ == "__main__":
    print("--- STARTING S.A.G.E. BACKEND DIAGNOSTICS ---")
    # test_root()
    # test_chat()
    test_vision()
    test_navigation()
    print("---------------------------------------------")