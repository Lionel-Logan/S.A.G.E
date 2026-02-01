#!/usr/bin/env python3
"""
SAGE Voice Assistant - Main Service
Coordinates wake word detection, audio recording, STT, and backend communication
"""

import logging
import sys
import signal
import json
import threading
import time
import requests
from datetime import datetime
from pathlib import Path
from flask import Flask, jsonify, request as flask_request
from werkzeug.serving import make_server

# Import configuration
from config import voice_config as config

# Import services
from services.wake_word_service import WakeWordService
from services.stt_service import STTService
from utils.audio_manager import AudioManager

# Configure logging
logging.basicConfig(
    level=getattr(logging, config.LOG_LEVEL),
    format=config.LOG_FORMAT,
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# Add file handler if log directory exists
log_path = Path(config.LOG_FILE)
if log_path.parent.exists():
    file_handler = logging.FileHandler(config.LOG_FILE)
    file_handler.setFormatter(logging.Formatter(config.LOG_FORMAT))
    logging.getLogger().addHandler(file_handler)
else:
    logger.warning(f"Log directory {log_path.parent} does not exist. Logging to console only.")


class VoiceAssistant:
    """Main Voice Assistant Service"""
    
    def __init__(self):
        """Initialize voice assistant components"""
        self.running = False
        self.processing = False
        
        # Initialize services
        logger.info("=" * 60)
        logger.info(f"Initializing {config.VOICE_ASSISTANT_NAME} v{config.VOICE_ASSISTANT_VERSION}")
        logger.info("=" * 60)
        
        try:
            self.audio_manager = AudioManager()
            self.stt_service = STTService()
            self.wake_word_service = WakeWordService(callback=self.on_wake_word_detected)
            
            logger.info("✓ All services initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize services: {e}", exc_info=True)
            raise
        
        # Setup signal handlers
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)
        
        # Initialize HTTP server for internal API
        self.http_server = None
        self.http_thread = None
        self._init_http_server()
        
        # Update status
        self.update_status("initialized")
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        logger.info(f"Received signal {signum}, shutting down...")
        self.stop()
    
    def _init_http_server(self):
        """Initialize Flask HTTP server for internal API"""
        app = Flask(__name__)
        
        @app.route('/health', methods=['GET'])
        def health():
            """Health check endpoint"""
            return jsonify({
                "status": "ok",
                "service": config.VOICE_ASSISTANT_NAME,
                "version": config.VOICE_ASSISTANT_VERSION,
                "timestamp": datetime.utcnow().isoformat()
            })
        
        @app.route('/record_and_transcribe', methods=['POST'])
        def record_and_transcribe():
            """Record audio and transcribe it with real-time streaming"""
            try:
                logger.info("📡 HTTP API: Recording and transcription requested")
                
                
                # Reset STT recognizer for new session
                self.stt_service.reset_recognizer()
                
                # Track transcription results
                last_partial = ""
                final_text = ""
                
                def transcribe_chunk(chunk_data):
                    """Callback to process each audio chunk"""
                    nonlocal last_partial, final_text
                    partial_text, is_final = self.stt_service.process_audio_chunk(chunk_data)
                    
                    if partial_text and partial_text != last_partial:
                        logger.info(f"📝 Streaming: '{partial_text}'")
                        last_partial = partial_text
                    
                    if is_final and partial_text:
                        logger.info(f"✅ Final: '{partial_text}'")
                        final_text = partial_text
                
                # Record with streaming transcription
                logger.info("🎤 Recording audio with real-time transcription...")
                audio_data, duration = self.audio_manager.record_with_streaming_callback(transcribe_chunk)
                
                if not audio_data or duration < 0.5:
                    logger.warning(f"Recording failed or too short (duration: {duration}s)")
                    return jsonify({
                        "success": False,
                        "error": "RecordingFailed",
                        "message": "No audio recorded or recording too short",
                        "duration": duration
                    }), 400
                
                logger.info(f"Recorded {duration:.2f}s of audio")
                
                # Use streaming result or fallback to full transcription
                logger.info("🔄 Finalizing transcription...")
                transcription = final_text if final_text else self.stt_service.get_final_result()
                
                if not transcription:
                    logger.warning("STT transcription returned empty result")
                    return jsonify({
                        "success": False,
                        "error": "TranscriptionFailed",
                        "message": "Could not transcribe audio",
                        "duration": duration
                    }), 400
                
                logger.info(f"✓ Transcription successful: '{transcription}'")
                
                return jsonify({
                    "success": True,
                    "transcription": transcription,
                    "duration": duration,
                    "timestamp": datetime.utcnow().isoformat()
                })
                
            except Exception as e:
                logger.error(f"Error in record_and_transcribe: {e}", exc_info=True)
                return jsonify({
                    "success": False,
                    "error": "InternalError",
                    "message": str(e)
                }), 500
        
        # Store the Flask app
        self.flask_app = app
    
    def update_status(self, state: str, data: dict = None):
        """
        Update status file for monitoring
        
        Args:
            state: Current state (initialized, listening, recording, processing, error)
            data: Additional status data
        """
        if not config.ENABLE_STATUS_FILE:
            return
        
        try:
            status = {
                "service": config.VOICE_ASSISTANT_NAME,
                "version": config.VOICE_ASSISTANT_VERSION,
                "state": state,
                "timestamp": datetime.utcnow().isoformat(),
                "data": data or {}
            }
            
            with open(config.STATUS_FILE, 'w') as f:
                json.dump(status, f, indent=2)
                
        except Exception as e:
            logger.error(f"Failed to update status file: {e}")
    
    def on_wake_word_detected(self):
        """
        Callback when wake word is detected
        Handles the entire flow: play tone → record → transcribe → send to backend
        """
        if self.processing:
            logger.warning("Already processing a query, ignoring wake word")
            return
        
        self.processing = True
        self.update_status("wake_word_detected")
        
        try:
            # Step 0: Interrupt TTS if it's currently speaking
            from utils.audio_manager import AudioManager
            if AudioManager.is_tts_active():
                logger.info("⚠️ Wake word detected during TTS, stopping TTS immediately")
                AudioManager.interrupt_tts()
                # Give TTS a moment to stop
                time.sleep(0.3)
            
            # Step 1: Play wake tone
            if config.ENABLE_WAKE_TONE:
                logger.info("Playing wake tone...")
                self.audio_manager.play_tone(config.WAKE_TONE_FILE)
            
            # Step 2: Record with real-time streaming transcription
            logger.info("🎤 Recording your query... Speak now!")
            self.update_status("recording")
            
            # Reset STT recognizer for new session
            self.stt_service.reset_recognizer()
            
            # Track partial transcription and final result
            last_partial = ""
            final_text = ""
            
            def transcribe_chunk(chunk_data):
                """Callback to process each audio chunk"""
                nonlocal last_partial, final_text
                partial_text, is_final = self.stt_service.process_audio_chunk(chunk_data)
                
                if partial_text and partial_text != last_partial:
                    logger.info(f"📝 Transcribing: '{partial_text}'")
                    last_partial = partial_text
                
                if is_final and partial_text:
                    logger.info(f"✅ Complete: '{partial_text}'")
                    final_text = partial_text  # Save the final result
            
            # Record with streaming transcription
            audio_data, duration = self.audio_manager.record_with_streaming_callback(transcribe_chunk)
            
            if audio_data is None or duration == 0:
                logger.warning("Failed to record audio")
                self.update_status("error", {"message": "Recording failed"})
                return
            
            # Step 3: Play end tone
            if config.ENABLE_END_TONE:
                logger.info("Playing end tone...")
                self.audio_manager.play_tone(config.END_TONE_FILE)
            
            # Step 4: Save recording for debugging
            if config.SAVE_RECORDINGS:
                saved_path = self.audio_manager.save_recording_debug(audio_data)
                if saved_path:
                    logger.info(f"Recording saved: {saved_path}")
            
            # Step 5: Get final transcription (use streaming result or fallback)
            logger.info("🔄 Finalizing transcription...")
            self.update_status("transcribing")
            
            transcribed_text = final_text if final_text else self.stt_service.get_final_result()
            
            if not transcribed_text:
                logger.warning("No speech detected")
                self.update_status("error", {"message": "No speech detected"})
                return
            
            logger.info(f"🎯 Final transcription: '{transcribed_text}'")
            
            # Step 6: Send to backend
            self.send_to_backend(transcribed_text)
            
        except Exception as e:
            logger.error(f"Error processing wake word: {e}", exc_info=True)
            self.update_status("error", {"message": str(e)})
        finally:
            self.processing = False
            self.update_status("listening")
    
    def send_to_backend(self, query_text: str):
        """
        Send transcribed query to the mobile app backend
        
        Args:
            query_text: The transcribed user query
        """
        logger.info(f"📤 Sending query to backend: '{query_text}'")
        self.update_status("sending_to_backend", {"query": query_text})
        
        # Prepare request payload
        payload = {
            "query": query_text,
            "user_id": "sage_glasses",  # Identifier for the glasses
            # Future: Add image_data, lat, lon if available
        }
        
        attempt = 0
        max_attempts = config.BACKEND_RETRY_ATTEMPTS + 1
        
        while attempt < max_attempts:
            try:
                attempt += 1
                logger.info(f"Attempt {attempt}/{max_attempts} to reach backend...")
                
                response = requests.post(
                    config.BACKEND_API_URL,
                    json=payload,
                    timeout=config.BACKEND_TIMEOUT
                )
                
                if response.status_code == 200:
                    result = response.json()
                    logger.info(f"✓ Backend response: {result.get('response_text', 'No response')}")
                    self.update_status("completed", {
                        "query": query_text,
                        "response": result.get('response_text'),
                        "action_type": result.get('action_type')
                    })
                    return
                else:
                    logger.error(f"Backend returned status {response.status_code}: {response.text}")
                    
            except requests.exceptions.Timeout:
                logger.error(f"Backend request timed out (attempt {attempt})")
            except requests.exceptions.ConnectionError:
                logger.error(f"Could not connect to backend (attempt {attempt})")
            except Exception as e:
                logger.error(f"Error sending to backend: {e}")
            
            # Wait before retry
            if attempt < max_attempts:
                time.sleep(1)
        
        # All attempts failed
        logger.error("Failed to reach backend after all attempts")
        self.update_status("error", {
            "message": "Backend unreachable",
            "query": query_text
        })
        
        # TODO: In future, use TTS to say "I can't connect to the servers right now"
    
    def start(self):
        """Start the voice assistant service"""
        if self.running:
            logger.warning("Voice assistant already running")
            return
        
        self.running = True
        
        # Start HTTP server in background thread
        self._start_http_server()
        
        logger.info("=" * 60)
        logger.info(f"🚀 {config.VOICE_ASSISTANT_NAME} started!")
        logger.info(f"Wake word: '{config.WAKE_WORD}'")
        logger.info(f"Backend URL: {config.BACKEND_API_URL}")
        logger.info(f"HTTP API: http://localhost:8002")
        logger.info("=" * 60)
        
        self.update_status("listening")
        
        try:
            # Start listening for wake word (blocking)
            self.wake_word_service.start_listening()
        except KeyboardInterrupt:
            logger.info("Keyboard interrupt received")
        except Exception as e:
            logger.error(f"Error in main loop: {e}", exc_info=True)
        finally:
            self.stop()
    
    def _start_http_server(self):
        """Start HTTP server in background thread"""
        try:
            self.http_server = make_server('127.0.0.1', 8002, self.flask_app, threaded=True)
            self.http_thread = threading.Thread(target=self.http_server.serve_forever, daemon=True)
            self.http_thread.start()
            logger.info("✓ HTTP API server started on port 8002")
        except Exception as e:
            logger.error(f"Failed to start HTTP server: {e}")
    
    def stop(self):
        """Stop the voice assistant service"""
        if not self.running:
            return
        
        logger.info("Stopping voice assistant...")
        self.running = False
        
        # Stop HTTP server
        if self.http_server:
            try:
                logger.info("Stopping HTTP server...")
                self.http_server.shutdown()
            except Exception as e:
                logger.error(f"Error stopping HTTP server: {e}")
        
        # Stop services
        try:
            self.wake_word_service.stop_listening()
        except:
            pass
        
        # Cleanup
        try:
            self.wake_word_service.cleanup()
            self.audio_manager.cleanup()
        except Exception as e:
            logger.error(f"Error during cleanup: {e}")
        
        self.update_status("stopped")
        logger.info("✓ Voice assistant stopped")


def main():
    """Main entry point"""
    try:
        # Create voice assistant
        assistant = VoiceAssistant()
        
        # Start the service
        assistant.start()
        
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
