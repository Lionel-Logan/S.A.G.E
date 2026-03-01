"""
End-to-end navigation test — simulates the full flow:

  1. Connects a WebSocket as the "mobile app"
  2. Sends "navigate to Lulu Mall Kochi" as the Pi voice query
  3. Waits for START_LOCATION_SHARING command from backend
  4. Streams simulated GPS coordinates (walking path near Kochi)
  5. Prints every backend response and TTS trigger

Run from: D:\S8 Project\S.A.G.E\app\backend
Usage:    python test_navigation_e2e.py
"""

import asyncio
import json
import requests
import websockets
import uuid
import time

# ── Config ────────────────────────────────────────────────────────────────────
BASE_HTTP   = "http://localhost:8000/api/v1"
WS_URL      = "ws://localhost:8000/api/v1/location/ws/test-device-001"
DEVICE_ID   = "test-device-001"
DESTINATION = "Lulu Mall Kochi"

# Simulated walking path (Edappally area, Kochi — near Lulu Mall)
# Each point is ~50-80m apart, simulating a walking pace
GPS_WAYPOINTS = [
    (10.0261, 76.3125),   # Start — Edappally
    (10.0266, 76.3120),   # Moving northwest
    (10.0271, 76.3115),   # Approaching junction
    (10.0275, 76.3110),   # Turning area
    (10.0278, 76.3105),   # Continuing
    (10.0280, 76.3098),   # Near NH544
    (10.0276, 76.3090),   # Approaching walkway
    (10.0273, 76.3085),   # Lulu Mall walkway
    (10.0271, 76.3082),   # Destination vicinity
]
GPS_INTERVAL_SECONDS = 3  # Send GPS every 3 seconds

# ── Helpers ───────────────────────────────────────────────────────────────────

def trigger_navigation():
    """Step 1: POST to assistant (simulating Pi voice command)"""
    print("\n" + "=" * 60)
    print("STEP 1 — Triggering navigation via assistant endpoint")
    print(f"  Query: 'navigate to {DESTINATION}'")
    print("=" * 60)

    try:
        resp = requests.post(
            f"{BASE_HTTP}/assistant/ask",
            json={"query": f"navigate to {DESTINATION}", "user_id": "pi_device"},
            timeout=15
        )
        data = resp.json()
        print(f"  ✅ Response ({resp.status_code}): {data.get('response_text')}")
        print(f"  Action: {data.get('action_type')}")
        return resp.status_code == 200
    except Exception as e:
        print(f"  ❌ Failed: {e}")
        return False


def check_session_status():
    """Check navigation session status via HTTP"""
    try:
        resp = requests.get(f"{BASE_HTTP}/location/session/status", timeout=5)
        return resp.json()
    except Exception as e:
        print(f"  ❌ Status check failed: {e}")
        return None


def make_location_message(lat: float, lon: float, idx: int) -> str:
    """Build a location_update WebSocket message (matches frontend format)"""
    return json.dumps({
        "type": "LOCATION_UPDATE",
        "data": {
            "latitude": lat,
            "longitude": lon,
            "accuracy": 8.0,
            "altitude": 5.0,
            "speed": 1.4,       # walking speed ~5 km/h
            "heading": 315.0,   # northwest
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        }
    })


