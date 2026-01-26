#!/usr/bin/env python3
"""
Audio Manager for SAGE Voice Assistant
Handles audio recording, playback, and silence detection
"""

import pyaudio
import wave
import numpy as np
import logging
import os
from pathlib import Path
from typing import Optional, Tuple
from datetime import datetime

from config import voice_config as config

logger = logging.getLogger(__name__)


class AudioManager:
    """Manages audio input/output operations"""
    
    def __init__(self):
        """Initialize PyAudio and configure audio settings"""
        self.audio = pyaudio.PyAudio()
        self.sample_rate = config.SAMPLE_RATE
        self.channels = config.CHANNELS
        self.chunk_size = config.CHUNK_SIZE
        self.format = pyaudio.paInt16  # 16-bit audio
        
        self.recording = False
        self.stream = None
        
        # Create debug directory if needed
        if config.SAVE_RECORDINGS:
            Path(config.DEBUG_AUDIO_DIR).mkdir(parents=True, exist_ok=True)
        
        logger.info("AudioManager initialized")
        self._log_audio_devices()
    
    def _log_audio_devices(self):
        """Log available audio devices for debugging"""
        try:
            info = self.audio.get_host_api_info_by_index(0)
            num_devices = info.get('deviceCount')
            
            logger.info(f"Found {num_devices} audio devices:")
            for i in range(num_devices):
                device_info = self.audio.get_device_info_by_host_api_device_index(0, i)
                if device_info.get('maxInputChannels') > 0:
                    logger.info(f"  Input Device {i}: {device_info.get('name')}")
        except Exception as e:
            logger.warning(f"Could not enumerate audio devices: {e}")
    
    def get_input_device_index(self) -> Optional[int]:
        """
        Get the input device index for the configured PulseAudio source
        
        Returns:
            Device index or None to use default
        """
        try:
            # Use PulseAudio device for automatic resampling
            for i in range(self.audio.get_device_count()):
                device_info = self.audio.get_device_info_by_index(i)
                if device_info.get('maxInputChannels') > 0:
                    device_name = device_info.get('name', '')
                    # Prefer 'pulse' device for resampling support
                    if device_name == 'pulse':
                        logger.info(f"Found input device: {device_name} (index {i})")
                        return i
            
            logger.warning("Could not find pulse device, using default")
            return None
        except Exception as e:
            logger.error(f"Error finding input device: {e}")
            return None
    
    def record_with_streaming_callback(self, callback) -> Tuple[Optional[bytes], float]:
        """
        Record audio until silence, streaming chunks to callback for real-time transcription
        
        Args:
            callback: Function to call with each audio chunk (chunk_data: bytes)
            
        Returns:
            Tuple of (audio_data as bytes, duration in seconds)
            Returns (None, 0) if recording failed
        """
        frames = []
        silent_chunks = 0
        chunks_per_second = self.sample_rate / self.chunk_size
        silence_chunks_needed = int(config.SILENCE_DURATION * chunks_per_second)
        max_chunks = int(config.MAX_RECORDING_DURATION * chunks_per_second)
        
        device_index = self.get_input_device_index()
        
        try:
            # Open audio stream
            self.stream = self.audio.open(
                format=self.format,
                channels=self.channels,
                rate=self.sample_rate,
                input=True,
                input_device_index=device_index,
                frames_per_buffer=self.chunk_size
            )
            
            self.recording = True
            logger.info("🎙️ Recording started... Streaming transcription active!")
            
            chunk_count = 0
            while self.recording and chunk_count < max_chunks:
                try:
                    data = self.stream.read(self.chunk_size, exception_on_overflow=False)
                    frames.append(data)
                    chunk_count += 1
                    
                    # Stream chunk to callback for real-time transcription
                    if callback:
                        callback(data)
                    
                    # Check for silence
                    audio_data = np.frombuffer(data, dtype=np.int16)
                    amplitude = np.abs(audio_data).mean()
                    
                    if amplitude < config.SILENCE_THRESHOLD:
                        silent_chunks += 1
                        if silent_chunks >= silence_chunks_needed:
                            logger.info("Silence detected, stopping recording")
                            break
                    else:
                        silent_chunks = 0  # Reset counter if sound detected
                        
                except Exception as e:
                    logger.error(f"Error reading audio chunk: {e}")
                    break
            
            self.recording = False
            self.stream.stop_stream()
            self.stream.close()
            self.stream = None
            
            # Calculate duration
            duration = len(frames) * self.chunk_size / self.sample_rate
            
            # Check minimum duration
            if duration < config.MIN_RECORDING_DURATION:
                logger.warning(f"Recording too short ({duration:.2f}s), discarding")
                return None, 0
            
            # Convert frames to bytes
            audio_data = b''.join(frames)
            
            logger.info(f"Recording complete: {duration:.2f} seconds, {len(frames)} chunks")
            return audio_data, duration
            
        except Exception as e:
            logger.error(f"Recording error: {e}", exc_info=True)
            return None, 0
    
    def record_until_silence(self) -> Tuple[Optional[bytes], float]:
        """
        Record audio until silence is detected (non-streaming version for compatibility)
        
        Returns:
            Tuple of (audio_data as bytes, duration in seconds)
            Returns (None, 0) if recording failed
        """
        return self.record_with_streaming_callback(callback=None)
    
    def stop_recording(self):
        """Stop the current recording"""
        self.recording = False
    
    def save_audio(self, audio_data: bytes, filename: str) -> bool:
        """
        Save audio data to WAV file
        
        Args:
            audio_data: Raw audio bytes
            filename: Output filename (full path)
            
        Returns:
            True if saved successfully
        """
        try:
            with wave.open(filename, 'wb') as wf:
                wf.setnchannels(self.channels)
                wf.setsampwidth(self.audio.get_sample_size(self.format))
                wf.setframerate(self.sample_rate)
                wf.writeframes(audio_data)
            
            logger.info(f"Audio saved to {filename}")
            return True
        except Exception as e:
            logger.error(f"Error saving audio: {e}")
            return False
    
    def play_tone(self, tone_file: str) -> bool:
        """
        Play an audio tone file
        
        Args:
            tone_file: Path to audio file
            
        Returns:
            True if played successfully
        """
        if not os.path.exists(tone_file):
            logger.warning(f"Tone file not found: {tone_file}")
            return False
        
        try:
            # Read the tone file
            with wave.open(tone_file, 'rb') as wf:
                # Open output stream
                stream = self.audio.open(
                    format=self.audio.get_format_from_width(wf.getsampwidth()),
                    channels=wf.getnchannels(),
                    rate=wf.getframerate(),
                    output=True
                )
                
                # Play the tone
                data = wf.readframes(self.chunk_size)
                while data:
                    stream.write(data)
                    data = wf.readframes(self.chunk_size)
                
                stream.stop_stream()
                stream.close()
            
            logger.debug(f"Played tone: {tone_file}")
            return True
        except Exception as e:
            logger.error(f"Error playing tone: {e}")
            return False
    
    def save_recording_debug(self, audio_data: bytes, prefix: str = "recording") -> Optional[str]:
        """
        Save recording for debugging purposes
        
        Args:
            audio_data: Raw audio bytes
            prefix: Filename prefix
            
        Returns:
            Path to saved file or None if failed
        """
        if not config.SAVE_RECORDINGS:
            return None
        
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"{prefix}_{timestamp}.wav"
            filepath = os.path.join(config.DEBUG_AUDIO_DIR, filename)
            
            if self.save_audio(audio_data, filepath):
                return filepath
            return None
        except Exception as e:
            logger.error(f"Error saving debug recording: {e}")
            return None
    
    def cleanup(self):
        """Clean up audio resources"""
        if self.stream:
            try:
                self.stream.stop_stream()
                self.stream.close()
            except:
                pass
        
        if self.audio:
            try:
                self.audio.terminate()
            except:
                pass
        
        logger.info("AudioManager cleaned up")
