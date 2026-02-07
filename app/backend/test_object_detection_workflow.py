"""
Test Object Detection Workflow
Tests the complete flow: Assistant API → Pi Camera → Object Detection → TTS

This test simulates a user saying:
1. "Start scanning my environment" - Triggers continuous object detection
2. Wait for 10-15 seconds to see detections
3. "Stop scanning" - Stops continuous detection

Requirements:
- Backend server running on localhost:8000
- Pi server running on localhost:5000 (with camera)
- Object detection server running on localhost:8001
"""

import requests
import time
import json
from datetime import datetime


class ObjectDetectionWorkflowTester:
    def __init__(self, backend_url="http://localhost:8000", api_prefix="/api/v1"):
        self.backend_url = backend_url
        self.api_prefix = api_prefix
        self.assistant_url = f"{backend_url}{api_prefix}/assistant/ask"
        
    def send_assistant_query(self, query: str, user_id: str = "test_user"):
        """Send a query to the assistant API"""
        payload = {
            "query": query,
            "user_id": user_id,
            "image_data": None,
            "lat": None,
            "lon": None
        }
        
        print(f"\n{'='*60}")
        print(f"📤 Sending to Assistant: '{query}'")
        print(f"{'='*60}")
        
        try:
            response = requests.post(
                self.assistant_url,
                json=payload,
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Status: {response.status_code}")
                print(f"📝 Response Text: {result.get('response_text')}")
                print(f"🎯 Action Type: {result.get('action_type')}")
                print(f"⏰ Timestamp: {result.get('timestamp')}")
                return result
            else:
                print(f"❌ Error: Status {response.status_code}")
                print(f"Response: {response.text}")
                return None
                
        except requests.exceptions.ConnectionError:
            print(f"❌ Connection Error: Backend not reachable at {self.backend_url}")
            print("Make sure the backend server is running!")
            return None
        except requests.exceptions.Timeout:
            print(f"❌ Timeout: Request took too long")
            return None
        except Exception as e:
            print(f"❌ Unexpected Error: {e}")
            return None
    
    def test_continuous_detection(self, duration_seconds: int = 15):
        """
        Test the complete continuous object detection workflow
        
        Args:
            duration_seconds: How long to run detection (default: 15 seconds)
        """
        print("\n" + "="*60)
        print("🧪 OBJECT DETECTION WORKFLOW TEST")
        print("="*60)
        print(f"Backend URL: {self.backend_url}")
        print(f"Test Duration: {duration_seconds} seconds")
        print("="*60)
        
        # Step 1: Start continuous detection
        print("\n" + "🚀 STEP 1: Starting Continuous Object Detection")
        start_result = self.send_assistant_query("Start scanning my environment")
        
        if not start_result:
            print("\n❌ Failed to start detection. Aborting test.")
            return
        
        # Check if detection started successfully
        response_text = start_result.get('response_text', '').lower()
        if 'starting' not in response_text and 'started' not in response_text:
            print(f"\n⚠️ Warning: Unexpected response. Detection may not have started.")
            print(f"Response was: {start_result.get('response_text')}")
        
        # Step 2: Wait and let the system process images
        print(f"\n" + "⏳ STEP 2: Monitoring Detection (waiting {duration_seconds} seconds)")
        print("=" * 60)
        print("The system is now:")
        print("  1. 📷 Pi camera capturing images every 2 seconds")
        print("  2. 🔄 Backend receiving images via /api/v1/camera/image")
        print("  3. 🤖 Object detection analyzing each image")
        print("  4. 🔊 TTS speaking detected objects")
        print("\nCheck your Pi TTS output to hear the detections!")
        print("=" * 60)
        
        # Progress bar
        for i in range(duration_seconds):
            time.sleep(1)
            elapsed = i + 1
            remaining = duration_seconds - elapsed
            bar_length = 40
            filled = int((elapsed / duration_seconds) * bar_length)
            bar = "█" * filled + "░" * (bar_length - filled)
            print(f"\r⏱️  [{bar}] {elapsed}s / {duration_seconds}s (remaining: {remaining}s)", end="", flush=True)
        
        print("\n")
        
        # Step 3: Stop continuous detection
        print("\n" + "🛑 STEP 3: Stopping Continuous Object Detection")
        stop_result = self.send_assistant_query("Stop scanning")
        
        if stop_result:
            print("\n✅ Detection stopped successfully!")
        else:
            print("\n⚠️ Failed to stop detection properly")
        
        # Summary
        print("\n" + "="*60)
        print("📊 TEST SUMMARY")
        print("="*60)
        if start_result and stop_result:
            print("✅ Start Command: SUCCESS")
            print("✅ Stop Command: SUCCESS")
            print("\n🎯 Next Steps:")
            print("  1. Check Pi TTS output - Did you hear object detections?")
            print("  2. Check backend logs - Were images processed?")
            print("  3. Check Pi camera logs - Were images captured?")
            print("  4. Check object detection server logs - Were objects detected?")
        else:
            print("❌ Test completed with errors")
            print("\n🔍 Troubleshooting:")
            print("  1. Is the backend server running? (python -m uvicorn app.main:app)")
            print("  2. Is the Pi server running? (python pi_server.py)")
            print("  3. Is the object detection server running?")
        print("="*60)
    
    def test_single_shot_detection(self):
        """Test single image detection (without continuous mode)"""
        print("\n" + "="*60)
        print("🧪 SINGLE-SHOT DETECTION TEST")
        print("="*60)
        
        result = self.send_assistant_query("What objects do you see?")
        
        if result:
            print("\n✅ Single-shot detection completed")
        else:
            print("\n❌ Single-shot detection failed")
    
    def check_backend_health(self):
        """Check if backend is reachable"""
        try:
            response = requests.get(f"{self.backend_url}/health", timeout=5)
            if response.status_code == 200:
                print(f"✅ Backend is healthy: {response.json()}")
                return True
            else:
                print(f"⚠️ Backend returned status {response.status_code}")
                return False
        except:
            print(f"❌ Backend not reachable at {self.backend_url}")
            return False


def main():
    """Main test function"""
    print("""
╔══════════════════════════════════════════════════════════════╗
║          SAGE OBJECT DETECTION WORKFLOW TESTER               ║
║                                                              ║
║  This test validates the complete object detection flow:    ║
║  Assistant → Pi Camera → Object Detection → TTS             ║
╚══════════════════════════════════════════════════════════════╝
    """)
    
    # Initialize tester
    tester = ObjectDetectionWorkflowTester(
        backend_url="http://localhost:8000",
        api_prefix="/api/v1"
    )
    
    # Check backend health first
    print("\n🔍 Checking Backend Status...")
    if not tester.check_backend_health():
        print("\n❌ Cannot proceed: Backend is not running")
        print("\n💡 Start the backend with:")
        print("   cd app/backend")
        print("   python -m uvicorn app.main:app --reload --port 8000")
        return
    
    print("\n" + "="*60)
    print("Select Test Mode:")
    print("="*60)
    print("1. Continuous Detection Test (recommended)")
    print("2. Single-Shot Detection Test")
    print("3. Both Tests")
    print("="*60)
    
    choice = input("\nEnter choice (1-3, or Enter for default=1): ").strip()
    if not choice:
        choice = "1"
    
    if choice == "1":
        duration = input("\nHow long to run detection? (seconds, default=15): ").strip()
        duration = int(duration) if duration.isdigit() else 15
        tester.test_continuous_detection(duration_seconds=duration)
    
    elif choice == "2":
        tester.test_single_shot_detection()
    
    elif choice == "3":
        print("\n📋 Running Single-Shot Test First...")
        tester.test_single_shot_detection()
        
        time.sleep(2)
        
        print("\n📋 Now Running Continuous Detection Test...")
        duration = input("\nHow long to run detection? (seconds, default=15): ").strip()
        duration = int(duration) if duration.isdigit() else 15
        tester.test_continuous_detection(duration_seconds=duration)
    
    else:
        print("Invalid choice. Running default continuous test...")
        tester.test_continuous_detection(duration_seconds=15)
    
    print("\n✨ Test Complete!\n")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️ Test interrupted by user (Ctrl+C)")
        print("Sending stop command to cleanup...")
        tester = ObjectDetectionWorkflowTester()
        tester.send_assistant_query("Stop scanning")
        print("Cleanup complete.")
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
