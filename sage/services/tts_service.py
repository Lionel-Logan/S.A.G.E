#!/usr/bin/env python3
"""
Text-to-Speech Service using pyttsx3
Converts text to speech with configurable voice settings
"""

import logging
import threading
import time
import os
import subprocess
from pathlib import Path
from typing import Optional, List, Dict, Any

# Force espeak to use PulseAudio/PipeWire for Bluetooth audio
os.environ['AUDIODEV'] = 'pulse'
os.environ['ALSA_CARD'] = 'default'

try:
    import pyttsx3
    # Monkey patch the espeak driver to fix bad default voice
    try:
        import pyttsx3.drivers.espeak as espeak_driver
        original_init = espeak_driver.EspeakDriver.__init__
        
        def patched_init(self, proxy):
            """Patched init to avoid bad default voice"""
            # Call original with try/except
            try:
                original_init(self, proxy)
            except ValueError as e:
                if "SetVoiceByName" in str(e):
                    # Bad default voice, initialize without setting it
                    logging.warning(f"Caught espeak bad voice error, using fallback initialization")
                    self._proxy = proxy
                    import espeak
                    self._espeak = espeak
                    self._espeak.Initialize(espeak.AUDIO_OUTPUT_PLAYBACK, 100)
                    self._proxy.setBusy(True)
                    self._proxy.setBusy(False)
                    self._proxy.notify('started-utterance', name='espeak')
                    self._proxy.notify('finished-utterance', completed=True)
                    # Set a working voice manually
                    try:
                        self._espeak.SetVoiceByName('en'.encode())
                    except:
                        pass
                else:
                    raise
        
        espeak_driver.EspeakDriver.__init__ = patched_init
        logging.info("Applied espeak driver patch")
    except Exception as e:
        logging.warning(f"Could not apply espeak patch: {e}")
except ImportError:
    pyttsx3 = None
    logging.warning("pyttsx3 not installed. Run: pip install pyttsx3")

from config import tts_config

logger = logging.getLogger(__name__)


