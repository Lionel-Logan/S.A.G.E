"""
Test script to manually send location updates and test navigation flow
Run this after starting navigation with: "navigate to lulu mall kochi"
"""

import requests
import json
import time

BASE_URL = "http://localhost:8000/api/v1"

# Sample location near Kochi, India (adjust to your actual location)
SAMPLE_LOCATIONS = [
    {"latitude": 10.0261, "longitude": 76.3125, "accuracy": 10.0},  # Near Kochi
    {"latitude": 10.0265, "longitude": 76.3130, "accuracy": 10.0},  # Moving slightly
    {"latitude": 10.0270, "longitude": 76.3135, "accuracy": 10.0},  # Moving more
]


def check_session_status():
    """Check current navigation session status"""
    print("\n🔍 Checking navigation session status...")
    try:
        response = requests.get(f"{BASE_URL}/location/session/status")
        data = response.json()
        print(f"Response: {json.dumps(data, indent=2)}")
        return data
    except Exception as e:
        print(f"❌ Error: {e}")
        return None


def send_location_update(lat, lon, accuracy=10.0):
    """Send a location update via HTTP"""
    print(f"\n📍 Sending location: ({lat:.6f}, {lon:.6f})")
    try:
        payload = {
            "latitude": lat,
            "longitude": lon,
            "accuracy": accuracy,
            "speed": 1.2,
            "heading": 45.0,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        }
        
        response = requests.post(
            f"{BASE_URL}/location/update",
            json=payload,
            timeout=30
        )
        
        data = response.json()
        print(f"Response: {json.dumps(data, indent=2)}")
        return data
    
    except Exception as e:
        print(f"❌ Error: {e}")
        return None


def test_navigation_flow():
    """Test the complete navigation flow"""
    print("=" * 60)
    print("🧪 NAVIGATION LOCATION TEST")
    print("=" * 60)
    
    print("\nSTEP 1: First, start navigation by calling the assistant endpoint:")
    print('  POST http://localhost:8000/api/v1/assistant/ask')
    print('  Body: {"query": "navigate to lulu mall kochi", "user_id": "test_user"}')
    print("\nStarting navigation now...")
    
    try:
        response = requests.post(
            f"{BASE_URL}/assistant/ask",
            json={"query": "navigate to lulu mall kochi", "user_id": "test_user"},
            timeout=10
        )
        print(f"Response: {response.status_code}")
        if response.status_code == 200:
            print(f"Data: {json.dumps(response.json(), indent=2)}")
    except Exception as e:
        print(f"❌ Error starting navigation: {e}")
        return
    
    # Check initial status
    print("\nSTEP 2: Checking navigation session status...")
    status = check_session_status()
    
    if not status or not status.get("has_active_session"):
        print("\n⚠️ No active navigation session found!")
        print("Please start navigation first using the assistant endpoint.")
        return
    
    session = status.get("session", {})
    print(f"\n✅ Active session found!")
    print(f"   Destination: {session.get('destination')}")
    print(f"   Status: {session.get('status')}")
    
    if session.get('status') != 'waiting_for_location':
        print("\n⚠️ Session is not waiting for location. It might already have a route.")
        print("   Do you want to send location updates anyway? (y/n)")
        if input().lower() != 'y':
            return
    
    # Send location updates
    print("\nSTEP 3: Sending location updates...")
    for i, loc in enumerate(SAMPLE_LOCATIONS, 1):
        print(f"\n--- Location update {i}/{len(SAMPLE_LOCATIONS)} ---")
        result = send_location_update(
            loc["latitude"],
            loc["longitude"],
            loc["accuracy"]
        )
        
        if result and result.get("navigation_active"):
            print(f"\n✅ Navigation active!")
            print(f"   Status: {result.get('navigation_status')}")
            print(f"   Instruction: {result.get('instruction', 'N/A')}")
            
            if result.get('navigation_status') == 'active':
                print("\n🎉 Navigation route calculated successfully!")
                print("   Distance to next: {:.1f}m".format(result.get('distance_to_next', 0)))
        
        # Wait a bit between updates (simulating real location updates)
        if i < len(SAMPLE_LOCATIONS):
            print("\nWaiting 2 seconds before next update...")
            time.sleep(2)
    
    # Final status check
    print("\nSTEP 4: Final status check...")
    check_session_status()
    
    print("\n" + "=" * 60)
    print("✅ Test complete!")
    print("=" * 60)


def interactive_mode():
    """Interactive mode to manually send location updates"""
    print("=" * 60)
    print("🧪 INTERACTIVE LOCATION SENDER")
    print("=" * 60)
    print("\nCommands:")
    print("  status - Check navigation session status")
    print("  send <lat> <lon> - Send location update")
    print("  sample - Send sample location near Kochi")
    print("  quit - Exit")
    print()
    
    while True:
        try:
            cmd = input("\n> ").strip().lower()
            
            if cmd == "quit":
                break
            
            elif cmd == "status":
                check_session_status()
            
            elif cmd == "sample":
                send_location_update(10.0261, 76.3125, 10.0)
            
            elif cmd.startswith("send"):
                parts = cmd.split()
                if len(parts) >= 3:
                    lat = float(parts[1])
                    lon = float(parts[2])
                    send_location_update(lat, lon)
                else:
                    print("❌ Usage: send <latitude> <longitude>")
            
            else:
                print("❌ Unknown command. Type 'quit' to exit.")
        
        except KeyboardInterrupt:
            print("\n\nExiting...")
            break
        except Exception as e:
            print(f"❌ Error: {e}")


if __name__ == "__main__":
    print("\nChoose mode:")
    print("  1. Automated test flow")
    print("  2. Interactive mode")
    choice = input("\nChoice (1 or 2): ").strip()
    
    if choice == "1":
        test_navigation_flow()
    elif choice == "2":
        interactive_mode()
    else:
        print("Invalid choice")