async def run_websocket_and_navigate():
    """Main coroutine — WebSocket lifecycle + navigation flow"""

    print(f"\n🔌 Connecting WebSocket as mock app: {WS_URL}")

    async with websockets.connect(WS_URL) as ws:
        print("✅ WebSocket connected\n")

        # ── Step 1: trigger navigation (in background so we can keep reading WS) ──
        loop = asyncio.get_event_loop()
        trigger_task = loop.run_in_executor(None, trigger_navigation)

        start_received = False
        gps_task_started = False

        async def send_gps_stream():
            """Send simulated GPS waypoints at GPS_INTERVAL_SECONDS intervals"""
            print("\n" + "=" * 60)
            print("STEP 3 — Streaming GPS waypoints")
            print(f"  {len(GPS_WAYPOINTS)} points, {GPS_INTERVAL_SECONDS}s apart")
            print("=" * 60)

            for i, (lat, lon) in enumerate(GPS_WAYPOINTS, 1):
                msg = make_location_message(lat, lon, i)
                await ws.send(msg)
                print(f"\n  📍 [{i}/{len(GPS_WAYPOINTS)}] Sent: ({lat:.6f}, {lon:.6f})")
                if i < len(GPS_WAYPOINTS):
                    await asyncio.sleep(GPS_INTERVAL_SECONDS)

            print("\n  ✅ All GPS waypoints sent")

        # ── Keep reading messages from backend ────────────────────────────────
        print("\nSTEP 2 — Listening for commands and responses from backend...")
        print("  (waiting for START_LOCATION_SHARING)\n")

        try:
            async for raw in ws:
                msg = json.loads(raw)
                msg_type = msg.get("type", "").lower()
                command   = msg.get("command", "").upper()

                # ── START_LOCATION_SHARING ───────────────────────────────────
                if command == "START_LOCATION_SHARING":
                    print(f"  ✅ Received START_LOCATION_SHARING from backend")
                    print(f"     request_id: {msg.get('request_id')}")
                    start_received = True

                    if not gps_task_started:
                        gps_task_started = True
                        asyncio.ensure_future(send_gps_stream())

                # ── STOP_LOCATION_SHARING ────────────────────────────────────
                elif command == "STOP_LOCATION_SHARING":
                    print(f"\n  🛑 Received STOP_LOCATION_SHARING — navigation ended")
                    print(f"     request_id: {msg.get('request_id')}")
                    break

                # ── Silent ack ───────────────────────────────────────────────
                elif msg_type == "ack":
                    nav = msg.get("navigation_active")
                    # Minimal log to avoid noise
                    print(f"  · ack (navigation_active={nav})")

                # ── Ping ─────────────────────────────────────────────────────
                elif msg_type == "ping":
                    await ws.send(json.dumps({
                        "type": "pong",
                        "request_id": msg.get("request_id")
                    }))

                # ── Error ────────────────────────────────────────────────────
                elif msg_type == "error":
                    print(f"  ⚠️  Backend error: {msg.get('message')}")

                else:
                    print(f"  📩 Unhandled message: {json.dumps(msg)}")

        except websockets.exceptions.ConnectionClosed:
            print("\n🔌 WebSocket closed by backend")

    # ── Final status check ─────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("STEP 4 — Final session status")
    print("=" * 60)
    status = check_session_status()
    if status:
        session = status.get("session", {})
        print(f"  Session status : {session.get('status')}")
        print(f"  Destination    : {session.get('destination')}")
        print(f"  Steps covered  : {session.get('current_step')}/{session.get('total_steps')}")
        print(f"  Elapsed        : {session.get('elapsed_time', 0):.0f}s")

    print("\n" + "=" * 60)
    print("✅ End-to-end test complete")
    print("=" * 60)


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("╔══════════════════════════════════════════════════════════╗")
    print("║        S.A.G.E Navigation End-to-End Test               ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print(f"\n  Backend  : {BASE_HTTP}")
    print(f"  WebSocket: {WS_URL}")
    print(f"  Target   : {DESTINATION}")
    print(f"  GPS pts  : {len(GPS_WAYPOINTS)} waypoints @ {GPS_INTERVAL_SECONDS}s each")

    # Quick health check before starting
    try:
        r = requests.get(f"http://localhost:8000/health", timeout=3)
        print(f"\n  Backend health: ✅ ({r.status_code})")
    except Exception:
        print("\n  ⚠️  Backend not reachable at localhost:8000")
        print("  Start it with: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload")
        exit(1)

    asyncio.run(run_websocket_and_navigate())
