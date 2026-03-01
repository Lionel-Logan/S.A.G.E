#!/usr/bin/env python3
"""
Speech-to-Text Service using Google Cloud Speech-to-Text
Converts recorded audio to text via batch transcription
"""

import logging
import os
from typing import Optional

from config import voice_config as config

logger = logging.getLogger(__name__)

# Set credentials before importing the Google client library
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = config.GOOGLE_APPLICATION_CREDENTIALS

try:
    from google.cloud import speech as google_speech
except ImportError:
    google_speech = None
    logging.warning("google-cloud-speech not installed. Run: pip install google-cloud-speech")


class STTService:
    """Handles speech-to-text conversion using Google Cloud Speech-to-Text"""

    def __init__(self):
        """Initialize Google Cloud Speech client"""
        if google_speech is None:
            raise RuntimeError(
                "google-cloud-speech not installed. Install with: pip install google-cloud-speech"
            )

        self.sample_rate = config.SAMPLE_RATE
        self._audio_buffer: list[bytes] = []

        # Build the recognition config once; reuse for every request
        self._recognition_config = google_speech.RecognitionConfig(
            encoding=google_speech.RecognitionConfig.AudioEncoding.LINEAR16,
            sample_rate_hertz=self.sample_rate,
            language_code=config.GOOGLE_STT_LANGUAGE_CODE,
            model=config.GOOGLE_STT_MODEL,
            max_alternatives=config.GOOGLE_STT_MAX_ALTERNATIVES,
            audio_channel_count=1,
        )

        try:
            self.client = google_speech.SpeechClient()
            logger.info("Google Cloud Speech client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Google Cloud Speech client: {e}")
            raise

    # ------------------------------------------------------------------
    # Public API  (identical contract to the previous Vosk implementation)
    # ------------------------------------------------------------------

    def reset_recognizer(self):
        """Clear the audio buffer to start a fresh transcription session"""
        self._audio_buffer = []
        logger.debug("STT audio buffer cleared")

    def process_audio_chunk(self, audio_chunk: bytes) -> tuple[Optional[str], bool]:
        """
        Accumulate an audio chunk for batch transcription.

        The Google Cloud STT implementation buffers chunks locally and does
        NOT send a network request per chunk. Call get_final_result() after
        recording ends to trigger the single cloud request.

        Args:
            audio_chunk: Raw 16-bit PCM audio data chunk

        Returns:
            Always (None, False) — partials are not available in batch mode.
        """
        self._audio_buffer.append(audio_chunk)
        return None, False

    def get_final_result(self) -> Optional[str]:
        """
        Send all buffered audio to Google Cloud STT and return the transcript.

        Returns:
            Transcribed text, or None if nothing was recognised.
        """
        if not self._audio_buffer:
            logger.warning("STT buffer is empty — nothing to transcribe")
            return None

        audio_data = b"".join(self._audio_buffer)
        self._audio_buffer = []  # clear for next session
        return self._recognise(audio_data)

    def transcribe_audio_bytes(self, audio_data: bytes) -> Optional[str]:
        """
        Transcribe audio from raw bytes in a single call.

        Args:
            audio_data: Raw 16-bit PCM audio data

        Returns:
            Transcribed text or None if failed
        """
        if not audio_data:
            logger.error("Empty audio data provided")
            return None
        return self._recognise(audio_data)

    def transcribe_audio_file(self, audio_file: str) -> Optional[str]:
        """
        Transcribe audio from a WAV file.

        Args:
            audio_file: Path to a 16-bit mono PCM WAV file

        Returns:
            Transcribed text or None if failed
        """
        import wave

        if not os.path.exists(audio_file):
            logger.error(f"Audio file not found: {audio_file}")
            return None

        try:
            with wave.open(audio_file, "rb") as wf:
                if wf.getnchannels() != 1:
                    logger.error(
                        f"Audio must be mono, got {wf.getnchannels()} channels"
                    )
                    return None
                if wf.getsampwidth() != 2:
                    logger.error(
                        f"Audio must be 16-bit, got {wf.getsampwidth() * 8}-bit"
                    )
                    return None
                actual_rate = wf.getframerate()
                if actual_rate != self.sample_rate:
                    logger.warning(
                        f"Audio sample rate {actual_rate} Hz differs from "
                        f"configured {self.sample_rate} Hz"
                    )
                audio_data = wf.readframes(wf.getnframes())

            # Use the actual file sample rate in case it differs
            cfg = google_speech.RecognitionConfig(
                encoding=google_speech.RecognitionConfig.AudioEncoding.LINEAR16,
                sample_rate_hertz=actual_rate,
                language_code=config.GOOGLE_STT_LANGUAGE_CODE,
                model=config.GOOGLE_STT_MODEL,
                max_alternatives=config.GOOGLE_STT_MAX_ALTERNATIVES,
                audio_channel_count=1,
            )
            return self._recognise(audio_data, recognition_config=cfg)

        except Exception as e:
            logger.error(f"Error transcribing file: {e}", exc_info=True)
            return None

    def test_transcription(self) -> bool:
        """
        Verify the STT service is reachable.

        Returns:
            True if the client was instantiated successfully.
        """
        try:
            assert self.client is not None
            logger.info("STT service test passed")
            return True
        except Exception as e:
            logger.error(f"STT service test failed: {e}")
            return False

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _recognise(
        self,
        audio_data: bytes,
        recognition_config=None,
    ) -> Optional[str]:
        """
        Send audio bytes to Google Cloud STT and return the top transcript.

        Args:
            audio_data: Raw 16-bit PCM audio bytes
            recognition_config: Override RecognitionConfig (uses default if None)

        Returns:
            Transcribed text or None
        """
        try:
            audio = google_speech.RecognitionAudio(content=audio_data)
            cfg = recognition_config or self._recognition_config

            logger.debug(
                f"Sending {len(audio_data)} bytes to Google Cloud STT "
                f"(language={config.GOOGLE_STT_LANGUAGE_CODE}, "
                f"model={config.GOOGLE_STT_MODEL})"
            )

            response = self.client.recognize(config=cfg, audio=audio)

            if not response.results:
                logger.warning("Google Cloud STT returned no results")
                return None

            transcript = response.results[0].alternatives[0].transcript.strip()

            if transcript:
                logger.info(f"Transcribed: '{transcript}'")
                return transcript
            else:
                logger.warning("Google Cloud STT returned an empty transcript")
                return None

        except Exception as e:
            logger.error(f"Google Cloud STT error: {e}", exc_info=True)
            return None
