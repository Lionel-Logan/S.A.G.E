"""
SAGE Pi Server - Interactive Test Client
=========================================
Tests Pi server with REAL device I/O: camera, microphone, speaker
"""

import requests
import base64
import cv2
import numpy as np
from io import BytesIO
from PIL import Image
import pyttsx3
import pyaudio
import wave
import tempfile
import os
import time

PI_SERVER_URL = "http://localhost:8001"

# ============================================================================
# UTILITIES
# ============================================================================

def print_header(text):
    """Print formatted header"""
    print("\n" + "="*60)
    print(f"  {text}")
    print("="*60)

def print_success(text):
    """Print success message"""
    print(f"✅ {text}")

def print_info(text):
    """Print info message"""
    print(f"ℹ️  {text}")

def print_error(text):
    """Print error message"""
    print(f"❌ {text}")

# ============================================================================
# API CALLS
# ============================================================================

def test_identity():
    """Test device identity endpoint"""
    print_header("Test 1: Device Identity")
    try:
        response = requests.get(f"{PI_SERVER_URL}/identity")
        response.raise_for_status()
        data = response.json()
        
        print_info(f"Device ID: {data['device_id']}")
        print_info(f"Device Name: {data['device_name']}")
        print_info(f"Paired: {data['paired']}")
        print_info(f"Capabilities: {', '.join(data['capabilities'])}")
        print_success("Identity check passed")
        return data
    except Exception as e:
        print_error(f"Failed: {e}")
        return None

def test_pairing():
    """Test pairing flow"""
    print_header("Test 2: Pairing Flow")
    
    # Step 1: Request pairing
    print_info("Step 1: Requesting pairing...")
    try:
        response = requests.post(
            f"{PI_SERVER_URL}/pairing/request",
            json={
                "app_id": "test-client-001",
                "app_name": "Test Client",
                "timestamp": "2026-01-03T10:00:00"
            }
        )
        response.raise_for_status()
        print_success("Pairing request sent")
    except Exception as e:
        print_error(f"Request failed: {e}")
        return False
    
    # Step 2: Confirm pairing
    print_info("Step 2: Confirming pairing...")
    try:
        response = requests.post(
            f"{PI_SERVER_URL}/pairing/confirm",
            json={
                "app_id": "test-client-001",
                "confirm": True
            }
        )
        response.raise_for_status()
        print_success("Pairing confirmed!")
        return True
    except Exception as e:
        print_error(f"Confirmation failed: {e}")
        return False

