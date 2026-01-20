"""
SAGE Complete System Test
==========================
Tests the complete flow: Pi Server → Backend → Pi Server
Simulates what the Flutter app will do
"""

import requests
import base64
import cv2
import numpy as np
import time

PI_SERVER = "http://localhost:8001"
BACKEND_SERVER = "http://localhost:8002"

# ============================================================================
# UTILITIES
# ============================================================================

def print_header(text):
    print("\n" + "="*70)
    print(f"  {text}")
    print("="*70)

def print_step(step_num, text):
    print(f"\n[Step {step_num}] {text}")

def print_success(text):
    print(f"  ✅ {text}")

def print_info(text):
    print(f"  ℹ️  {text}")

def print_error(text):
    print(f"  ❌ {text}")

def print_flow(text):
    print(f"  ➡️  {text}")

# ============================================================================
# COMPLETE FLOW TESTS
# ============================================================================

def test_complete_voice_assistant_flow():
    """
    Complete Flow: User speaks → Pi captures → Backend processes → Pi displays
    """
    print_header("TEST 1: Voice Assistant Complete Flow")
    
    try:
        # Step 1: User says "Hey Glass, what's the weather?"
        print_step(1, "User: 'Hey Glass, what's the weather?'")
        user_query = "What's the weather today?"
        print_info(f"Captured query: '{user_query}'")
        
        # Step 2: Flutter app sends query to Backend
        print_step(2, "Flutter → Backend: Send voice query")
        print_flow(f"POST {BACKEND_SERVER}/assistant/query")
        
        response = requests.post(
            f"{BACKEND_SERVER}/assistant/query",
            json={"query": user_query}
        )
        response.raise_for_status()
        backend_result = response.json()
        
        print_success(f"Backend response: '{backend_result['response_text']}'")
        print_info(f"Processing time: {backend_result['processing_time_ms']}ms")
        
        # Step 3: Flutter app sends response to Pi HUD
        print_step(3, "Flutter → Pi: Display on HUD")
        print_flow(f"POST {PI_SERVER}/hud/display")
        
        response = requests.post(
            f"{PI_SERVER}/hud/display",
            json={
                "text": backend_result['response_text'][:100],  # Truncate for HUD
                "position": "center",
                "duration_ms": 5000
            }
        )
        response.raise_for_status()
        
        print_success("Response displayed on Pi HUD")
        
        # Step 4: Optionally speak through Pi speaker
        print_step(4, "Flutter → Pi: Speak response")
        print_flow(f"POST {PI_SERVER}/speaker/speak")
        
        response = requests.post(
            f"{PI_SERVER}/speaker/speak",
            json={"text": backend_result['response_text']}
        )
        response.raise_for_status()
        
        print_success("Response spoken through Pi speaker")
        print_success("✨ Voice Assistant Flow Complete!")
        
        return True
        
    except Exception as e:
        print_error(f"Flow failed: {e}")
        return False

def test_complete_facial_recognition_flow():
    """
    Complete Flow: Pi captures image → Backend recognizes → Pi displays name
    """
    print_header("TEST 2: Facial Recognition Complete Flow")
    
    try:
        # Step 1: Pi captures camera frame
        print_step(1, "Pi: Capture camera frame")
        print_flow(f"GET {PI_SERVER}/camera/capture")
        
        response = requests.get(f"{PI_SERVER}/camera/capture")
        response.raise_for_status()
        camera_data = response.json()
        
        print_success(f"Frame captured: {camera_data['resolution']}")
        frame_base64 = camera_data['frame']
        
        # Step 2: Flutter sends frame to Backend for face recognition
        print_step(2, "Flutter → Backend: Recognize faces")
        print_flow(f"POST {BACKEND_SERVER}/recognition/faces")
        
        response = requests.post(
            f"{BACKEND_SERVER}/recognition/faces",
            json={
                "image_base64": frame_base64,
                "threshold": 0.6
            }
        )
        response.raise_for_status()
        face_data = response.json()
        
        print_success(f"Faces detected: {face_data['faces_detected']}")
        
        if face_data['faces_detected'] > 0:
            for face in face_data['faces']:
                print_info(f"  • {face['person_name']} (confidence: {face['confidence']})")
        
        # Step 3: Flutter sends results to Pi HUD
        print_step(3, "Flutter → Pi: Display names on HUD")
        
        if face_data['faces_detected'] > 0:
            names = [f['person_name'] for f in face_data['faces']]
            hud_text = ", ".join(names) if len(names) <= 3 else f"{len(names)} people detected"
        else:
            hud_text = "No faces detected"
        
        print_flow(f"POST {PI_SERVER}/hud/display")
        response = requests.post(
            f"{PI_SERVER}/hud/display",
            json={"text": hud_text, "position": "top"}
        )
        response.raise_for_status()
        
        print_success(f"Displayed: '{hud_text}'")
        
        # Step 4: Optionally speak names
        if face_data['faces_detected'] > 0:
            print_step(4, "Flutter → Pi: Speak greeting")
            greeting = f"Hello, {names[0]}!" if len(names) == 1 else f"Hello everyone!"
            
            response = requests.post(
                f"{PI_SERVER}/speaker/speak",
                json={"text": greeting}
            )
            response.raise_for_status()
            print_success(f"Spoken: '{greeting}'")
        
        print_success("✨ Facial Recognition Flow Complete!")
        return True
        
    except Exception as e:
        print_error(f"Flow failed: {e}")
        return False

