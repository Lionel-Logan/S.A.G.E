#!/usr/bin/env python3
"""
Wake Word Detection Service using Porcupine
Listens for "Hey Sage" wake word
"""

import logging
import struct
import pyaudio
from typing import Optional, Callable

try:
    import pvporcupine
except ImportError:
    pvporcupine = None
    logging.warning("pvporcupine not installed. Run: pip install pvporcupine")

from config import voice_config as config

logger = logging.getLogger(__name__)


class WakeWordService:
    """Handles wake word detection using Porcupine"""
    
    def __init__(self, callback: Optional[Callable] = None):
        """
        Initialize Porcupine wake word detector
        
        Args:
            callback: Optional function to call when wake word detected
        """
        self.callback = callback
        self.porcupine = None
        self.audio = None
        self.stream = None
        self.running = False
        
        if pvporcupine is None:
            raise RuntimeError("pvporcupine not installed. Install with: pip install pvporcupine")
        
        if not config.PORCUPINE_ACCESS_KEY:
            raise ValueError(
                "PORCUPINE_ACCESS_KEY not configured. "
                "Get a free key from https://console.picovoice.ai/"
            )
        
        self._initialize_porcupine()
    
    def _initialize_porcupine(self):
        """Initialize Porcupine engine"""
        try:
            # Use custom trained "Hey Sage" wake word model
            keyword_path = "/home/sage/sage/models/hey-sage-wake-up-train.ppn"
            
            self.porcupine = pvporcupine.create(
                access_key=config.PORCUPINE_ACCESS_KEY,
                keyword_paths=[keyword_path],
                sensitivities=[config.PORCUPINE_SENSITIVITY]
            )
            
            self.audio = pyaudio.PyAudio()
            
            logger.info(f"Porcupine initialized (version {self.porcupine.version})")
            logger.info(f"Sample rate: {self.porcupine.sample_rate} Hz")
            logger.info(f"Frame length: {self.porcupine.frame_length}")
            logger.info(f"Using custom 'Hey Sage' wake word model: {keyword_path}")
            
        except Exception as e:
            logger.error(f"Failed to initialize Porcupine: {e}")
            raise
    
    def start_listening(self):
        """
        Start listening for wake word in blocking mode
        Call stop_listening() from another thread to stop
        """
        if self.running:
            logger.warning("Already listening for wake word")
            return
        
        device_index = self._get_input_device_index()
        
        try:
            # Open audio stream
            self.stream = self.audio.open(
                rate=self.porcupine.sample_rate,
                channels=1,
                format=pyaudio.paInt16,
                input=True,
                input_device_index=device_index,
                frames_per_buffer=self.porcupine.frame_length
            )
            
            self.running = True
            logger.info(f"🎤 Listening for wake word... Say '{config.WAKE_WORD}'")
            
            while self.running:
                try:
                    # Read audio frame
                    pcm = self.stream.read(
                        self.porcupine.frame_length,
                        exception_on_overflow=False
                    )
                    pcm = struct.unpack_from("h" * self.porcupine.frame_length, pcm)
                    
                    # Check for wake word
                    keyword_index = self.porcupine.process(pcm)
                    
                    if keyword_index >= 0:
                        logger.info("🎉 Wake word detected!")
                        if self.callback:
                            self.callback()
                        
                except Exception as e:
                    logger.error(f"Error processing audio frame: {e}")
                    continue
            
            logger.info("Stopped listening for wake word")
            
        except Exception as e:
            logger.error(f"Error in wake word detection: {e}", exc_info=True)
        finally:
            if self.stream:
                self.stream.stop_stream()
                self.stream.close()
                self.stream = None
            self.running = False
    
    def stop_listening(self):
        """Stop listening for wake word"""
        self.running = False
    
    def _get_input_device_index(self) -> Optional[int]:
        """Get the input device index for the configured microphone"""
        # Use PulseAudio device for automatic resampling
        try:
            for i in range(self.audio.get_device_count()):
                device_info = self.audio.get_device_info_by_index(i)
                if device_info.get('maxInputChannels') > 0:
                    device_name = device_info.get('name', '')
                    # Prefer 'pulse' device for resampling support
                    if device_name == 'pulse':
                        logger.info(f"Using input device: {device_name} (with resampling)")
                        return i
            
            # Fallback to default
            logger.warning("Could not find pulse device, using default")
            return None
        except Exception as e:
            logger.error(f"Error finding input device: {e}")
            return None
    
    def cleanup(self):
        """Clean up resources"""
        self.stop_listening()
        
        if self.porcupine:
            try:
                self.porcupine.delete()
            except:
                pass
        
        if self.audio:
            try:
                self.audio.terminate()
            except:
                pass
        
        logger.info("WakeWordService cleaned up")
    
    def __del__(self):
        """Ensure cleanup on deletion"""
        self.cleanup()
