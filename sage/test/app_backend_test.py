"""
SAGE App Backend - Test Client
================================
Tests all AI endpoints with dummy data
"""

import requests
import base64
import cv2
import numpy as np
from pathlib import Path

BACKEND_URL = "http://localhost:8002"

# ============================================================================
# UTILITIES
# ============================================================================

def print_header(text):
    print("\n" + "="*60)
    print(f"  {text}")
    print("="*60)

def print_success(text):
    print(f"✅ {text}")

def print_info(text):
    print(f"ℹ️  {text}")

def print_error(text):
    print(f"❌ {text}")

def get_dummy_image_base64():
    """Generate a dummy image for testing"""
    # Create a simple test image
    img = np.zeros((480, 640, 3), dtype=np.uint8)
    cv2.putText(img, "SAGE Test Image", (200, 240), 
                cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
    
    # Encode to base64
    _, buffer = cv2.imencode('.jpg', img)
    return base64.b64encode(buffer).decode('utf-8')

# ============================================================================
# TEST FUNCTIONS
# ============================================================================

def test_health():
    """Test health check endpoint"""
    print_header("Test 1: Health Check")
    try:
        response = requests.get(f"{BACKEND_URL}/health")
        response.raise_for_status()
        data = response.json()
        
        print_info(f"Status: {data['status']}")
        print_info("Services:")
        for service, status in data['services'].items():
            print(f"   • {service}: {status}")
        print_success("Health check passed")
        return True
    except Exception as e:
        print_error(f"Failed: {e}")
        return False

def test_voice_assistant():
    """Test voice assistant queries"""
    print_header("Test 2: Voice Assistant")
    
    queries = [
        "What's the weather today?",
        "What time is it?",
        "Hello SAGE",
        "Who is this person?",
        "What do you see?"
    ]
    
    for query in queries:
        try:
            print_info(f"Query: '{query}'")
            response = requests.post(
                f"{BACKEND_URL}/assistant/query",
                json={"query": query}
            )
            response.raise_for_status()
            data = response.json()
            
            print(f"   Response: {data['response_text']}")
            print(f"   Time: {data['processing_time_ms']}ms")
            print()
        except Exception as e:
            print_error(f"Failed: {e}")
            return False
    
    print_success("Voice assistant test passed")
    return True

def test_translation():
    """Test translation endpoint"""
    print_header("Test 3: Translation")
    
    try:
        image_base64 = get_dummy_image_base64()
        
        print_info("Requesting translation (auto → English)")
        response = requests.post(
            f"{BACKEND_URL}/translation/translate",
            json={
                "image_base64": image_base64,
                "source_language": "auto",
                "target_language": "en"
            }
        )
        response.raise_for_status()
        data = response.json()
        
        print(f"   Original: {data['original_text']}")
        print(f"   Translated: {data['translated_text']}")
        print(f"   Language: {data['source_language']} → {data['target_language']}")
        print(f"   Time: {data['processing_time_ms']}ms")
        
        print_success("Translation test passed")
        return True
    except Exception as e:
        print_error(f"Failed: {e}")
        return False

def test_facial_recognition():
    """Test facial recognition endpoint"""
    print_header("Test 4: Facial Recognition")
    
    try:
        image_base64 = get_dummy_image_base64()
        
        print_info("Requesting face recognition")
        response = requests.post(
            f"{BACKEND_URL}/recognition/faces",
            json={
                "image_base64": image_base64,
                "threshold": 0.6
            }
        )
        response.raise_for_status()
        data = response.json()
        
        print(f"   Faces detected: {data['faces_detected']}")
        
        if data['faces_detected'] > 0:
            for face in data['faces']:
                print(f"   • {face['person_name']} (confidence: {face['confidence']})")
                print(f"     Box: {face['bounding_box']}")
        else:
            print("   No faces detected")
        
        print(f"   Time: {data['processing_time_ms']}ms")
        
        print_success("Facial recognition test passed")
        return True
    except Exception as e:
        print_error(f"Failed: {e}")
        return False

def test_object_detection():
    """Test object detection endpoint"""
    print_header("Test 5: Object Detection")
    
    try:
        image_base64 = get_dummy_image_base64()
        
        print_info("Requesting object detection")
        response = requests.post(
            f"{BACKEND_URL}/detection/objects",
            json={
                "image_base64": image_base64,
                "confidence_threshold": 0.5
            }
        )
        response.raise_for_status()
        data = response.json()
        
        print(f"   Objects detected: {data['objects_detected']}")
        
        for obj in data['objects']:
            print(f"   • {obj['label']} (confidence: {obj['confidence']})")
            print(f"     Box: {obj['bounding_box']}")
        
        print(f"   Time: {data['processing_time_ms']}ms")
        
        print_success("Object detection test passed")
        return True
    except Exception as e:
        print_error(f"Failed: {e}")
        return False

def test_ocr():
    """Test OCR endpoint"""
    print_header("Test 6: OCR Extraction")
    
    try:
        image_base64 = get_dummy_image_base64()
        
        print_info("Requesting OCR extraction")
        response = requests.post(
            f"{BACKEND_URL}/ocr/extract",
            json={"image_base64": image_base64}
        )
        response.raise_for_status()
        data = response.json()
        
        print(f"   Extracted text: '{data['text']}'")
        print(f"   Language: {data['language']}")
        print(f"   Confidence: {data['confidence']}")
        print(f"   Time: {data['processing_time_ms']}ms")
        
        print_success("OCR test passed")
        return True
    except Exception as e:
        print_error(f"Failed: {e}")
        return False

def test_workflow_translation():
    """Test complete translation workflow"""
    print_header("Test 7: Translation Workflow (OCR + Translate)")
    
    try:
        image_base64 = get_dummy_image_base64()
        
        print_info("Running complete translation workflow")
        response = requests.post(
            f"{BACKEND_URL}/workflow/translate-image",
            json={
                "image_base64": image_base64,
                "target_language": "en"
            }
        )
        response.raise_for_status()
        data = response.json()
        
        print(f"   Workflow: {data['workflow']}")
        print(f"   Steps: {', '.join(data['steps_completed'])}")
        print(f"   OCR Result: '{data['ocr_result']['text']}'")
        print(f"   Translation: '{data['translation_result']['translated_text']}'")
        print(f"   Total Time: {data['total_processing_time_ms']}ms")
        
        print_success("Translation workflow test passed")
        return True
    except Exception as e:
        print_error(f"Failed: {e}")
        return False

def test_workflow_identify_greet():
    """Test identify and greet workflow"""
    print_header("Test 8: Identify & Greet Workflow")
    
    try:
        image_base64 = get_dummy_image_base64()
        
        print_info("Running identify and greet workflow")
        response = requests.post(
            f"{BACKEND_URL}/workflow/identify-and-greet",
            params={"image_base64": image_base64}
        )
        response.raise_for_status()
        data = response.json()
        
        print(f"   Workflow: {data['workflow']}")
        print(f"   Faces detected: {data['faces_detected']}")
        print(f"   Greeting: '{data['greeting_text']}'")
        print(f"   Total Time: {data['total_processing_time_ms']}ms")
        
        print_success("Identify & greet workflow test passed")
        return True
    except Exception as e:
        print_error(f"Failed: {e}")
        return False

def run_all_tests():
    """Run all tests"""
    print_header("Running Complete Backend Test Suite")
    
    tests = [
        ("Health Check", test_health),
        ("Voice Assistant", test_voice_assistant),
        ("Translation", test_translation),
        ("Facial Recognition", test_facial_recognition),
        ("Object Detection", test_object_detection),
        ("OCR", test_ocr),
        ("Translation Workflow", test_workflow_translation),
        ("Identify & Greet Workflow", test_workflow_identify_greet),
    ]
    
    passed = 0
    failed = 0
    
    for name, test_func in tests:
        if test_func():
            passed += 1
        else:
            failed += 1
    
    print_header("Test Summary")
    print(f"✅ Passed: {passed}")
    print(f"❌ Failed: {failed}")
    
    if failed == 0:
        print_success("🎉 ALL TESTS PASSED!")
    else:
        print_error(f"Some tests failed. Check logs above.")

# ============================================================================
# INTERACTIVE MENU
# ============================================================================

def show_menu():
    print("\n" + "="*60)
    print("  SAGE App Backend - Test Menu")
    print("="*60)
    print("1. Health Check")
    print("2. Voice Assistant")
    print("3. Translation")
    print("4. Facial Recognition")
    print("5. Object Detection")
    print("6. OCR Extraction")
    print("7. Translation Workflow")
    print("8. Identify & Greet Workflow")
    print("9. Run All Tests")
    print("0. Exit")
    print("="*60)

def main():
    print_header("SAGE App Backend Test Client")
    print_info(f"Backend URL: {BACKEND_URL}")
    
    # Check if backend is running
    try:
        response = requests.get(f"{BACKEND_URL}/")
        response.raise_for_status()
        print_success("App Backend is running!")
    except Exception as e:
        print_error(f"Cannot connect to backend: {e}")
        print_info("Make sure the backend is running on port 8002")
        return
    
    while True:
        show_menu()
        choice = input("\nEnter choice (0-9): ").strip()
        
        if choice == "1":
            test_health()
        elif choice == "2":
            test_voice_assistant()
        elif choice == "3":
            test_translation()
        elif choice == "4":
            test_facial_recognition()
        elif choice == "5":
            test_object_detection()
        elif choice == "6":
            test_ocr()
        elif choice == "7":
            test_workflow_translation()
        elif choice == "8":
            test_workflow_identify_greet()
        elif choice == "9":
            run_all_tests()
        elif choice == "0":
            print_info("Exiting...")
            break
        else:
            print_error("Invalid choice. Try again.")
        
        input("\nPress Enter to continue...")

if __name__ == "__main__":
    main()