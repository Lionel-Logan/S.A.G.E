"""
Continuous Object Detection Service
Manages workflow for continuous object detection with camera and TTS output
"""

import httpx
import asyncio
from typing import Dict, Any, Optional
from datetime import datetime
from app.config import settings
import logging

logger = logging.getLogger(__name__)


class ContinuousObjectDetectionService:
    def __init__(self):
        self.is_running = False
        self.detection_count = 0
        
    async def start_continuous_detection(self, interval_seconds: float = 2.0) -> Dict[str, Any]:
        """
        Start continuous object detection by triggering Pi camera continuous capture
        
        Args:
            interval_seconds: Time between captures (default: 2.0 seconds)
            
        Returns:
            Status dictionary with success/error
        """
        if self.is_running:
            return {
                "success": False,
                "error": "Continuous object detection already running"
            }
        
        try:
            # Call Pi server to start continuous capture
            async with httpx.AsyncClient(timeout=settings.PI_REQUEST_TIMEOUT) as client:
                response = await client.post(
                    f"{settings.PI_SERVER_URL}/camera/continuous/start",
                    json={"interval_seconds": interval_seconds}
                )
                response.raise_for_status()
                result = response.json()
                
                if result.get("success"):
                    self.is_running = True
                    self.detection_count = 0
                    logger.info("Started continuous object detection")
                    
                    return {
                        "success": True,
                        "message": "Continuous object detection started",
                        "interval_seconds": interval_seconds
                    }
                else:
                    return {
                        "success": False,
                        "error": result.get("message", "Failed to start continuous capture")
                    }
                    
        except Exception as e:
            logger.error(f"Error starting continuous detection: {e}")
            return {
                "success": False,
                "error": f"Failed to start continuous detection: {str(e)}"
            }
    
    async def stop_continuous_detection(self) -> Dict[str, Any]:
        """
        Stop continuous object detection by stopping Pi camera continuous capture
        
        Returns:
            Status dictionary with success/error
        """
        if not self.is_running:
            return {
                "success": False,
                "error": "Continuous object detection not running"
            }
        
        try:
            # Call Pi server to stop continuous capture
            async with httpx.AsyncClient(timeout=settings.PI_REQUEST_TIMEOUT) as client:
                response = await client.post(
                    f"{settings.PI_SERVER_URL}/camera/continuous/stop"
                )
                response.raise_for_status()
                result = response.json()
                
                if result.get("success"):
                    self.is_running = False
                    logger.info(f"Stopped continuous object detection (processed {self.detection_count} images)")
                    
                    return {
                        "success": True,
                        "message": f"Continuous object detection stopped. Processed {self.detection_count} images.",
                        "images_processed": self.detection_count
                    }
                else:
                    return {
                        "success": False,
                        "error": result.get("message", "Failed to stop continuous capture")
                    }
                    
        except Exception as e:
            logger.error(f"Error stopping continuous detection: {e}")
            return {
                "success": False,
                "error": f"Failed to stop continuous detection: {str(e)}"
            }
    
    async def process_image(self, image_base64: str) -> Dict[str, Any]:
        """
        Process a single image: detect objects and send results to TTS
        
        Args:
            image_base64: Base64 encoded image
            
        Returns:
            Detection result dictionary
        """
        try:
            # Forward image to object detection API
            async with httpx.AsyncClient(timeout=30) as client:
                # Note: We're calling our own internal API endpoint
                # Using localhost and assuming we're running on port 8000
                response = await client.post(
                    f"http://localhost:8003{settings.API_V1_PREFIX}/objects/detect",
                    json={
                        "image_base64": image_base64,
                        "confidence_threshold": 0.5
                    },
                    headers={"Authorization": "Bearer internal_call"}  # Skip auth for internal calls
                )
                
                if response.status_code == 200:
                    result = response.json()
                    objects = result.get("objects", [])
                    
                    # Increment counter
                    self.detection_count += 1
                    
                    # Format detection results for TTS
                    if objects:
                        # Create natural language output
                        object_names = [obj.get("label", obj.get("class_name", "unknown")) for obj in objects]
                        
                        # Count occurrences
                        object_counts = {}
                        for name in object_names:
                            object_counts[name] = object_counts.get(name, 0) + 1
                        
                        # Build speech text
                        if len(object_counts) == 1 and list(object_counts.values())[0] == 1:
                            speech_text = f"I see a {list(object_counts.keys())[0]}."
                        else:
                            items = []
                            for obj_name, count in object_counts.items():
                                if count > 1:
                                    items.append(f"{count} {obj_name}s")
                                else:
                                    items.append(f"a {obj_name}")
                            
                            if len(items) == 1:
                                speech_text = f"I see {items[0]}."
                            elif len(items) == 2:
                                speech_text = f"I see {items[0]} and {items[1]}."
                            else:
                                speech_text = f"I see {', '.join(items[:-1])}, and {items[-1]}."
                    else:
                        speech_text = "I don't see any recognizable objects."
                    
                    # Send to TTS
                    await self._send_to_tts(speech_text)
                    
                    logger.info(f"Processed image {self.detection_count}: {speech_text}")
                    
                    return {
                        "success": True,
                        "objects": objects,
                        "speech_text": speech_text,
                        "detection_count": self.detection_count
                    }
                else:
                    logger.error(f"Object detection API returned status {response.status_code}")
                    return {
                        "success": False,
                        "error": f"Detection failed with status {response.status_code}"
                    }
                    
        except Exception as e:
            logger.error(f"Error processing image for object detection: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    async def _send_to_tts(self, text: str):
        """Send text to Pi server for TTS output"""
        try:
            async with httpx.AsyncClient(timeout=settings.PI_REQUEST_TIMEOUT) as client:
                await client.post(
                    f"{settings.PI_SERVER_URL}/tts/speak",
                    json={"text": text, "blocking": False}
                )
        except Exception as e:
            logger.error(f"TTS error: {e}")


# Singleton instance
_continuous_detection_service = None

def get_continuous_detection_service() -> ContinuousObjectDetectionService:
    """Get or create singleton instance of continuous detection service"""
    global _continuous_detection_service
    if _continuous_detection_service is None:
        _continuous_detection_service = ContinuousObjectDetectionService()
    return _continuous_detection_service