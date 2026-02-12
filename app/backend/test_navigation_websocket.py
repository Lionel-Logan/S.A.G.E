import asyncio
import websockets
import json
from datetime import datetime

async def test_navigation():
    uri = "ws://localhost:8000/api/v1/location/ws/test_device"
    
    # Simulated location updates (moving from start to destination)
    locations = [
        {"lat": 40.7589, "lon": -73.9851, "speed": 1.2, "accuracy": 10},  # Starting point
        {"lat": 40.7600, "lon": -73.9840, "speed": 1.5, "accuracy": 8},   # Moving
        {"lat": 40.7610, "lon": -73.9830, "speed": 1.3, "accuracy": 9},   # Near turn
        {"lat": 40.7620, "lon": -73.9820, "speed": 1.4, "accuracy": 7},   # After turn
        {"lat": 40.7630, "lon": -73.9810, "speed": 1.2, "accuracy": 10},  # Continuing
    ]
    
    async with websockets.connect(uri) as websocket:
        print("✅ WebSocket connected")
        
        for i, loc in enumerate(locations):
            # Send location update
            message = {
                "type": "location_update",
                "data": {
                    "latitude": loc["lat"],
                    "longitude": loc["lon"],
                    "accuracy": loc["accuracy"],
                    "speed": loc["speed"],
                    "heading": 45.0,
                    "timestamp": datetime.utcnow().isoformat() + "Z"
                }
            }
            
            print(f"\n📍 Sending location update {i+1}/{len(locations)}:")
            print(f"   Lat: {loc['lat']}, Lon: {loc['lon']}")
            
            await websocket.send(json.dumps(message))
            
            # Receive response
            response = await websocket.recv()
            data = json.loads(response)
            
            print(f"📨 Response: {data}")
            
            if data.get("type") == "navigation_update":
                print(f"   🗣️ Instruction: {data.get('instruction')}")
                print(f"   📏 Distance to next: {data.get('distance_to_next')}m")
                print(f"   📊 Status: {data.get('status')}")
            
            # Wait 3 seconds between updates (simulating real polling)
            await asyncio.sleep(3)

if __name__ == "__main__":
    asyncio.run(test_navigation())