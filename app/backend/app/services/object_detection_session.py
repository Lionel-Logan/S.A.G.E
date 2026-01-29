import asyncio
import httpx
from datetime import datetime
from typing import Optional, Dict
from app.config import settings
from app.services.model_client import ObjectDetectionClient


class ObjectDetectionSession:
    """
    Manages object detection sessions with periodic image capture from Pi camera.
    Handles start/stop of detection loop and processes frames through ML server.
    """
    
    def __init__(self):
        self.active_session: Optional[asyncio.Task] = None
        self.session_id: Optional[str] = None
        self.is_running: bool = False
        self.detection_interval: float = 2.0  # 2 seconds between captures
        self.pi_server_url: str = settings.PI_SERVER_URL
        self.pi_timeout: float = settings.PI_REQUEST_TIMEOUT
        
    async def start_detection(self, session_id: str) -> Dict:
        """
        Start periodic object detection session.
        
        Args:
            session_id: Unique identifier for this detection session
            
        Returns:
            dict with session start status
        """
        if self.is_running:
            return {
                "error": "Detection session already running. Stop current session first."
            }
        
        self.session_id = session_id
        self.is_running = True
        
        # Start background task for periodic detection
        self.active_session = asyncio.create_task(self._detection_loop())
        
        print(f"✓ Object detection session started: {session_id}")
        return {
            "status": "started",
            "session_id": session_id,
            "interval_seconds": self.detection_interval
        }
    
    async def stop_detection(self) -> Dict:
        """
        Stop the active object detection session.
        
        Returns:
            dict with session stop status
        """
        if not self.is_running:
            return {
                "error": "No active detection session to stop."
            }
        
        self.is_running = False
        
        # Cancel background task
        if self.active_session:
            self.active_session.cancel()
            try:
                await self.active_session
            except asyncio.CancelledError:
                pass
        
        session_id = self.session_id
        self.session_id = None
        self.active_session = None
        
        print(f"✓ Object detection session stopped: {session_id}")
        return {
            "status": "stopped",
            "session_id": session_id
        }
    
    def get_status(self) -> Dict:
        """Get current session status."""
        return {
            "is_running": self.is_running,
            "session_id": self.session_id,
            "interval_seconds": self.detection_interval if self.is_running else None
        }
    
    async def _detection_loop(self):
        """
        Background task that runs periodic object detection.
        Captures image from Pi, processes through ML server, sends results to TTS and stores for frontend.
        """
        print(f"🔄 Starting detection loop (interval: {self.detection_interval}s)")
        
        while self.is_running:
            try:
                # 1. Capture image from Pi camera
                image_base64 = await self._capture_image_from_pi()
                
                if not image_base64:
                    print("⚠️ Failed to capture image from Pi, skipping frame...")
                    await asyncio.sleep(self.detection_interval)
                    continue
                
                # 2. Send to object detection ML server
                detection_result = await self._detect_objects(image_base64)
                
                if "error" in detection_result:
                    print(f"⚠️ Detection error: {detection_result['error']}, skipping frame...")
                    await asyncio.sleep(self.detection_interval)
                    continue
                
                # 3. Format result for voice output
                voice_text = self._format_for_voice(detection_result)
                
                # 4. Send to Pi TTS for voice output
                await self._send_to_tts(voice_text)
                
                # 5. Store result for frontend retrieval (optional - can be enhanced later)
                print(f"✓ Detection result: {voice_text}")
                
                # Wait for next interval
                await asyncio.sleep(self.detection_interval)
                
            except asyncio.CancelledError:
                print("Detection loop cancelled")
                break
            except Exception as e:
                print(f"⚠️ Error in detection loop: {e}, continuing...")
                await asyncio.sleep(self.detection_interval)
    
    async def _capture_image_from_pi(self) -> Optional[str]:
        """
        Capture image from Pi camera endpoint.
        
        Returns:
            Base64 encoded image string, or None if failed
        """
        try:
            async with httpx.AsyncClient(timeout=self.pi_timeout) as client:
                response = await client.post(f"{self.pi_server_url}/camera/capture_photo_base64")
                response.raise_for_status()
                data = response.json()
                
                if data.get("success") and "image_base64" in data:
                    return data["image_base64"]
                else:
                    print(f"⚠️ Pi camera response missing image_base64")
                    return None
                    
        except httpx.TimeoutException:
            print("⚠️ Pi camera request timed out")
            return None
        except httpx.HTTPError as e:
            print(f"⚠️ Pi camera HTTP error: {e}")
            return None
        except Exception as e:
            print(f"⚠️ Pi camera error: {e}")
            return None
    
    async def _detect_objects(self, image_base64: str) -> Dict:
        """
        Send image to object detection ML server.
        
        Returns:
            Detection result dict
        """
        try:
            client = ObjectDetectionClient()
            result = await client.detect_objects(image_base64, confidence_threshold=0.5)
            await client.close()
            return result
        except Exception as e:
            return {"error": str(e)}
    
    def _format_for_voice(self, detection_result: Dict) -> str:
        """
        Format detection result into voice-friendly text.
        
        Args:
            detection_result: Result from object detection ML server
            
        Returns:
            Natural language description for TTS
        """
        if "detected_objects" not in detection_result:
            return "No objects detected."
        
        objects = detection_result["detected_objects"]
        
        if len(objects) == 0:
            return "No objects in view."
        elif len(objects) == 1:
            obj = objects[0]
            return f"I see {obj.get('position_description', obj['label'])}."
        else:
            # List multiple objects with positions
            descriptions = [obj.get('position_description', obj['label']) for obj in objects[:5]]
            if len(objects) > 5:
                return f"I see {', '.join(descriptions[:4])}, and {len(objects) - 4} more objects."
            else:
                return f"I see {', '.join(descriptions[:-1])}, and {descriptions[-1]}."
    
    async def _send_to_tts(self, text: str):
        """
        Send text to Pi TTS endpoint for voice output.
        
        Args:
            text: Text to speak
        """
        try:
            async with httpx.AsyncClient(timeout=self.pi_timeout) as client:
                response = await client.post(
                    f"{self.pi_server_url}/tts/speak",
                    json={"text": text, "blocking": False}
                )
                response.raise_for_status()
                print(f"🔊 TTS: {text}")
        except Exception as e:
            print(f"⚠️ TTS error: {e}")


# Global session manager instance
_session_manager: Optional[ObjectDetectionSession] = None


def get_detection_session() -> ObjectDetectionSession:
    """Get or create the global object detection session manager."""
    global _session_manager
    if _session_manager is None:
        _session_manager = ObjectDetectionSession()
    return _session_manager
