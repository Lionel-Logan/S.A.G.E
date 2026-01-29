#!/usr/bin/env python3
"""
Speech-to-Text Service using Vosk
Converts recorded audio to text
"""

import json
import logging
import os
import wave
import tempfile
from typing import Optional
from pathlib import Path

try:
    from vosk import Model, KaldiRecognizer
except ImportError:
    Model = None
    KaldiRecognizer = None
    logging.warning("vosk not installed. Run: pip install vosk")

from config import voice_config as config

logger = logging.getLogger(__name__)


class STTService:
    """Handles speech-to-text conversion using Vosk"""
    
    def __init__(self):
        """Initialize Vosk model"""
        self.model = None
        self.sample_rate = config.SAMPLE_RATE
        self.recognizer = None
        
        if Model is None:
            raise RuntimeError("vosk not installed. Install with: pip install vosk")
        
        self._load_model()
        self._create_recognizer()
    
    def _load_model(self):
        """Load Vosk model from disk"""
        model_path = Path(config.VOSK_MODEL_PATH)
        
        if not model_path.exists():
            logger.error(f"Vosk model not found at {model_path}")
            logger.info(f"Download model from: {config.VOSK_MODEL_URL}")
            logger.info("Instructions:")
            logger.info("  1. Download and extract the model")
            logger.info("  2. Place it in the configured path")
            logger.info("  3. Restart the voice assistant")
            raise FileNotFoundError(
                f"Vosk model not found at {model_path}. "
                f"Download from {config.VOSK_MODEL_URL}"
            )
        
        try:
            logger.info(f"Loading Vosk model from {model_path}...")
            self.model = Model(str(model_path))
            logger.info("Vosk model loaded successfully")
        except Exception as e:
            logger.error(f"Failed to load Vosk model: {e}")
            raise
    
    def _create_recognizer(self):
        """Create a new recognizer instance"""
        if self.model:
            self.recognizer = KaldiRecognizer(self.model, self.sample_rate)
            self.recognizer.SetWords(True)
    
    def reset_recognizer(self):
        """Reset recognizer for a new transcription session"""
        self._create_recognizer()
    
    def process_audio_chunk(self, audio_chunk: bytes) -> tuple[Optional[str], bool]:
        """
        Process audio chunk for streaming transcription
        
        Args:
            audio_chunk: Raw audio data chunk (16-bit PCM)
            
        Returns:
            Tuple of (partial_text, is_final)
            - partial_text: Transcribed text so far (or None)
            - is_final: True if this is a complete utterance
        """
        if self.recognizer is None:
            logger.error("Recognizer not initialized")
            return None, False
        
        try:
            if self.recognizer.AcceptWaveform(audio_chunk):
                # Complete utterance detected
                result = json.loads(self.recognizer.Result())
                text = result.get('text', '').strip()
                return text, True
            else:
                # Partial result
                result = json.loads(self.recognizer.PartialResult())
                partial = result.get('partial', '').strip()
                return partial, False
                
        except Exception as e:
            logger.error(f"Error processing audio chunk: {e}")
            return None, False
    
    def get_final_result(self) -> Optional[str]:
        """Get final transcription result"""
        if self.recognizer is None:
            return None
        
        try:
            result = json.loads(self.recognizer.FinalResult())
            text = result.get('text', '').strip()
            return text if text else None
        except Exception as e:
            logger.error(f"Error getting final result: {e}")
            return None
    
    def transcribe_audio_bytes(self, audio_data: bytes) -> Optional[str]:
        """
        Transcribe audio from raw bytes
        
        Args:
            audio_data: Raw audio data (16-bit PCM)
            
        Returns:
            Transcribed text or None if failed
        """
        if self.model is None:
            logger.error("Vosk model not loaded")
            return None
        
        try:
            # Create recognizer
            recognizer = KaldiRecognizer(self.model, self.sample_rate)
            recognizer.SetWords(True)  # Enable word-level timestamps if needed
            
            # Process audio data
            if recognizer.AcceptWaveform(audio_data):
                result = json.loads(recognizer.Result())
            else:
                result = json.loads(recognizer.FinalResult())
            
            # Extract transcribed text
            text = result.get('text', '').strip()
            
            if text:
                logger.info(f"Transcribed: '{text}'")
                return text
            else:
                logger.warning("No speech detected in audio")
                return None
                
        except Exception as e:
            logger.error(f"Transcription error: {e}", exc_info=True)
            return None
    
    def transcribe_audio_file(self, audio_file: str) -> Optional[str]:
        """
        Transcribe audio from WAV file
        
        Args:
            audio_file: Path to WAV file
            
        Returns:
            Transcribed text or None if failed
        """
        if self.model is None:
            logger.error("Vosk model not loaded")
            return None
        
        if not os.path.exists(audio_file):
            logger.error(f"Audio file not found: {audio_file}")
            return None
        
        try:
            # Open WAV file
            with wave.open(audio_file, 'rb') as wf:
                # Verify audio format
                if wf.getnchannels() != 1:
                    logger.error(f"Audio must be mono, got {wf.getnchannels()} channels")
                    return None
                
                if wf.getsampwidth() != 2:
                    logger.error(f"Audio must be 16-bit, got {wf.getsampwidth()*8}-bit")
                    return None
                
                if wf.getframerate() != self.sample_rate:
                    logger.warning(
                        f"Audio sample rate {wf.getframerate()} Hz differs from "
                        f"configured {self.sample_rate} Hz"
                    )
                
                # Create recognizer
                recognizer = KaldiRecognizer(self.model, wf.getframerate())
                recognizer.SetWords(True)
                
                # Process audio in chunks
                while True:
                    data = wf.readframes(4000)
                    if len(data) == 0:
                        break
                    recognizer.AcceptWaveform(data)
                
                # Get final result
                result = json.loads(recognizer.FinalResult())
                text = result.get('text', '').strip()
                
                if text:
                    logger.info(f"Transcribed from file: '{text}'")
                    return text
                else:
                    logger.warning("No speech detected in audio file")
                    return None
                    
        except Exception as e:
            logger.error(f"Error transcribing file: {e}", exc_info=True)
            return None
    
    def test_transcription(self) -> bool:
        """
        Test if the STT service is working
        
        Returns:
            True if test passed
        """
        try:
            # Create a simple test recognizer
            recognizer = KaldiRecognizer(self.model, self.sample_rate)
            logger.info("STT service test passed")
            return True
        except Exception as e:
            logger.error(f"STT service test failed: {e}")
            return False


class STTServiceOffline(STTService):
    """
    Offline STT service variant
    Ensures all processing is done locally without internet
    """
    
    def __init__(self):
        """Initialize offline STT service"""
        super().__init__()
        logger.info("STTServiceOffline initialized - all processing is local")
    
    def transcribe_with_confidence(self, audio_data: bytes) -> tuple[Optional[str], float]:
        """
        Transcribe audio and return confidence score
        
        Args:
            audio_data: Raw audio data
            
        Returns:
            Tuple of (transcribed_text, confidence_score)
        """
        if self.model is None:
            return None, 0.0
        
        try:
            recognizer = KaldiRecognizer(self.model, self.sample_rate)
            recognizer.SetWords(True)
            
            if recognizer.AcceptWaveform(audio_data):
                result = json.loads(recognizer.Result())
            else:
                result = json.loads(recognizer.FinalResult())
            
            text = result.get('text', '').strip()
            
            # Calculate average confidence from word-level results
            words = result.get('result', [])
            if words:
                confidence = sum(word.get('conf', 0) for word in words) / len(words)
            else:
                confidence = 0.0
            
            return text, confidence
            
        except Exception as e:
            logger.error(f"Transcription error: {e}")
            return None, 0.0
