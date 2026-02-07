"""
Face Recognition Module Test Suite
Tests enrollment, recognition, and integration with S.A.G.E backend
"""
import requests
import base64
import json
from pathlib import Path

# Configuration
BACKEND_URL = "http://localhost:8000"
FACE_SERVER_URL = "http://localhost:8002"

def encode_image_to_base64(image_path):
    """Convert image file to base64 string"""
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')

def test_face_server_health():
    """Test if face recognition server is running"""
    print("\n" + "="*60)
    print("TEST 1: Face Recognition Server Health Check")
    print("="*60)
    
    try:
        response = requests.get(f"{FACE_SERVER_URL}/health", timeout=5)
        if response.status_code == 200:
            print("✅ Face Recognition Server is ONLINE")
            print(f"   Response: {response.json()}")
            return True
        else:
            print(f"❌ Server returned status code: {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print("❌ FAILED: Face Recognition Server is OFFLINE (port 8002)")
        print("   Ask teammate Nikhil to start the server:")
        print("   cd ml/facial-recognition/src")
        print("   python face_recognition_service.py")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_backend_health():
    """Test if S.A.G.E backend is running"""
    print("\n" + "="*60)
    print("TEST 2: S.A.G.E Backend Health Check")
    print("="*60)
    
    try:
        response = requests.get(f"{BACKEND_URL}/health", timeout=5)
        if response.status_code == 200:
            print("✅ S.A.G.E Backend is ONLINE")
            print(f"   Response: {response.json()}")
            return True
        else:
            print(f"❌ Backend returned status code: {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print("❌ FAILED: S.A.G.E Backend is OFFLINE (port 8000)")
        print("   Start backend with: uvicorn app.main:app --reload")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_enrollment_direct(image_path, name, description=""):
    """Test enrollment directly with face recognition server"""
    print("\n" + "="*60)
    print(f"TEST 3: Direct Enrollment - {name}")
    print("="*60)
    
    try:
        # Encode image
        image_base64 = encode_image_to_base64(image_path)
        print(f"📸 Image loaded: {image_path}")
        print(f"   Image size: {len(image_base64)} bytes (base64)")
        
        # Send enrollment request
        payload = {
            "name": name,
            "description": description,
            "image_base64": image_base64,
            "threshold": 0.5
        }
        
        response = requests.post(
            f"{FACE_SERVER_URL}/enroll",
            json=payload,
            timeout=10
        )
        
        result = response.json()
        
        if response.status_code == 200 and result.get("success"):
            print(f"✅ Enrollment SUCCESS")
            print(f"   Name: {name}")
            print(f"   Description: {description}")
            print(f"   Face ID: {result.get('face_id', 'N/A')}")
            print(f"   Message: {result.get('message')}")
            return True
        else:
            print(f"❌ Enrollment FAILED")
            print(f"   Status: {response.status_code}")
            print(f"   Response: {json.dumps(result, indent=2)}")
            return False
            
    except FileNotFoundError:
        print(f"❌ Image file not found: {image_path}")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_recognition_direct(image_path):
    """Test recognition directly with face recognition server"""
    print("\n" + "="*60)
    print(f"TEST 4: Direct Recognition")
    print("="*60)
    
    try:
        # Encode image
        image_base64 = encode_image_to_base64(image_path)
        print(f"📸 Image loaded: {image_path}")
        
        # Send recognition request
        payload = {
            "image_base64": image_base64,
            "threshold": 0.2
        }
        
        response = requests.post(
            f"{FACE_SERVER_URL}/recognize",
            json=payload,
            timeout=10
        )
        
        result = response.json()
        
        if response.status_code == 200 and result.get("success"):
            print(f"✅ Recognition SUCCESS")
            print(f"   Faces detected: {result.get('faces_detected', 0)}")
            
            faces = result.get('faces', [])
            if faces:
                print(f"\n   Recognized faces:")
                for i, face in enumerate(faces, 1):
                    name = face.get('name', 'Unknown')
                    desc = face.get('description', '')
                    conf = face.get('confidence', 0.0)
                    print(f"   {i}. {name} ({desc}) - Confidence: {conf:.2f}")
            else:
                print(f"   No faces recognized")
            
            return True
        else:
            print(f"❌ Recognition FAILED")
            print(f"   Status: {response.status_code}")
            print(f"   Response: {json.dumps(result, indent=2)}")
            return False
            
    except FileNotFoundError:
        print(f"❌ Image file not found: {image_path}")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_enrollment_flow_via_backend(image_path, name, description="Person"):
    """
    Test enrollment workflow through S.A.G.E backend assistant endpoint
    This tests the INTERACTIVE enrollment flow:
    1. Ask "who is this" with unknown face
    2. Backend detects unrecognized face and asks if you want to enroll
    3. Respond "yes"
    4. Backend asks for name
    5. Provide name (and optional description)
    """
    print("\n" + "="*60)
    print(f"TEST 5: Backend Enrollment Workflow - {name}")
    print("="*60)
    
    try:
        # Encode image
        image_base64 = encode_image_to_base64(image_path)
        print(f"📸 Image loaded: {image_path}")
        
        # STEP 1: Ask "who is this" with unknown face
        print(f"\n📝 Step 1: Ask 'who is this' (should be unrecognized)")
        payload = {
            "query": "who is this",
            "image_data": image_base64,
            "user_id": "test_user_123"
        }
        
        response = requests.post(
            f"{BACKEND_URL}/api/v1/assistant/ask",
            json=payload,
            timeout=15
        )
        
        result = response.json()
        print(f"   Response: {result.get('response_text')}")
        
        if "don't recognize" in result.get('response_text', '').lower() or "would you like" in result.get('response_text', '').lower():
            print(f"✅ Step 1 passed: Face not recognized, enrollment prompt triggered")
        else:
            print(f"⚠️  Step 1: Face might already be enrolled or different response")
            return False
        
        # STEP 2: Respond "yes" to enrollment prompt
        print(f"\n📝 Step 2: Respond 'yes' to enrollment")
        payload = {
            "query": "yes",
            "user_id": "test_user_123"
        }
        
        response = requests.post(
            f"{BACKEND_URL}/api/v1/assistant/ask",
            json=payload,
            timeout=15
        )
        
        result = response.json()
        print(f"   Response: {result.get('response_text')}")
        
        if "name" in result.get('response_text', '').lower():
            print(f"✅ Step 2 passed: Backend asking for name")
        else:
            print(f"❌ Step 2 failed: Expected name prompt")
            return False
        
        # STEP 3: Provide name and description
        print(f"\n📝 Step 3: Provide name and description")
        if description and description != "Person":
            name_query = f"{name} as {description}"
        else:
            name_query = name
        
        print(f"   Sending: '{name_query}'")
        payload = {
            "query": name_query,
            "user_id": "test_user_123"
        }
        
        response = requests.post(
            f"{BACKEND_URL}/api/v1/assistant/ask",
            json=payload,
            timeout=15
        )
        
        result = response.json()
        print(f"   Response: {result.get('response_text')}")
        
        if "enrolled successfully" in result.get('response_text', '').lower():
            print(f"✅ Step 3 passed: Enrollment complete!")
            print(f"\n✅ FULL ENROLLMENT WORKFLOW SUCCESS")
            return True
        else:
            print(f"❌ Step 3 failed: Enrollment not confirmed")
            return False
            
    except FileNotFoundError:
        print(f"❌ Image file not found: {image_path}")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_recognition_via_backend(image_path):
    """Test recognition through S.A.G.E backend assistant endpoint"""
    print("\n" + "="*60)
    print(f"TEST 6: Backend Recognition via Assistant")
    print("="*60)
    
    try:
        # Encode image
        image_base64 = encode_image_to_base64(image_path)
        print(f"📸 Image loaded: {image_path}")
        
        # Create recognition query
        query = "who is this"
        print(f"📝 Query: '{query}'")
        
        # Send to assistant endpoint
        payload = {
            "query": query,
            "image_data": image_base64,
            "user_id": "test_user_123"
        }
        
        response = requests.post(
            f"{BACKEND_URL}/api/v1/assistant/ask",
            json=payload,
            timeout=15
        )
        
        result = response.json()
        
        if response.status_code == 200:
            print(f"✅ Backend recognition SUCCESS")
            print(f"   Response: {result.get('response_text')}")
            print(f"   Action Type: {result.get('action_type')}")
            return True
        else:
            print(f"❌ Backend recognition FAILED")
            print(f"   Status: {response.status_code}")
            print(f"   Response: {json.dumps(result, indent=2)}")
            return False
            
    except FileNotFoundError:
        print(f"❌ Image file not found: {image_path}")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_faces_endpoint_directly(image_path, token=None):
    """
    Test the /faces/recognize endpoint directly (NOT through assistant)
    This requires authentication token
    """
    print("\n" + "="*60)
    print(f"TEST 7: Direct /faces/recognize Endpoint (Requires Auth)")
    print("="*60)
    
    if not token:
        print("⚠️  No authentication token provided")
        print("   This test requires you to login first")
        print("   Skipping...")
        return False
    
    try:
        # Encode image
        image_base64 = encode_image_to_base64(image_path)
        print(f"📸 Image loaded: {image_path}")
        
        # Send to /faces/recognize endpoint with auth
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "image_base64": image_base64
        }
        
        response = requests.post(
            f"{BACKEND_URL}/api/v1/faces/recognize",
            json=payload,
            headers=headers,
            timeout=15
        )
        
        result = response.json()
        
        if response.status_code == 200:
            print(f"✅ /faces/recognize SUCCESS")
            print(f"   Faces detected: {len(result.get('faces', []))}")
            for face in result.get('faces', []):
                print(f"   - {face.get('name')} (confidence: {face.get('confidence', 0):.2f})")
            return True
        else:
            print(f"❌ /faces/recognize FAILED")
            print(f"   Status: {response.status_code}")
            print(f"   Response: {json.dumps(result, indent=2)}")
            return False
            
    except FileNotFoundError:
        print(f"❌ Image file not found: {image_path}")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def run_full_test_suite():
    """Run complete test suite"""
    print("\n" + "="*60)
    print("S.A.G.E FACE RECOGNITION TEST SUITE")
    print("="*60)
    print("\nPREREQUISITES:")
    print("1. Face Recognition Server running on port 8002")
    print("2. S.A.G.E Backend running on port 8000")
    print("3. Test images available in data/ folder")
    print("\n" + "="*60)
    
    # Test 1 & 2: Health checks
    face_server_ok = test_face_server_health()
    backend_ok = test_backend_health()
    
    if not face_server_ok:
        print("\n❌ Face Recognition Server is not running!")
        print("\nTO START THE SERVER:")
        print("1. Ask teammate Nikhil to run:")
        print("   cd D:\\fourthyr\\try2\\S.A.G.E\\ml\\facial-recognition\\src")
        print("   python face_recognition_service.py")
        print("\n2. Or check if server is running on different port")
        return
    
    if not backend_ok:
        print("\n❌ S.A.G.E Backend is not running!")
        print("\nTO START BACKEND:")
        print("   cd D:\\fourthyr\\try2\\S.A.G.E\\app\\backend")
        print("   uvicorn app.main:app --reload")
        return
    
    # Prompt for test images
    print("\n" + "="*60)
    print("TEST IMAGE SETUP")
    print("="*60)
    print("\nPlease provide test images:")
    print("1. Place face images in: ml/facial-recognition/data/test/")
    print("2. Or provide full path to image files")
    
    # Example test with placeholder paths
    print("\n" + "="*60)
    print("RUNNING TESTS WITH SAMPLE DATA")
    print("="*60)
    
    # You can modify these paths
    test_image_1 = input("\nEnter path to test image 1 (or press Enter to skip): ").strip()
    
    if test_image_1 and Path(test_image_1).exists():
        name = input("Enter person's name for enrollment: ").strip()
        description = input("Enter description (optional): ").strip()
        
        print("\n" + "="*60)
        print("CHOOSE TEST TYPE:")
        print("="*60)
        print("1. Direct to Face Recognition Server (Tests 3-4)")
        print("2. Via Backend Assistant Endpoint (Tests 5-6)")
        print("3. All tests")
        
        choice = input("\nEnter choice (1-3): ").strip()
        
        if choice == "1" or choice == "3":
            # Test 3: Direct enrollment
            test_enrollment_direct(test_image_1, name, description)
            
            # Test 4: Direct recognition
            test_recognition_direct(test_image_1)
        
        if choice == "2" or choice == "3":
            # Test 5: Backend enrollment workflow (interactive)
            print("\n⚠️  Note: This will test the INTERACTIVE enrollment flow")
            print("   The face in the image must NOT be enrolled yet!")
            confirm = input("   Continue? (y/n): ").strip().lower()
            
            if confirm == "y":
                test_enrollment_flow_via_backend(test_image_1, name, description)
            
            # Test 6: Backend recognition (should recognize the face now)
            print("\n⚠️  Note: Testing recognition - face should be enrolled by now")
            input("   Press Enter to test recognition...")
            test_recognition_via_backend(test_image_1)
        
    else:
        print("\n⚠️  No test image provided, skipping face tests")
        print("   Tests 1-2 (health checks) passed successfully!")
    
    print("\n" + "="*60)
    print("✅ TEST SUITE COMPLETE")
    print("="*60)

if __name__ == "__main__":
    run_full_test_suite()