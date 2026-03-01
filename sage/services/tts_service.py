#!/usr/bin/env python3
"""
Text-to-Speech Service using Google Cloud Text-to-Speech
Synthesises speech via Google Cloud TTS and plays it through aplay
(preserving the existing Bluetooth/PulseAudio routing)
"""

import hashlib
import json
import logging
import os
import subprocess
import tempfile
import threading
import time
import uuid
from pathlib import Path
from typing import Optional, List, Dict, Any

from config import tts_config

# Set credentials before importing the Google client library
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = tts_config.GOOGLE_APPLICATION_CREDENTIALS

try:
    from google.cloud import texttospeech as google_tts
except ImportError:
    google_tts = None
    logging.warning("google-cloud-texttospeech not installed. Run: pip install google-cloud-texttospeech")

logger = logging.getLogger(__name__)


class TTSService:
    """Handles text-to-speech conversion using Google Cloud Text-to-Speech"""

    def __init__(self):
        """Initialize Google Cloud TTS client"""
        if google_tts is None:
            raise RuntimeError(
                "google-cloud-texttospeech not installed. "
                "Install with: pip install google-cloud-texttospeech"
            )

        self.config = tts_config.tts_runtime_config
        self.is_speaking = False
        self.stop_requested = False
        self._lock = threading.Lock()
        self._speech_thread: Optional[threading.Thread] = None
        self._aplay_proc: Optional[subprocess.Popen] = None  # for stop()

        try:
            self.client = google_tts.TextToSpeechClient()
            logger.info("Google Cloud TTS client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Google Cloud TTS client: {e}")
            raise

        # Set up audio cache
        self._cache_dir = Path(tts_config.TTS_CACHE_DIR)
        self._cache_enabled = tts_config.ENABLE_TTS_CACHE
        if self._cache_enabled:
            self._cache_dir.mkdir(parents=True, exist_ok=True)
            logger.info(f"TTS cache enabled at {self._cache_dir}")

        # Pre-warm common phrases in background so first use is instant
        prewarm = getattr(tts_config, 'TTS_PREWARM_PHRASES', [])
        if self._cache_enabled and prewarm:
            threading.Thread(target=self._prewarm, args=(prewarm,), daemon=True).start()

        logger.info("TTSService initialized successfully")

    # ------------------------------------------------------------------
    # Public API (same contract as the previous pyttsx3 implementation)
    # ------------------------------------------------------------------

    def speak(self, text: str, blocking: bool = True) -> bool:
        """
        Convert text to speech and play through the audio output.

        Args:
            text: Text to speak
            blocking: Wait for speech to finish if True; return immediately if False

        Returns:
            True if speech started (or completed) successfully
        """
        if not text or not text.strip():
            logger.warning("Empty text provided to speak()")
            return False

        if blocking:
            return self._speak_blocking(text)
        else:
            return self._speak_async(text)

    def stop(self) -> bool:
        """
        Stop current speech immediately.

        Returns:
            True if stopped successfully
        """
        if not self.is_speaking:
            logger.debug("TTS not currently speaking, nothing to stop")
            return True

        try:
            logger.info("Stopping TTS speech")
            self.stop_requested = True

            # Kill the aplay subprocess if it is running
            if self._aplay_proc and self._aplay_proc.poll() is None:
                self._aplay_proc.terminate()
                try:
                    self._aplay_proc.wait(timeout=2.0)
                except subprocess.TimeoutExpired:
                    self._aplay_proc.kill()

            # Wait for the speech thread to exit
            if self._speech_thread and self._speech_thread.is_alive():
                self._speech_thread.join(timeout=2.0)

            self.is_speaking = False
            logger.info("TTS speech stopped")
            return True

        except Exception as e:
            logger.error(f"Error stopping TTS: {e}", exc_info=True)
            self.is_speaking = False
            return False

    def get_available_voices(self) -> List[Dict[str, Any]]:
        """
        Get list of available Google Cloud TTS voices for the configured language.

        Returns:
            List of voice dicts with id, name, languages, gender, description
        """
        try:
            response = self.client.list_voices(
                language_code=self.config.voice_language
            )
            voice_list = []
            for voice in response.voices:
                gender_map = {
                    google_tts.SsmlVoiceGender.MALE: "Male",
                    google_tts.SsmlVoiceGender.FEMALE: "Female",
                    google_tts.SsmlVoiceGender.NEUTRAL: "Neutral",
                }
                voice_list.append({
                    "id": voice.name,
                    "name": voice.name,
                    "languages": list(voice.language_codes),
                    "gender": gender_map.get(voice.ssml_gender, "Unknown"),
                    "description": (
                        f"{voice.name} â€” "
                        f"{', '.join(voice.language_codes)}"
                    ),
                })
            logger.info(
                f"Found {len(voice_list)} voices for "
                f"language={self.config.voice_language}"
            )
            return voice_list
        except Exception as e:
            logger.error(f"Failed to get available voices: {e}", exc_info=True)
            return []

    def save_audio(self, text: str, output_file: str) -> bool:
        """
        Synthesise text and save the audio to a file (no playback).

        Args:
            text: Text to convert
            output_file: Destination file path

        Returns:
            True if saved successfully
        """
        try:
            logger.info(f"Saving TTS audio to {output_file}")
            audio_content = self._synthesise(text)
            if audio_content is None:
                return False
            Path(output_file).parent.mkdir(parents=True, exist_ok=True)
            with open(output_file, "wb") as f:
                f.write(audio_content)
            logger.info(f"TTS audio saved to {output_file}")
            return True
        except Exception as e:
            logger.error(f"Failed to save TTS audio: {e}", exc_info=True)
            return False

    def update_config(self, settings: Dict[str, Any]) -> Dict[str, Any]:
        """
        Update TTS configuration.

        Args:
            settings: Dict of new settings (voice_speed, voice_volume, etc.)

        Returns:
            Updated configuration dict
        """
        try:
            updated_config = self.config.update(settings)
            logger.info("TTS configuration updated successfully")
            return updated_config
        except Exception as e:
            logger.error(f"Failed to update TTS config: {e}", exc_info=True)
            raise

    def get_config(self) -> Dict[str, Any]:
        """Get current TTS configuration as a dictionary"""
        return self.config.to_dict()

    def get_status(self) -> Dict[str, Any]:
        """Get current TTS service status"""
        return {
            "is_speaking": self.is_speaking,
            "engine": tts_config.TTS_ENGINE,
            "config": self.get_config(),
            "available_voices_count": len(self.get_available_voices()),
        }

    def test_speech(self, text: Optional[str] = None) -> bool:
        """
        Test TTS with current settings.

        Args:
            text: Text to speak (default: standard test message)

        Returns:
            True if test successful
        """
        test_text = text or "Hello, this is a test of the text to speech system."
        logger.info("Running TTS test")
        return self.speak(test_text, blocking=True)

    def cleanup(self):
        """Release resources"""
        try:
            if self.is_speaking:
                self.stop()
            logger.info("TTS service cleaned up")
        except Exception as e:
            logger.error(f"Error during TTS cleanup: {e}", exc_info=True)

    def __del__(self):
        """Destructor"""
        self.cleanup()

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _speak_blocking(self, text: str) -> bool:
        """Synthesise and play text synchronously (blocking)"""
        from utils.audio_manager import AudioManager

        logger.info(f"[TTS] Speaking text: '{text}'")

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

                # 1. Synthesise audio via Google Cloud TTS (or load from cache)
                t0 = time.monotonic()
                audio_content = self._get_cached_audio(text)
                if audio_content is not None:
                    logger.info(f"[TTS] Cache hit for '{text[:60]}' ({len(audio_content)} bytes)")
                else:
                    audio_content = self._synthesise(text)
                    if audio_content is None:
                        self.is_speaking = False
                        return False
                    self._cache_audio(text, audio_content)
                    logger.info(f"[TTS] Synthesised in {time.monotonic()-t0:.2f}s ({len(audio_content)} bytes)")

                # 2. Write to a temporary WAV file
                tmp_path = f"/tmp/sage_tts_{uuid.uuid4().hex}.wav"
                with open(tmp_path, "wb") as f:
                    f.write(audio_content)

                # 3. Play with aplay (preserves existing Bluetooth/PulseAudio routing)
                env = os.environ.copy()
                if "XDG_RUNTIME_DIR" not in env:
                    env["XDG_RUNTIME_DIR"] = "/run/user/1000"
                if "PULSE_SERVER" not in env:
                    env["PULSE_SERVER"] = (
                        f"unix:{env['XDG_RUNTIME_DIR']}/pulse/native"
                    )

                logger.debug(
                    f"[TTS] Playing {tmp_path} via aplay "
                    f"(XDG_RUNTIME_DIR={env.get('XDG_RUNTIME_DIR')})"
                )

                self._aplay_proc = subprocess.Popen(
                    ["aplay", tmp_path],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    env=env,
                )

                stdout, stderr = self._aplay_proc.communicate(timeout=60)

                if stderr:
                    logger.debug(f"[TTS] aplay stderr: {stderr.decode().strip()}")

                if self._aplay_proc.returncode != 0 and not self.stop_requested:
                    logger.error(
                        f"[TTS] aplay exited with code {self._aplay_proc.returncode}"
                    )

                # 4. Clean up temp file
                try:
                    os.remove(tmp_path)
                except OSError:
                    pass

                self._aplay_proc = None
                self.is_speaking = False
                logger.info("[TTS] Speech completed successfully")
                return True

        except Exception as e:
            logger.error(f"TTS error: {e}", exc_info=True)
            self.is_speaking = False
            return False
        finally:
            AudioManager.release_from_tts()

    def _speak_async(self, text: str) -> bool:
        """Synthesise and play text asynchronously (non-blocking)"""
        if self.is_speaking:
            logger.warning("TTS is already speaking, stopping previous speech")
            self.stop()

        def _worker():
            self._speak_blocking(text)

        try:
            self._speech_thread = threading.Thread(target=_worker, daemon=True)
            self._speech_thread.start()
            return True
        except Exception as e:
            logger.error(f"Failed to start async speech thread: {e}", exc_info=True)
            return False

    def _synthesise(self, text: str) -> Optional[bytes]:
        """
        Call Google Cloud TTS and return raw LINEAR16 WAV audio bytes.

        Args:
            text: Text to synthesise

        Returns:
            Audio bytes (LINEAR16 WAV) or None on failure
        """
        try:
            # Map config fields to Google TTS API parameters
            speaking_rate = self.config.voice_speed / 175.0  # 175 WPM â†’ 1.0
            speaking_rate = max(0.25, min(4.0, speaking_rate))  # clamp to API range

            # volume_gain_db: config 0.0â€“1.0 â†’ -6 dB to 0 dB
            volume_gain_db = (self.config.voice_volume - 1.0) * 6.0
            volume_gain_db = max(-96.0, min(16.0, volume_gain_db))

            # Determine voice name: explicitly set voice_id takes priority
            voice_name = self.config.voice_id or tts_config.GOOGLE_TTS_VOICE_NAME

            # Gender hint (used if Google chooses a voice automatically)
            gender_map = {
                "female": google_tts.SsmlVoiceGender.FEMALE,
                "male": google_tts.SsmlVoiceGender.MALE,
                "neutral": google_tts.SsmlVoiceGender.NEUTRAL,
            }
            ssml_gender = gender_map.get(
                self.config.voice_gender.lower(),
                google_tts.SsmlVoiceGender.FEMALE,
            )

            synthesis_input = google_tts.SynthesisInput(text=text)
            voice_params = google_tts.VoiceSelectionParams(
                language_code=self.config.voice_language,
                name=voice_name,
                ssml_gender=ssml_gender,
            )
            audio_config = google_tts.AudioConfig(
                audio_encoding=google_tts.AudioEncoding.LINEAR16,
                speaking_rate=speaking_rate,
                volume_gain_db=volume_gain_db,
            )

            logger.debug(
                f"[TTS] Synthesising: voice={voice_name}, "
                f"rate={speaking_rate:.2f}, volume_db={volume_gain_db:.1f}"
            )

            response = self.client.synthesize_speech(
                input=synthesis_input,
                voice=voice_params,
                audio_config=audio_config,
            )

            return response.audio_content

        except Exception as e:
            logger.error(f"Google Cloud TTS synthesis error: {e}", exc_info=True)
            return None

    # ------------------------------------------------------------------
    # Cache helpers
    # ------------------------------------------------------------------

    def _cache_key(self, text: str) -> str:
        """Return a stable filename-safe cache key for the given text + voice settings."""
        voice = self.config.voice_id or tts_config.GOOGLE_TTS_VOICE_NAME
        rate = round(self.config.voice_speed / 175.0, 2)
        vol = round((self.config.voice_volume - 1.0) * 6.0, 1)
        payload = f"{text}|{voice}|{rate}|{vol}"
        return hashlib.md5(payload.encode()).hexdigest()

    def _get_cached_audio(self, text: str) -> Optional[bytes]:
        """Return cached WAV bytes for text, or None if not cached."""
        if not self._cache_enabled:
            return None
        cache_file = self._cache_dir / f"{self._cache_key(text)}.wav"
        if cache_file.exists():
            try:
                return cache_file.read_bytes()
            except OSError:
                pass
        return None

    def _cache_audio(self, text: str, audio_bytes: bytes) -> None:
        """Save synthesised audio to cache. Evicts oldest entries if over limit."""
        if not self._cache_enabled or not audio_bytes:
            return
        try:
            # Evict oldest entries if at limit
            max_entries = getattr(tts_config, 'TTS_CACHE_MAX_ENTRIES', 200)
            existing = sorted(self._cache_dir.glob("*.wav"), key=lambda p: p.stat().st_mtime)
            while len(existing) >= max_entries:
                existing.pop(0).unlink(missing_ok=True)
            cache_file = self._cache_dir / f"{self._cache_key(text)}.wav"
            cache_file.write_bytes(audio_bytes)
        except OSError as e:
            logger.warning(f"[TTS] Could not write cache: {e}")

    def _prewarm(self, phrases: list) -> None:
        """Synthesise a list of phrases at startup and store in cache."""
        logger.info(f"[TTS] Pre-warming {len(phrases)} phrases...")
        warmed = 0
        for phrase in phrases:
            try:
                if self._get_cached_audio(phrase) is None:
                    audio = self._synthesise(phrase)
                    if audio:
                        self._cache_audio(phrase, audio)
                        warmed += 1
                        logger.debug(f"[TTS] Pre-warmed: '{phrase[:60]}'")
            except Exception as e:
                logger.warning(f"[TTS] Pre-warm failed for '{phrase[:40]}': {e}")
        logger.info(f"[TTS] Pre-warm complete: {warmed} new phrase(s) cached")