def test_camera_capture_and_display():
    """Test camera capture and display captured image"""
    print_header("Test 3: Camera Capture & Display")
    
    try:
        print_info("Capturing frame from Pi server...")
        response = requests.get(f"{PI_SERVER_URL}/camera/capture")
        response.raise_for_status()
        data = response.json()
        
        # Decode base64 image
        frame_base64 = data['frame']
        frame_bytes = base64.b64decode(frame_base64)
        
        print_success(f"Frame received: {data['resolution']}, {data['size_bytes']} bytes")
        
        # Convert to numpy array and display
        nparr = np.frombuffer(frame_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is not None:
            print_info("Displaying captured frame... (Press any key to close)")
            cv2.imshow('SAGE Pi Camera Feed', img)
            cv2.waitKey(0)
            cv2.destroyAllWindows()
            print_success("Camera test passed")
            return True
        else:
            print_error("Failed to decode image")
            return False
            
    except Exception as e:
        print_error(f"Camera test failed: {e}")
        return False

def test_hud_display(text="Hello SAGE!"):
    """Test HUD display"""
    print_header("Test 4: HUD Display")
    
    try:
        print_info(f"Sending text to HUD: '{text}'")
        response = requests.post(
            f"{PI_SERVER_URL}/hud/display",
            json={
                "text": text,
                "position": "center",
                "duration_ms": 3000
            }
        )
        response.raise_for_status()
        print_success("HUD display command sent")
        print_info("(On real Pi, this would show on TFT screen)")
        return True
    except Exception as e:
        print_error(f"HUD display failed: {e}")
        return False

def test_speaker_output(text="SAGE voice output test"):
    """Test speaker by speaking text using local TTS"""
    print_header("Test 5: Speaker Output")
    
    try:
        print_info(f"Speaking text: '{text}'")
        
        # Send to Pi server
        response = requests.post(
            f"{PI_SERVER_URL}/speaker/speak",
            json={"text": text}
        )
        response.raise_for_status()
        
        # Actually speak using local TTS to simulate
        print_info("Playing audio locally (simulating Pi speaker)...")
        engine = pyttsx3.init()
        engine.say(text)
        engine.runAndWait()
        
        print_success("Speaker test passed")
        return True
    except Exception as e:
        print_error(f"Speaker test failed: {e}")
        return False

def test_microphone_capture(duration=3):
    """Test microphone capture"""
    print_header("Test 6: Microphone Capture")
    
    try:
        print_info(f"Recording {duration} seconds of audio...")
        
        # Audio settings
        CHUNK = 1024
        FORMAT = pyaudio.paInt16
        CHANNELS = 1
        RATE = 16000
        
        p = pyaudio.PyAudio()
        
        # Start recording
        stream = p.open(
            format=FORMAT,
            channels=CHANNELS,
            rate=RATE,
            input=True,
            frames_per_buffer=CHUNK
        )
        
        print_info("🎤 Recording... Speak now!")
        frames = []
        
        for i in range(0, int(RATE / CHUNK * duration)):
            data = stream.read(CHUNK)
            frames.append(data)
        
        print_info("Recording complete")
        
        # Stop recording
        stream.stop_stream()
        stream.close()
        
        # Get sample size before terminating PyAudio
        sample_width = p.get_sample_size(FORMAT)
        p.terminate()
        
        # Save to temporary WAV file
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.wav')
        temp_file.close()  # Close the file handle before wave.open
        wf = wave.open(temp_file.name, 'wb')
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(sample_width)
        wf.setframerate(RATE)
        wf.writeframes(b''.join(frames))
        wf.close()
        
        # Get file size
        file_size = os.path.getsize(temp_file.name)
        
        print_success(f"Audio captured: {file_size} bytes, {duration}s @ {RATE}Hz")
        print_info(f"Audio saved to: {temp_file.name}")
        
        # Send to Pi server (in real implementation)
        response = requests.post(
            f"{PI_SERVER_URL}/microphone/capture",
            params={"duration_seconds": duration}
        )
        response.raise_for_status()
        
        print_success("Microphone test passed")
        
        # Cleanup
        # os.unlink(temp_file.name)
        return True
        
    except Exception as e:
        print_error(f"Microphone test failed: {e}")
        return False

def test_status():
    """Check device status"""
    print_header("Test 7: Device Status")
    
    try:
        response = requests.get(f"{PI_SERVER_URL}/status")
        response.raise_for_status()
        data = response.json()
        
        print_info(f"Paired: {data['paired']}")
        print_info(f"Paired App: {data['paired_app']}")
        print_info(f"Temperature: {data['temperature']}°C")
        print_info(f"HUD Active: {data['hud_active']}")
        if data['hud_active']:
            print_info(f"HUD Text: {data['hud_text']}")
        
        print_success("Status check passed")
        return True
    except Exception as e:
        print_error(f"Status check failed: {e}")
        return False

def reset_pairing():
    """Reset pairing"""
    print_header("Reset: Unpair Device")
    
    try:
        response = requests.post(f"{PI_SERVER_URL}/pairing/reset")
        response.raise_for_status()
        print_success("Device unpaired successfully")
        return True
    except Exception as e:
        print_error(f"Reset failed: {e}")
        return False

# ============================================================================
# INTERACTIVE MENU
# ============================================================================

def show_menu():
    """Show interactive menu"""
    print("\n" + "="*60)
    print("  SAGE Pi Server - Interactive Test Menu")
    print("="*60)
    print("1. Test Device Identity")
    print("2. Test Pairing Flow")
    print("3. Test Camera Capture & Display")
    print("4. Test HUD Display")
    print("5. Test Speaker Output")
    print("6. Test Microphone Capture")
    print("7. Check Device Status")
    print("8. Run All Tests (Full Flow)")
    print("9. Reset Pairing")
    print("0. Exit")
    print("="*60)

def run_all_tests():
    """Run complete test flow"""
    print_header("Running Complete Test Suite")
    
    # Test 1: Identity
    if not test_identity():
        return
    
    time.sleep(1)
    
    # Test 2: Pairing
    if not test_pairing():
        return
    
    time.sleep(1)
    
    # Test 3: Camera
    if not test_camera_capture_and_display():
        return
    
    time.sleep(1)
    
    # Test 4: HUD
    if not test_hud_display("Complete test running..."):
        return
    
    time.sleep(1)
    
    # Test 5: Speaker
    if not test_speaker_output("All systems operational"):
        return
    
    time.sleep(1)
    
    # Test 6: Microphone
    if not test_microphone_capture(duration=3):
        return
    
    time.sleep(1)
    
    # Test 7: Status
    test_status()
    
    print_header("🎉 ALL TESTS PASSED!")

def main():
    """Main interactive loop"""
    print_header("SAGE Pi Server Test Client")
    print_info(f"Connecting to: {PI_SERVER_URL}")
    
    # Check if server is running
    try:
        response = requests.get(f"{PI_SERVER_URL}/")
        response.raise_for_status()
        print_success("Pi server is running!")
    except Exception as e:
        print_error(f"Cannot connect to Pi server: {e}")
        print_info("Make sure the Pi server is running on port 8001")
        return
    
    while True:
        show_menu()
        choice = input("\nEnter choice (0-9): ").strip()
        
        if choice == "1":
            test_identity()
        elif choice == "2":
            test_pairing()
        elif choice == "3":
            test_camera_capture_and_display()
        elif choice == "4":
            text = input("Enter text to display on HUD: ").strip()
            if text:
                test_hud_display(text)
        elif choice == "5":
            text = input("Enter text to speak: ").strip()
            if text:
                test_speaker_output(text)
        elif choice == "6":
            duration = input("Enter recording duration (seconds, default=3): ").strip()
            duration = int(duration) if duration.isdigit() else 3
            test_microphone_capture(duration)
        elif choice == "7":
            test_status()
        elif choice == "8":
            run_all_tests()
        elif choice == "9":
            reset_pairing()
        elif choice == "0":
            print_info("Exiting...")
            break
        else:
            print_error("Invalid choice. Try again.")
        
        input("\nPress Enter to continue...")

if __name__ == "__main__":
    main()