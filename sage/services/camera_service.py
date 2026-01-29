"""
Camera Service for Raspberry Pi Camera v1 (OV5647)
Handles photo capture, video recording, live streaming, and configuration
"""

import asyncio
import base64
import io
import json
import logging
import os
import subprocess
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, Any, AsyncGenerator

import requests
from PIL import Image
from picamera2 import Picamera2
from picamera2.encoders import H264Encoder, Quality
from picamera2.outputs import FileOutput

from config import camera_config as config
from utils.image_storage import ImageStorage, VideoStorage

logger = logging.getLogger(__name__)


class CameraService:
    """Manages Pi Camera operations: photos, videos, streaming, configuration"""
    
    def __init__(self):
        """Initialize camera service"""
        self.camera = None
        self.streaming = False
        self.continuous_capturing = False
        self.continuous_thread = None
        self.continuous_failure_count = 0
        
        # Video recording state
        self.recording = False
        self.current_video_id = None
        self.recording_start_time = None
        self.video_encoder = None
        
        # Storage managers
        self.image_storage = ImageStorage(
            config.IMAGE_STORAGE_PATH,
            config.IMAGE_KEEP_LAST_N
        )
        self.video_storage = VideoStorage(
            config.VIDEO_STORAGE_PATH,
            config.VIDEO_KEEP_LAST_N,
            config.VIDEO_MAX_STORAGE_MB
        )
        
        # Load or initialize configuration
        self.camera_config = self._load_config()
        
        logger.info(f"Camera service initialized for {config.CAMERA_NAME}")
    
    def _load_config(self) -> Dict[str, Any]:
        """Load camera configuration from file or create default"""
        config_path = Path(config.CONFIG_STORAGE_PATH)
        
        if config_path.exists():
            try:
                with open(config_path, 'r') as f:
                    loaded_config = json.load(f)
                logger.info("Loaded camera configuration from file")
                return loaded_config
            except Exception as e:
                logger.error(f"Failed to load config: {e}")
        
        # Return default configuration
        return config.CAMERA_SETTINGS.copy()
    
    def _save_config(self):
        """Save current configuration to file"""
        try:
            config_path = Path(config.CONFIG_STORAGE_PATH)
            config_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(config_path, 'w') as f:
                json.dump(self.camera_config, f, indent=2)
            
            logger.info("Saved camera configuration")
        except Exception as e:
            logger.error(f"Failed to save config: {e}")
    
    def _init_camera(self, mode: str = "photo") -> Picamera2:
        """
        Initialize camera with current configuration
        
        Args:
            mode: "photo", "video", or "stream"
            
        Returns:
            Configured Picamera2 instance
        """
        camera = Picamera2()
        
        resolution = tuple(self.camera_config["resolution"])
        
        if mode == "photo":
            # Photo configuration
            photo_config = camera.create_still_configuration(
                main={"size": resolution}
            )
            camera.configure(photo_config)
        
        elif mode == "video":
            # Video configuration
            video_config = camera.create_video_configuration(
                main={"size": resolution, "format": "RGB888"}
            )
            camera.configure(video_config)
        
        elif mode == "stream":
            # Preview/streaming configuration (lower resolution for speed)
            stream_config = camera.create_preview_configuration(
                main={"size": resolution}
            )
            camera.configure(stream_config)
        
        # Apply camera settings
        camera.start()
        
        # Set controls (only if not auto)
        controls = {}
        
        if self.camera_config["shutter_speed_us"] > 0:
            controls["ExposureTime"] = self.camera_config["shutter_speed_us"]
        
        if self.camera_config["iso"] > 0:
            controls["AnalogueGain"] = self.camera_config["iso"] / 100.0
        
        if self.camera_config["brightness"] != 0.0:
            controls["Brightness"] = self.camera_config["brightness"]
        
        if self.camera_config["contrast"] != 1.0:
            controls["Contrast"] = self.camera_config["contrast"]
        
        if self.camera_config["sharpness"] != 1.0:
            controls["Sharpness"] = self.camera_config["sharpness"]
        
        if controls:
            camera.set_controls(controls)
        
        logger.debug(f"Camera initialized in {mode} mode with resolution {resolution}")
        return camera
    
    def _apply_camera_controls(self, camera: Picamera2):
        """Apply current configuration controls to an active camera instance"""
        controls = {}
        
        if self.camera_config["shutter_speed_us"] > 0:
            controls["ExposureTime"] = self.camera_config["shutter_speed_us"]
        
        if self.camera_config["iso"] > 0:
            controls["AnalogueGain"] = self.camera_config["iso"] / 100.0
        
        if self.camera_config["brightness"] != 0.0:
            controls["Brightness"] = self.camera_config["brightness"]
        
        if self.camera_config["contrast"] != 1.0:
            controls["Contrast"] = self.camera_config["contrast"]
        
        if self.camera_config["sharpness"] != 1.0:
            controls["Sharpness"] = self.camera_config["sharpness"]
        
        if controls:
            camera.set_controls(controls)
            logger.info(f"Applied camera controls: {controls}")
    
    def capture_photo(self) -> bytes:
        """
        Capture a single photo
        
        Returns:
            JPEG image bytes
        """
        camera = None
        try:
            camera = self._init_camera("photo")
            
            # Capture as numpy array
            image_array = camera.capture_array()
            
            # Convert to PIL Image
            image = Image.fromarray(image_array)
            
            # Convert RGBA to RGB if needed (JPEG doesn't support alpha)
            if image.mode == 'RGBA':
                image = image.convert('RGB')
            
            # Save to memory buffer as JPEG with quality control
            image_buffer = io.BytesIO()
            image.save(image_buffer, format='JPEG', quality=config.PHOTO_JPEG_QUALITY)
            image_buffer.seek(0)
            
            image_bytes = image_buffer.read()
            
            # Save to local storage
            self.image_storage.save_image(image_bytes)
            
            logger.info(f"Captured photo ({len(image_bytes)} bytes)")
            return image_bytes
            
        except Exception as e:
            logger.error(f"Failed to capture photo: {e}", exc_info=True)
            raise
        finally:
            if camera:
                camera.stop()
                camera.close()
    
    def capture_photo_base64(self) -> Dict[str, Any]:
        """
        Capture photo and return as base64
        
        Returns:
            Dictionary with base64 image and metadata
        """
        image_bytes = self.capture_photo()
        image_base64 = base64.b64encode(image_bytes).decode('utf-8')
        
        return {
            "image_base64": image_base64,
            "size_bytes": len(image_bytes),
            "size_kb": round(len(image_bytes) / 1024, 2),
            "timestamp": datetime.utcnow().isoformat(),
            "resolution": self.camera_config["resolution"]
        }
    
    def start_continuous_capture(self, interval: float = None) -> Dict[str, Any]:
        """
        Start continuous photo capture at intervals
        
        Args:
            interval: Seconds between captures (default: from config)
            
        Returns:
            Status dictionary
        """
        if self.continuous_capturing:
            return {"success": False, "message": "Continuous capture already running"}
        
        if interval is None:
            interval = config.CONTINUOUS_INTERVAL_SECONDS
        
        self.continuous_capturing = True
        self.continuous_failure_count = 0
        
        # Start background thread
        self.continuous_thread = threading.Thread(
            target=self._continuous_capture_loop,
            args=(interval,),
            daemon=True
        )
        self.continuous_thread.start()
        
        logger.info(f"Started continuous capture (interval: {interval}s)")
        
        return {
            "success": True,
            "status": "started",
            "interval_seconds": interval,
            "max_failures": config.CONTINUOUS_MAX_FAILURES
        }
    
    def stop_continuous_capture(self) -> Dict[str, Any]:
        """
        Stop continuous photo capture
        
        Returns:
            Status dictionary
        """
        if not self.continuous_capturing:
            return {"success": False, "message": "Continuous capture not running"}
        
        self.continuous_capturing = False
        
        # Wait for thread to finish
        if self.continuous_thread:
            self.continuous_thread.join(timeout=5)
        
        logger.info("Stopped continuous capture")
        
        return {
            "success": True,
            "status": "stopped"
        }
    
    def _continuous_capture_loop(self, interval: float):
        """Background loop for continuous capture"""
        logger.info("Continuous capture loop started")
        
        while self.continuous_capturing:
            try:
                # Capture photo
                image_bytes = self.capture_photo()
                image_base64 = base64.b64encode(image_bytes).decode('utf-8')
                
                # Send to backend
                success = self._send_to_backend(image_base64, "continuous")
                
                if success:
                    self.continuous_failure_count = 0
                else:
                    self.continuous_failure_count += 1
                    logger.warning(f"Backend failure count: {self.continuous_failure_count}")
                
                # Check failure threshold
                if self.continuous_failure_count >= config.CONTINUOUS_MAX_FAILURES:
                    logger.error("Max failures reached, stopping continuous capture")
                    self.continuous_capturing = False
                    break
                
            except Exception as e:
                logger.error(f"Error in continuous capture: {e}")
                self.continuous_failure_count += 1
                
                if self.continuous_failure_count >= config.CONTINUOUS_MAX_FAILURES:
                    logger.error("Max failures reached, stopping continuous capture")
                    self.continuous_capturing = False
                    break
            
            # Wait for next interval
            time.sleep(interval)
        
        logger.info("Continuous capture loop ended")
    
    def _send_to_backend(self, image_base64: str, capture_type: str = "single") -> bool:
        """
        Send image to backend server
        
        Args:
            image_base64: Base64 encoded image
            capture_type: "single" or "continuous"
            
        Returns:
            True if successful
        """
        try:
            url = config.BACKEND_BASE_URL + config.BACKEND_IMAGE_ENDPOINT
            
            payload = {
                "image_base64": image_base64,
                "timestamp": datetime.utcnow().isoformat(),
                "metadata": {
                    "resolution": self.camera_config["resolution"],
                    "capture_type": capture_type
                }
            }
            
            response = requests.post(
                url,
                json=payload,
                timeout=config.BACKEND_TIMEOUT
            )
            
            if response.status_code == 200:
                logger.info(f"Successfully sent image to backend ({capture_type})")
                return True
            else:
                logger.error(f"Backend returned status {response.status_code}")
                return False
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to send to backend: {e}")
            return False
    
    def start_video_recording(self, max_duration: int = None) -> Dict[str, Any]:
        """
        Start video recording
        
        Args:
            max_duration: Maximum recording duration in seconds
            
        Returns:
            Status dictionary with video_id
        """
        if self.recording:
            return {"success": False, "message": "Already recording"}
        
        if max_duration is None:
            max_duration = config.VIDEO_MAX_DURATION
        
        # Generate video ID
        timestamp = int(time.time())
        self.current_video_id = f"vid_{timestamp}"
        
        try:
            # Initialize camera for video
            self.camera = self._init_camera("video")
            
            # Get bitrate based on resolution
            resolution_key = f"{self.camera_config['resolution'][0]}x{self.camera_config['resolution'][1]}"
            bitrate = config.RESOLUTION_PRESETS.get(
                resolution_key,
                {"video_bitrate": 10000000}
            )["video_bitrate"]
            
            # Create encoder
            self.video_encoder = H264Encoder(bitrate=bitrate)
            
            # Output to H.264 file (will convert to MP4 after)
            video_h264_path = self.video_storage.storage_path / f"{self.current_video_id}.h264"
            output = FileOutput(str(video_h264_path))
            
            # Start recording
            self.camera.start_recording(self.video_encoder, output)
            self.recording = True
            self.recording_start_time = time.time()
            
            logger.info(f"Started video recording: {self.current_video_id} (max: {max_duration}s)")
            
            # Schedule auto-stop
            if max_duration > 0:
                threading.Timer(max_duration, self._auto_stop_recording).start()
            
            return {
                "success": True,
                "video_id": self.current_video_id,
                "status": "recording",
                "max_duration_seconds": max_duration,
                "resolution": self.camera_config["resolution"],
                "bitrate": bitrate
            }
            
        except Exception as e:
            logger.error(f"Failed to start recording: {e}", exc_info=True)
            self.recording = False
            self.current_video_id = None
            if self.camera:
                self.camera.close()
                self.camera = None
            raise
    
    def stop_video_recording(self, send_to_backend: bool = True) -> Dict[str, Any]:
        """
        Stop video recording and optionally send to backend
        
        Args:
            send_to_backend: Whether to upload to backend
            
        Returns:
            Status dictionary with video info
        """
        if not self.recording:
            return {"success": False, "message": "Not recording"}
        
        try:
            # Stop recording
            self.camera.stop_recording()
            self.recording = False
            
            duration = time.time() - self.recording_start_time
            video_id = self.current_video_id
            
            logger.info(f"Stopped video recording: {video_id} ({duration:.1f}s)")
            
            # Close camera
            if self.camera:
                self.camera.close()
                self.camera = None
            
            # Convert H.264 to MP4
            h264_path = self.video_storage.storage_path / f"{video_id}.h264"
            mp4_path = self.video_storage.storage_path / f"{video_id}.mp4"
            
            self._convert_to_mp4(str(h264_path), str(mp4_path))
            
            # Remove H.264 file
            if h264_path.exists():
                h264_path.unlink()
            
            # Get file size
            file_size_mb = mp4_path.stat().st_size / (1024 * 1024)
            
            result = {
                "success": True,
                "video_id": video_id,
                "duration_seconds": round(duration, 2),
                "file_size_mb": round(file_size_mb, 2),
                "file_path": str(mp4_path),
                "upload_status": "skipped"
            }
            
            # Upload to backend in background
            if send_to_backend:
                threading.Thread(
                    target=self._upload_video_to_backend,
                    args=(video_id, str(mp4_path)),
                    daemon=True
                ).start()
                result["upload_status"] = "uploading"
            
            # Cleanup old videos
            self.video_storage.cleanup_old_videos()
            
            return result
            
        except Exception as e:
            logger.error(f"Failed to stop recording: {e}", exc_info=True)
            self.recording = False
            self.current_video_id = None
            if self.camera:
                self.camera.close()
                self.camera = None
            raise
    
    def _auto_stop_recording(self):
        """Auto-stop recording when max duration reached"""
        if self.recording:
            logger.info("Auto-stopping recording (max duration reached)")
            self.stop_video_recording(send_to_backend=True)
    
    def _convert_to_mp4(self, h264_path: str, mp4_path: str):
        """
        Convert H.264 file to MP4 using ffmpeg
        
        Args:
            h264_path: Input H.264 file path
            mp4_path: Output MP4 file path
        """
        try:
            cmd = [
                "ffmpeg",
                "-i", h264_path,
                "-c", "copy",
                "-y",  # Overwrite output file
                mp4_path
            ]
            
            subprocess.run(cmd, check=True, capture_output=True)
            logger.info(f"Converted to MP4: {mp4_path}")
            
        except subprocess.CalledProcessError as e:
            logger.error(f"FFmpeg conversion failed: {e.stderr.decode()}")
            raise
        except FileNotFoundError:
            logger.error("ffmpeg not found. Install with: sudo apt install ffmpeg")
            raise
    
    def _upload_video_to_backend(self, video_id: str, video_path: str):
        """
        Upload video to backend (runs in background thread)
        
        Args:
            video_id: Video identifier
            video_path: Path to MP4 file
        """
        try:
            url = config.BACKEND_BASE_URL + config.BACKEND_VIDEO_ENDPOINT
            
            with open(video_path, 'rb') as video_file:
                files = {'video': video_file}
                data = {
                    'video_id': video_id,
                    'timestamp': datetime.utcnow().isoformat(),
                    'metadata': json.dumps({
                        'resolution': self.camera_config["resolution"],
                        'fps': config.VIDEO_DEFAULT_FPS
                    })
                }
                
                response = requests.post(
                    url,
                    files=files,
                    data=data,
                    timeout=60  # Longer timeout for video upload
                )
                
                if response.status_code == 200:
                    logger.info(f"Successfully uploaded video to backend: {video_id}")
                    
                    # Delete local file if configured
                    if config.VIDEO_AUTO_DELETE_AFTER_UPLOAD:
                        os.remove(video_path)
                        logger.info(f"Deleted local video after upload: {video_id}")
                else:
                    logger.error(f"Backend returned status {response.status_code}")
                    
        except Exception as e:
            logger.error(f"Failed to upload video: {e}")
    
    def get_video_status(self, video_id: str) -> Dict[str, Any]:
        """Get status of a video recording"""
        if self.recording and self.current_video_id == video_id:
            duration = time.time() - self.recording_start_time
            return {
                "video_id": video_id,
                "status": "recording",
                "duration_seconds": round(duration, 2)
            }
        
        # Check if video exists
        video_path = self.video_storage.get_video_path(video_id)
        if video_path.exists():
            file_size_mb = video_path.stat().st_size / (1024 * 1024)
            return {
                "video_id": video_id,
                "status": "completed",
                "file_size_mb": round(file_size_mb, 2),
                "file_path": str(video_path)
            }
        
        return {
            "video_id": video_id,
            "status": "not_found"
        }
    
    async def stream_mjpeg(self) -> AsyncGenerator[bytes, None]:
        """
        Generate MJPEG stream for live preview
        
        Yields:
            MJPEG frame bytes
        """
        try:
            # Don't allow streaming while recording
            if self.recording:
                logger.warning("Cannot start stream while recording video")
                return
            
            # Clean up any existing camera instance
            if self.camera is not None:
                try:
                    self.camera.stop()
                    self.camera.close()
                    logger.info("Closed existing camera instance")
                except Exception as e:
                    logger.warning(f"Error closing existing camera: {e}")
                self.camera = None
            
            # Small delay to ensure camera is fully released
            await asyncio.sleep(0.2)
            
            # Initialize new camera for streaming
            self.camera = self._init_camera("stream")
            self.streaming = True
            
            logger.info("Started MJPEG streaming")
            
            # Give camera time to stabilize
            await asyncio.sleep(0.5)
            
            while self.streaming:
                try:
                    # Capture frame
                    frame = self.camera.capture_array()
                    
                    # Convert to PIL Image
                    image = Image.fromarray(frame)
                    
                    # Convert RGBA to RGB if needed (JPEG doesn't support alpha)
                    if image.mode == 'RGBA':
                        image = image.convert('RGB')
                    
                    # Encode as JPEG
                    buffer = io.BytesIO()
                    image.save(buffer, format='JPEG', quality=config.STREAM_JPEG_QUALITY)
                    jpeg_bytes = buffer.getvalue()
                    
                    # Yield MJPEG frame
                    yield (b'--frame\r\n'
                           b'Content-Type: image/jpeg\r\n\r\n' + jpeg_bytes + b'\r\n')
                    
                    # Control frame rate
                    await asyncio.sleep(1.0 / config.STREAM_FPS)
                    
                except Exception as e:
                    logger.error(f"Frame capture error: {e}")
                    await asyncio.sleep(0.1)
                    continue
                
        except Exception as e:
            logger.error(f"Streaming error: {e}", exc_info=True)
        finally:
            self.streaming = False
            if self.camera:
                try:
                    self.camera.stop()
                    self.camera.close()
                except Exception as e:
                    logger.warning(f"Error during camera cleanup: {e}")
                self.camera = None
            logger.info("Stopped MJPEG streaming")
    
    def stop_streaming(self):
        """Stop MJPEG streaming"""
        self.streaming = False
    
    def get_config(self) -> Dict[str, Any]:
        """Get current camera configuration"""
        return self.camera_config.copy()
    
    def update_config(self, new_settings: Dict[str, Any]) -> Dict[str, Any]:
        """
        Update camera configuration
        
        Args:
            new_settings: Dictionary with settings to update
                - resolution: [width, height]
                - shutter_speed_ms: milliseconds (will convert to microseconds)
                - iso, brightness, contrast, sharpness: direct values
                - video_max_duration, last_videos_stored: video settings
            
        Returns:
            Updated configuration
        """
        # Handle parameter conversion and mapping
        if 'shutter_speed_ms' in new_settings:
            # Convert milliseconds to microseconds
            ms_value = new_settings.pop('shutter_speed_ms')
            new_settings['shutter_speed_us'] = int(ms_value * 1000)
        
        # Track if we need to restart stream due to resolution change
        resolution_changed = 'resolution' in new_settings and \
                            new_settings['resolution'] != self.camera_config['resolution']
        
        # Update camera settings
        for key, value in new_settings.items():
            if key in self.camera_config:
                self.camera_config[key] = value
                logger.info(f"Updated {key} to {value}")
            elif key in ['video_max_duration', 'last_videos_stored']:
                # These are video settings, not camera settings
                # Store them for informational purposes but don't validate
                # (they're used at runtime, not in camera_config)
                logger.info(f"Video setting {key} set to {value}")
        
        # Save to file
        self._save_config()
        
        # Apply changes to running camera if streaming
        if self.camera and self.streaming:
            if resolution_changed:
                # Resolution requires camera restart
                logger.info("Resolution changed, stream needs restart")
                # Note: Client should restart the stream
            else:
                # Apply other controls without restart
                try:
                    self._apply_camera_controls(self.camera)
                    logger.info("Applied new settings to running camera")
                except Exception as e:
                    logger.warning(f"Could not apply settings to running camera: {e}")
        
        return self.camera_config.copy()
    
    def reset_to_defaults(self) -> Dict[str, Any]:
        """
        Reset camera configuration to default values
        
        Returns:
            Default configuration
        """
        self.camera_config = config.CAMERA_SETTINGS.copy()
        self._save_config()
        
        # Apply to running camera if streaming
        if self.camera and self.streaming:
            try:
                self._apply_camera_controls(self.camera)
                logger.info("Applied default settings to running camera")
            except Exception as e:
                logger.warning(f"Could not apply defaults to running camera: {e}")
        
        logger.info("Reset camera configuration to defaults")
        return self.camera_config.copy()
    
    def get_status(self) -> Dict[str, Any]:
        """Get camera service status"""
        return {
            "available": True,
            "camera_type": config.CAMERA_NAME,
            "recording": self.recording,
            "streaming": self.streaming,
            "continuous_capturing": self.continuous_capturing,
            "current_video_id": self.current_video_id,
            "configuration": self.camera_config.copy(),
            "image_storage": self.image_storage.get_storage_info(),
            "video_storage": self.video_storage.get_storage_info()
        }
    
    def cleanup(self):
        """Cleanup camera resources"""
        self.stop_streaming()
        self.stop_continuous_capture()
        
        if self.recording:
            self.stop_video_recording(send_to_backend=False)
        
        if self.camera:
            self.camera.close()
            self.camera = None
        
        logger.info("Camera service cleaned up")