class TTSService:
    """Handles text-to-speech conversion and playback"""
    
    def __init__(self):
        """Initialize pyttsx3 TTS engine"""
        if pyttsx3 is None:
            raise RuntimeError("pyttsx3 not installed. Install with: pip install pyttsx3")
        
        self.engine = None
        self.config = tts_config.tts_runtime_config
        self.is_speaking = False
        self.stop_requested = False
        self._lock = threading.Lock()
        self._speech_thread = None
        
        # Initialize engine
        self._initialize_engine()
        
        logger.info("TTSService initialized successfully")
    
    def _initialize_engine(self):
        """Initialize or reinitialize the TTS engine"""
        try:
            # Clean up old engine if it exists
            if self.engine is not None:
                try:
                    self.engine.stop()
                except:
                    pass
                self.engine = None
            
            # Create engine - try multiple times with different configurations
            init_attempts = [
                lambda: pyttsx3.init('espeak', debug=False),  # Try espeak explicitly
                lambda: pyttsx3.init(debug=False),  # Try default
            ]
            
            last_error = None
            for attempt_func in init_attempts:
                try:
                    self.engine = attempt_func()
                    if self.engine:
                        break
                except Exception as e:
                    last_error = e
                    logger.warning(f"Engine init attempt failed: {e}")
                    continue
            
            if not self.engine:
                raise RuntimeError(f"All TTS engine initialization attempts failed. Last error: {last_error}")
            
            # Successfully initialized, now configure it
            # Get and set first available voice to override any bad defaults
            try:
                voices = self.engine.getProperty('voices')
                if voices and len(voices) > 0:
                    # Try to find an English voice, fallback to first
                    english_voice = None
                    for voice in voices:
                        voice_id = str(voice.id)
                        if 'en' in voice_id or 'english' in voice_id.lower():
                            english_voice = voice
                            break
                    
                    if english_voice:
                        self.engine.setProperty('voice', english_voice.id)
                        logger.info(f"Set default voice: {english_voice.name} (ID: {english_voice.id})")
                    else:
                        self.engine.setProperty('voice', voices[0].id)
                        logger.info(f"Set default voice: {voices[0].name}")
                else:
                    logger.warning("No voices found, using engine defaults")
            except Exception as voice_err:
                logger.warning(f"Could not set default voice: {voice_err}")
            
            # Apply current configuration
            self._apply_config()
            
            logger.info("TTS engine initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize TTS engine: {e}", exc_info=True)
            raise
    
    def _apply_config(self):
        """Apply current configuration to the TTS engine"""
        if self.engine is None:
            return
        
        try:
            # Set voice speed (words per minute)
            self.engine.setProperty('rate', self.config.voice_speed)
            
            # Set volume (0.0 to 1.0)
            self.engine.setProperty('volume', self.config.voice_volume)
            
            # Set voice (if voice_id is specified, use it; otherwise auto-select by gender)
            if self.config.voice_id:
                self.engine.setProperty('voice', self.config.voice_id)
                logger.info(f"Set voice to ID: {self.config.voice_id}")
            else:
                # Auto-select voice based on gender preference
                self._auto_select_voice_by_gender()
            
            logger.info(f"Applied TTS config: speed={self.config.voice_speed}, "
                       f"volume={self.config.voice_volume}, gender={self.config.voice_gender}")
            
        except Exception as e:
            logger.error(f"Failed to apply TTS config: {e}", exc_info=True)
    
    def _auto_select_voice_by_gender(self):
        """Auto-select voice based on configured gender preference"""
        voices = self.get_available_voices()
        
        if not voices:
            logger.warning("No voices available for auto-selection")
            return
        
        # Get language preference
        lang = self.config.voice_language
        if '-' in lang:
            lang = lang.split('-')[0]  # Convert en-US to en
        
        # Try to find a voice matching the gender preference
        gender_preference = self.config.voice_gender.lower()
        
        # For espeak, use voice variants for gender
        # Male: base voice (e.g., "en")
        # Female: base voice + "+f1", "+f2", "+f3" etc
        
        # Find English voice (or language-matching voice)
        base_voice_id = None
        for voice in voices:
            voice_id = voice.get('id')
            if lang in str(voice_id).lower() or 'english' in voice.get('name', '').lower():
                base_voice_id = voice_id
                break
        
        if not base_voice_id and voices:
            # Fallback to first voice if no language match
            base_voice_id = voices[0].get('id')
        
        if base_voice_id:
            if gender_preference == 'female':
                # Use espeak female variant
                female_voice_id = f"{base_voice_id}+f1"
                self.engine.setProperty('voice', female_voice_id)
                logger.info(f"Auto-selected female voice variant: {female_voice_id}")
            else:
                # Use base voice for male
                self.engine.setProperty('voice', base_voice_id)
                logger.info(f"Auto-selected male voice: {base_voice_id}")
    
    def get_available_voices(self) -> List[Dict[str, Any]]:
        """
        Get list of all available system voices including espeak variants
        
        Returns:
            List of voice dictionaries with id, name, languages, gender, description
        """
        if self.engine is None:
            return []
        
        try:
            voices = self.engine.getProperty('voices')
            voice_list = []
            
            # Add base voices
            for voice in voices:
                voice_info = {
                    'id': voice.id,
                    'name': voice.name,
                    'languages': voice.languages if hasattr(voice, 'languages') else [],
                    'gender': voice.gender if hasattr(voice, 'gender') else 'Male',
                    'description': f"{voice.name} (default)"
                }
                voice_list.append(voice_info)
            
            # Add espeak voice variants for English voices
            english_voices = [v for v in voices if 'en' in str(v.id).lower()]
            for base_voice in english_voices[:5]:  # Limit to first 5 English voices to avoid clutter
                base_id = base_voice.id
                base_name = base_voice.name
                
                # Male variants
                for i in range(1, 8):
                    voice_list.append({
                        'id': f"{base_id}+m{i}",
                        'name': f"{base_name}",
                        'languages': base_voice.languages if hasattr(base_voice, 'languages') else [],
                        'gender': 'Male',
                        'description': f"Male variant {i}"
                    })
                
                # Female variants
                for i in range(1, 5):
                    voice_list.append({
                        'id': f"{base_id}+f{i}",
                        'name': f"{base_name}",
                        'languages': base_voice.languages if hasattr(base_voice, 'languages') else [],
                        'gender': 'Female',
                        'description': f"Female variant {i}"
                    })
                
                # Other variants
                for variant, desc in [('whisper', 'Whisper'), ('croak', 'Croaky')]:
                    voice_list.append({
                        'id': f"{base_id}+{variant}",
                        'name': f"{base_name}",
                        'languages': base_voice.languages if hasattr(base_voice, 'languages') else [],
                        'gender': 'Neutral',
                        'description': desc
                    })
            
            logger.info(f"Found {len(voice_list)} available voices (including variants)")
            return voice_list
            
        except Exception as e:
            logger.error(f"Failed to get available voices: {e}", exc_info=True)
            return []
    
    def speak(self, text: str, blocking: bool = True) -> bool:
        """
        Convert text to speech and play it
        
        Args:
            text: Text to speak
            blocking: If True, wait for speech to finish; if False, speak in background
            
        Returns:
            True if speech started successfully, False otherwise
        """
        if not text or not text.strip():
            logger.warning("Empty text provided to speak()")
            return False
        
        if blocking:
            return self._speak_blocking(text)
        else:
            return self._speak_async(text)
    
    def _speak_blocking(self, text: str) -> bool:
        """Speak text synchronously (blocking)"""
        from utils.audio_manager import AudioManager
        
        logger.info(f"[TTS] _speak_blocking called with text: '{text[:50]}'")
        
        # Acquire audio lock for TTS
        if not AudioManager.acquire_for_tts(timeout=5.0):
            logger.warning("Could not acquire audio lock for TTS")
            return False
        
        logger.info("[TTS] Audio lock acquired")
        
        try:
            with self._lock:
                if self.is_speaking:
                    logger.warning("TTS is already speaking, stopping previous speech")
                    self.stop()
                
                self.is_speaking = True
                self.stop_requested = False
                
                # Reinitialize engine to pick up current audio output device
                # This ensures TTS uses the currently connected Bluetooth device
                logger.info("[TTS] Reinitializing engine to use current audio output device")
                try:
                    self._initialize_engine()
                except Exception as e:
                    logger.warning(f"[TTS] Engine reinitialization failed: {e}, continuing with existing engine")
                
                # Log current voice settings
                try:
                    current_voice = self.engine.getProperty('voice')
                    current_rate = self.engine.getProperty('rate')
                    logger.info(f"[TTS] Current voice: {current_voice}, rate: {current_rate}")
                except Exception as e:
                    logger.warning(f"[TTS] Could not get voice properties: {e}")
                
                logger.info(f"[TTS] Calling engine.say() and runAndWait()...")
                
                # Use espeak piped through aplay since aplay works correctly
                # This ensures audio goes to the current default output (Bluetooth)
                try:
                    # Get current configuration
                    voice_id = self.config.voice_id or 'en'
                    rate = self.config.voice_speed
                    volume = int(self.config.voice_volume * 100)  # espeak uses 0-100
                    
                    print(f"[TTS] Using espeak -> aplay pipeline for audio output")
                    print(f"[TTS] Voice: {voice_id}, Rate: {rate}, Volume: {volume}")
                    print(f"[TTS] Text to speak: '{text}'")
                    
                    # First, test if aplay is available and working
                    test_result = subprocess.run(['which', 'aplay'], capture_output=True)
                    print(f"[TTS] aplay location: {test_result.stdout.decode().strip()}")
                    
                    # Generate audio with espeak and pipe to aplay
                    espeak_cmd = [
                        'espeak',
                        '-v', voice_id,
                        '-s', str(rate),
                        '-a', str(volume),
                        '--stdout',  # Output WAV to stdout
                        text
                    ]
                    
                    aplay_cmd = ['aplay']  # Use default device (works manually)
                    
                    print(f"[TTS] Running: {' '.join(espeak_cmd)} | {' '.join(aplay_cmd)}")
                    
                    # Create subprocess pipeline: espeak | aplay
                    # Use the sage user's environment for PulseAudio access
                    env = os.environ.copy()
                    # Set runtime directory for PulseAudio socket access
                    if 'XDG_RUNTIME_DIR' not in env:
                        # Assume sage user UID 1000
                        env['XDG_RUNTIME_DIR'] = '/run/user/1000'
                    if 'PULSE_SERVER' not in env:
                        env['PULSE_SERVER'] = f"unix:{env['XDG_RUNTIME_DIR']}/pulse/native"
                    
                    print(f"[TTS] Using XDG_RUNTIME_DIR: {env.get('XDG_RUNTIME_DIR')}")
                    print(f"[TTS] Using PULSE_SERVER: {env.get('PULSE_SERVER')}")
                    
                    espeak_proc = subprocess.Popen(
                        espeak_cmd,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        env=env
                    )
                    
                    aplay_proc = subprocess.Popen(
                        aplay_cmd,
                        stdin=espeak_proc.stdout,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        env=env
                    )
                    
                    # Allow espeak_proc to receive SIGPIPE if aplay_proc exits
                    if espeak_proc.stdout:
                        espeak_proc.stdout.close()
                    
                    print("[TTS] Pipeline started, waiting for completion...")
                    
                    # Wait for completion
                    aplay_stdout, aplay_stderr = aplay_proc.communicate(timeout=30)
                    espeak_stderr = espeak_proc.stderr.read() if espeak_proc.stderr else b''
                    espeak_proc.wait()
                    
                    print(f"[TTS] espeak exit code: {espeak_proc.returncode}")
                    print(f"[TTS] aplay exit code: {aplay_proc.returncode}")
                    
                    if espeak_stderr:
                        print(f"[TTS] espeak stderr: {espeak_stderr.decode()}")
                    if aplay_stderr:
                        print(f"[TTS] aplay stderr: {aplay_stderr.decode()}")
                    if aplay_stdout:
                        print(f"[TTS] aplay stdout: {aplay_stdout.decode()}")
                    
                    if aplay_proc.returncode != 0:
                        print(f"[TTS] aplay failed with code {aplay_proc.returncode}")
                        raise Exception(f"aplay returned {aplay_proc.returncode}")
                    
                    if espeak_proc.returncode != 0:
                        print(f"[TTS] espeak failed with code {espeak_proc.returncode}")
                        raise Exception(f"espeak returned {espeak_proc.returncode}")
                    
                    print(f"[TTS] Speech completed successfully via espeak->aplay pipeline")
                    
                except Exception as pipeline_error:
                    print(f"[TTS] espeak->aplay pipeline failed: {pipeline_error}")
                    print(f"[TTS] Falling back to pyttsx3")
                    # Fallback to pyttsx3
                    self.engine.say(text)
                    self.engine.runAndWait()
                    print(f"[TTS] Speech completed via pyttsx3 fallback")
                
                self.is_speaking = False
                logger.info("Speech completed")
                return True
                
        except Exception as e:
            logger.error(f"TTS error: {e}", exc_info=True)
            self.is_speaking = False
            return False
        finally:
            # Release audio lock
            AudioManager.release_from_tts()
    
    def _speak_async(self, text: str) -> bool:
        """Speak text asynchronously (non-blocking)"""
        from utils.audio_manager import AudioManager
        
        if self.is_speaking:
            logger.warning("TTS is already speaking, stopping previous speech")
            self.stop()
        
        def _speech_worker():
            # Acquire audio lock for TTS
            if not AudioManager.acquire_for_tts(timeout=5.0):
                logger.warning("Could not acquire audio lock for async TTS")
                return
            
            try:
                with self._lock:
                    self.is_speaking = True
                    self.stop_requested = False
                    
                    logger.info(f"Speaking (async): '{text[:50]}{'...' if len(text) > 50 else ''}'")
                    
                    self.engine.say(text)
                    self.engine.runAndWait()
                    
                    self.is_speaking = False
                    logger.info("Async speech completed")
                    
            except Exception as e:
                logger.error(f"Async TTS error: {e}", exc_info=True)
                self.is_speaking = False
            finally:
                # Release audio lock
                AudioManager.release_from_tts()
        
        try:
            self._speech_thread = threading.Thread(target=_speech_worker, daemon=True)
            self._speech_thread.start()
            return True
        except Exception as e:
            logger.error(f"Failed to start async speech thread: {e}", exc_info=True)
            return False
    
    def stop(self) -> bool:
        """
        Stop current speech immediately
        
        Returns:
            True if stopped successfully
        """
        if not self.is_speaking:
            logger.debug("TTS not currently speaking, nothing to stop")
            return True
        
        try:
            logger.info("Stopping TTS speech")
            self.stop_requested = True
            
            # Stop the engine
            if self.engine:
                self.engine.stop()
            
            # Wait for speech thread to finish (with timeout)
            if self._speech_thread and self._speech_thread.is_alive():
                self._speech_thread.join(timeout=1.0)
            
            self.is_speaking = False
            logger.info("TTS speech stopped")
            return True
            
        except Exception as e:
            logger.error(f"Error stopping TTS: {e}", exc_info=True)
            self.is_speaking = False
            return False
    
    def save_audio(self, text: str, output_file: str) -> bool:
        """
        Save text-to-speech audio to file
        
        Args:
            text: Text to convert
            output_file: Path to output audio file
            
        Returns:
            True if saved successfully
        """
        try:
            logger.info(f"Saving TTS audio to {output_file}")
            
            # Ensure output directory exists
            Path(output_file).parent.mkdir(parents=True, exist_ok=True)
            
            # Save to file
            self.engine.save_to_file(text, output_file)
            self.engine.runAndWait()
            
            logger.info(f"TTS audio saved to {output_file}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to save TTS audio: {e}", exc_info=True)
            return False
    
    def update_config(self, settings: Dict[str, Any]) -> Dict[str, Any]:
        """
        Update TTS configuration and apply changes
        
        Args:
            settings: Dictionary with new settings
            
        Returns:
            Updated configuration
        """
        try:
            # Update configuration
            updated_config = self.config.update(settings)
            
            # Apply new settings to engine
            self._apply_config()
            
            logger.info("TTS configuration updated successfully")
            return updated_config
            
        except Exception as e:
            logger.error(f"Failed to update TTS config: {e}", exc_info=True)
            raise
    
    def get_config(self) -> Dict[str, Any]:
        """
        Get current TTS configuration
        
        Returns:
            Current configuration as dictionary
        """
        return self.config.to_dict()
    
    def get_status(self) -> Dict[str, Any]:
        """
        Get current TTS service status
        
        Returns:
            Status dictionary
        """
        return {
            'is_speaking': self.is_speaking,
            'engine': tts_config.TTS_ENGINE,
            'config': self.get_config(),
            'available_voices_count': len(self.get_available_voices())
        }
    
    def test_speech(self, text: Optional[str] = None) -> bool:
        """
        Test TTS with current settings
        
        Args:
            text: Text to speak (default: test message)
            
        Returns:
            True if test successful
        """
        test_text = text or "Hello, this is a test of the text to speech system."
        logger.info("Running TTS test")
        return self.speak(test_text, blocking=True)
    
    def cleanup(self):
        """Cleanup resources"""
        try:
            if self.is_speaking:
                self.stop()
            
            if self.engine:
                self.engine.stop()
                # Note: pyttsx3 doesn't have an explicit cleanup method
                self.engine = None
            
            logger.info("TTS service cleaned up")
            
        except Exception as e:
            logger.error(f"Error during TTS cleanup: {e}", exc_info=True)
    
    def __del__(self):
        """Destructor"""
        self.cleanup()