def test_complete_translation_flow():
    """
    Complete Flow: Pi captures image → Backend OCR+Translate → Pi displays
    """
    print_header("TEST 3: Translation Complete Flow")
    
    try:
        # Step 1: User triggers translation
        print_step(1, "User: 'Hey Glass, translate this'")
        print_info("Translation mode activated")
        
        # Step 2: Pi captures image
        print_step(2, "Pi: Capture image to translate")
        print_flow(f"GET {PI_SERVER}/camera/capture")
        
        response = requests.get(f"{PI_SERVER}/camera/capture")
        response.raise_for_status()
        camera_data = response.json()
        
        print_success("Image captured")
        frame_base64 = camera_data['frame']
        
        # Step 3: Flutter sends to Backend translation workflow
        print_step(3, "Flutter → Backend: OCR + Translate workflow")
        print_flow(f"POST {BACKEND_SERVER}/workflow/translate-image")
        
        response = requests.post(
            f"{BACKEND_SERVER}/workflow/translate-image",
            json={
                "image_base64": frame_base64,
                "target_language": "en"
            }
        )
        response.raise_for_status()
        translation_data = response.json()
        
        print_success("Translation complete")
        print_info(f"Original: '{translation_data['translation_result']['original_text']}'")
        print_info(f"Translated: '{translation_data['translation_result']['translated_text']}'")
        
        # Step 4: Flutter sends translation to Pi HUD
        print_step(4, "Flutter → Pi: Display translation")
        
        hud_text = translation_data['translation_result']['translated_text']
        print_flow(f"POST {PI_SERVER}/hud/display")
        
        response = requests.post(
            f"{PI_SERVER}/hud/display",
            json={"text": hud_text, "position": "center"}
        )
        response.raise_for_status()
        
        print_success(f"Displayed: '{hud_text}'")
        
        # Step 5: Optionally speak translation
        print_step(5, "Flutter → Pi: Speak translation")
        response = requests.post(
            f"{PI_SERVER}/speaker/speak",
            json={"text": hud_text}
        )
        response.raise_for_status()
        print_success("Translation spoken")
        
        print_success("✨ Translation Flow Complete!")
        return True
        
    except Exception as e:
        print_error(f"Flow failed: {e}")
        return False

def test_complete_object_detection_flow():
    """
    Complete Flow: Continuous scanning → Backend detects → Pi displays objects
    """
    print_header("TEST 4: Object Detection Complete Flow")
    
    try:
        # Step 1: User starts scanning
        print_step(1, "User: 'Hey Glass, start scanning'")
        print_info("Object detection mode activated")
        
        # Simulate 3 frames of scanning (real app would do this continuously)
        for frame_num in range(1, 4):
            print(f"\n  --- Frame {frame_num} ---")
            
            # Step 2: Pi captures frame
            print_info(f"Capturing frame {frame_num}...")
            response = requests.get(f"{PI_SERVER}/camera/capture")
            response.raise_for_status()
            camera_data = response.json()
            frame_base64 = camera_data['frame']
            
            # Step 3: Flutter sends to Backend for object detection
            response = requests.post(
                f"{BACKEND_SERVER}/detection/objects",
                json={
                    "image_base64": frame_base64,
                    "confidence_threshold": 0.5
                }
            )
            response.raise_for_status()
            detection_data = response.json()
            
            # Step 4: Flutter updates Pi HUD with detected objects
            if detection_data['objects_detected'] > 0:
                objects = [obj['label'] for obj in detection_data['objects']]
                hud_text = ", ".join(objects[:3])  # Show top 3 objects
                print_info(f"Detected: {hud_text}")
                
                response = requests.post(
                    f"{PI_SERVER}/hud/display",
                    json={"text": hud_text, "position": "bottom"}
                )
                response.raise_for_status()
            
            time.sleep(0.5)  # Simulate 1-2 second intervals
        
        # Step 5: User stops scanning
        print_step(2, "User: 'Hey Glass, stop scanning'")
        print_info("Object detection stopped")
        
        response = requests.post(f"{PI_SERVER}/hud/clear")
        response.raise_for_status()
        print_success("HUD cleared")
        
        print_success("✨ Object Detection Flow Complete!")
        return True
        
    except Exception as e:
        print_error(f"Flow failed: {e}")
        return False

