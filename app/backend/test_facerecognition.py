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
            "threshold": 0.7
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

def test_enrollment_via_backend(image_path, name, description=""):
    """Test enrollment through S.A.G.E backend assistant endpoint"""
    print("\n" + "="*60)
    print(f"TEST 5: Backend Enrollment - {name}")
    print("="*60)
    
    try:
        # Encode image
        image_base64 = encode_image_to_base64(image_path)
        print(f"📸 Image loaded: {image_path}")
        
        # Create enrollment query
        if description:
            query = f"enroll {name} as {description}"
        else:
            query = f"enroll {name}"
        
        print(f"📝 Query: '{query}'")
        
        # Send to assistant endpoint
        payload = {
            "query": query,
            "image_data": image_base64
        }
        
        response = requests.post(
            f"{BACKEND_URL}/api/v1/assistant/ask",
            json=payload,
            timeout=15
        )
        
        result = response.json()
        
        if response.status_code == 200:
            print(f"✅ Backend enrollment SUCCESS")
            print(f"   Response: {result.get('response_text')}")
            return True
        else:
            print(f"❌ Backend enrollment FAILED")
            print(f"   Status: {response.status_code}")
            print(f"   Response: {json.dumps(result, indent=2)}")
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
    print(f"TEST 6: Backend Recognition")
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
            "image_data": image_base64
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
        
        # Test 3: Direct enrollment
        #test_enrollment_direct(test_image_1, name, description)
        
        # Test 4: Direct recognition
        #test_recognition_direct(test_image_1)
        
        # Test 5: Backend enrollment
        test_enrollment_via_backend(test_image_1, name + "_backend", description)
        
        # Test 6: Backend recognition
        test_recognition_via_backend(test_image_1)
        
    else:
        print("\n⚠️  No test image provided, skipping face tests")
        print("   Tests 1-2 (health checks) passed successfully!")
    
    print("\n" + "="*60)
    print("✅ TEST SUITE COMPLETE")
    print("="*60)

if __name__ == "__main__":
    run_full_test_suite()