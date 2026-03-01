"""
Shared WebSocket connection registry.

Both location.py and assistant.py import from here so that
assistant.py can command the frontend (START/STOP_LOCATION_SHARING)
without creating a circular import between the two routers.
"""

from typing import Dict
from fastapi import WebSocket

# Active WebSocket connections keyed by device_id
# Single-user system: normally only one entry at a time
active_connections: Dict[str, WebSocket] = {}


async def send_command_to_any_device(command: dict) -> bool:
    """
    Send a JSON command to the first connected device via WebSocket.
    Used by assistant.py to trigger START/STOP_LOCATION_SHARING on the app.

    Returns True if sent successfully, False if no device is connected.
    """
    if not active_connections:
        print(f"⚠️ [Connections] No connected device — command not sent: {command.get('command')}")
        return False

    device_id = next(iter(active_connections))
    ws = active_connections[device_id]

    try:
        await ws.send_json(command)
        print(f"📡 [Connections] Sent '{command.get('command')}' to device: {device_id}")
        return True
    except Exception as e:
        print(f"❌ [Connections] Failed to send to device {device_id}: {e}")
        return False