def check_servers():
    """Check if both servers are running"""
    print_header("System Check")
    
    # Check Pi Server
    print_info("Checking Pi Server...")
    try:
        response = requests.get(f"{PI_SERVER}/identity", timeout=2)
        response.raise_for_status()
        print_success(f"Pi Server: ONLINE ({PI_SERVER})")
    except Exception as e:
        print_error(f"Pi Server: OFFLINE - {e}")
        return False
    
    # Check Backend Server
    print_info("Checking App Backend...")
    try:
        response = requests.get(f"{BACKEND_SERVER}/health", timeout=2)
        response.raise_for_status()
        print_success(f"App Backend: ONLINE ({BACKEND_SERVER})")
    except Exception as e:
        print_error(f"App Backend: OFFLINE - {e}")
        return False
    
    return True

def pair_with_pi():
    """Ensure Pi is paired before running tests"""
    print_header("Pairing Check")
    
    try:
        # Check if already paired
        response = requests.get(f"{PI_SERVER}/identity")
        response.raise_for_status()
        data = response.json()
        
        if data['paired']:
            print_success("Pi is already paired")
            return True
        
        # Request pairing
        print_info("Requesting pairing...")
        response = requests.post(
            f"{PI_SERVER}/pairing/request",
            json={
                "app_id": "system-test-001",
                "app_name": "System Test",
                "timestamp": "2026-01-03T10:00:00"
            }
        )
        response.raise_for_status()
        
        # Confirm pairing
        print_info("Confirming pairing...")
        response = requests.post(
            f"{PI_SERVER}/pairing/confirm",
            json={"app_id": "system-test-001", "confirm": True}
        )
        response.raise_for_status()
        
        print_success("Pi paired successfully")
        return True
        
    except Exception as e:
        print_error(f"Pairing failed: {e}")
        return False

def run_complete_system_test():
    """Run all complete flow tests"""
    print_header("🚀 SAGE Complete System Test")
    print_info("This simulates what the Flutter app will do")
    print_info("Testing: Pi Server ↔ Flutter ↔ Backend Server")
    
    # Check both servers
    if not check_servers():
        print_error("Servers not ready. Start both servers first:")
        print_error("  Terminal 1: python pi_server.py")
        print_error("  Terminal 2: python app_backend.py")
        return
    
    # Ensure pairing
    if not pair_with_pi():
        return
    
    # Run complete flow tests
    tests = [
        ("Voice Assistant Flow", test_complete_voice_assistant_flow),
        ("Facial Recognition Flow", test_complete_facial_recognition_flow),
        ("Translation Flow", test_complete_translation_flow),
        ("Object Detection Flow", test_complete_object_detection_flow),
    ]
    
    passed = 0
    failed = 0
    
    for name, test_func in tests:
        time.sleep(1)  # Brief pause between tests
        if test_func():
            passed += 1
        else:
            failed += 1
    
    # Summary
    print_header("📊 Test Summary")
    print(f"  ✅ Passed: {passed}/{len(tests)}")
    print(f"  ❌ Failed: {failed}/{len(tests)}")
    
    if failed == 0:
        print_header("🎉 ALL COMPLETE FLOWS VALIDATED!")
        print_info("Architecture is ready for Flutter app development")
        print()
        print("Next Steps:")
        print("  1. ✅ Pi Server validated")
        print("  2. ✅ App Backend validated")
        print("  3. ✅ Complete flows validated")
        print("  4. ➡️  Build Flutter app that replicates these flows")
        print("  5. ➡️  Deploy to actual Raspberry Pi")
    else:
        print_error("Some flows failed. Check logs above.")

if __name__ == "__main__":
    run_complete_system_test()