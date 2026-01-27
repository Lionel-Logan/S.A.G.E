"""
Configuration for SAGE Text-to-Speech Service
Supports runtime configuration updates with persistence
"""

import json
import logging
from pathlib import Path
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

# TTS Engine Configuration
TTS_ENGINE = "pyttsx3"  # Offline text-to-speech engine

# Default Voice Settings (can be updated via API)
DEFAULT_VOICE_SPEED = 175  # words per minute (100-300 recommended)
DEFAULT_VOICE_VOLUME = 0.9  # 0.0 to 1.0
DEFAULT_VOICE_GENDER = "female"  # male, female, neutral (used for auto-selection)
DEFAULT_VOICE_ID = None  # System voice ID (None = auto-select based on gender)
DEFAULT_VOICE_LANGUAGE = "en-US"  # Language code

# Audio Output Configuration
OUTPUT_DEVICE = None  # Use current audio sink (from bluetooth_manager)
AUDIO_FORMAT = "wav"

# Performance Settings
TTS_TIMEOUT = 30  # Maximum seconds for TTS operation
ENABLE_TTS_CACHE = False  # Cache generated audio files (disabled by default)
TTS_CACHE_DIR = "/tmp/sage_tts_cache"

# Persistence Settings
CONFIG_PERSIST_FILE = "/home/sage/sage/.sage/tts_settings.json"  # Persisted settings location
ENABLE_CONFIG_PERSISTENCE = True  # Save settings across reboots

# Feature Flags
SAVE_TTS_AUDIO = False  # Debug: save generated audio files
DEBUG_TTS_DIR = "/home/sage/sage/tts_debug"  # Directory for debug audio files

# Logging Configuration
LOG_TTS_EVENTS = True  # Log TTS operations for debugging


class TTSConfig:
    """Runtime TTS configuration with persistence"""
    
    def __init__(self):
        """Initialize configuration with defaults"""
        self.voice_speed = DEFAULT_VOICE_SPEED
        self.voice_volume = DEFAULT_VOICE_VOLUME
        self.voice_gender = DEFAULT_VOICE_GENDER
        self.voice_id = DEFAULT_VOICE_ID
        self.voice_language = DEFAULT_VOICE_LANGUAGE
        
        # Load persisted settings if available
        if ENABLE_CONFIG_PERSISTENCE:
            self._load_persisted_config()
    
    def _load_persisted_config(self):
        """Load configuration from persisted file"""
        config_file = Path(CONFIG_PERSIST_FILE)
        
        if not config_file.exists():
            logger.info("No persisted TTS configuration found, using defaults")
            return
        
        try:
            with open(config_file, 'r') as f:
                saved_config = json.load(f)
            
            # Update settings from file
            self.voice_speed = saved_config.get('voice_speed', DEFAULT_VOICE_SPEED)
            self.voice_volume = saved_config.get('voice_volume', DEFAULT_VOICE_VOLUME)
            self.voice_gender = saved_config.get('voice_gender', DEFAULT_VOICE_GENDER)
            self.voice_id = saved_config.get('voice_id', DEFAULT_VOICE_ID)
            self.voice_language = saved_config.get('voice_language', DEFAULT_VOICE_LANGUAGE)
            
            logger.info(f"Loaded persisted TTS configuration from {config_file}")
            logger.info(f"Settings: speed={self.voice_speed}, volume={self.voice_volume}, "
                       f"gender={self.voice_gender}, voice_id={self.voice_id}")
            
        except Exception as e:
            logger.error(f"Failed to load persisted config: {e}", exc_info=True)
            logger.info("Using default TTS configuration")
    
    def _save_persisted_config(self):
        """Save current configuration to file"""
        if not ENABLE_CONFIG_PERSISTENCE:
            return
        
        config_file = Path(CONFIG_PERSIST_FILE)
        
        try:
            # Create directory if it doesn't exist
            config_file.parent.mkdir(parents=True, exist_ok=True)
            
            # Save current settings
            config_data = {
                'voice_speed': self.voice_speed,
                'voice_volume': self.voice_volume,
                'voice_gender': self.voice_gender,
                'voice_id': self.voice_id,
                'voice_language': self.voice_language,
                'updated_at': str(Path(__file__).stat().st_mtime)
            }
            
            with open(config_file, 'w') as f:
                json.dump(config_data, f, indent=2)
            
            logger.info(f"Saved TTS configuration to {config_file}")
            
        except Exception as e:
            logger.error(f"Failed to save persisted config: {e}", exc_info=True)
    
    def update(self, settings: Dict[str, Any]) -> Dict[str, Any]:
        """
        Update configuration settings
        
        Args:
            settings: Dictionary with new settings
            
        Returns:
            Updated configuration as dictionary
        """
        updated_fields = []
        
        # Update voice speed
        if 'voice_speed' in settings:
            speed = settings['voice_speed']
            if isinstance(speed, (int, float)) and 100 <= speed <= 300:
                self.voice_speed = int(speed)
                updated_fields.append('voice_speed')
            else:
                logger.warning(f"Invalid voice_speed: {speed} (must be 100-300)")
        
        # Update voice volume
        if 'voice_volume' in settings:
            volume = settings['voice_volume']
            if isinstance(volume, (int, float)) and 0.0 <= volume <= 1.0:
                self.voice_volume = float(volume)
                updated_fields.append('voice_volume')
            else:
                logger.warning(f"Invalid voice_volume: {volume} (must be 0.0-1.0)")
        
        # Update voice gender
        if 'voice_gender' in settings:
            gender = settings['voice_gender']
            if gender in ['male', 'female', 'neutral']:
                self.voice_gender = gender
                updated_fields.append('voice_gender')
            else:
                logger.warning(f"Invalid voice_gender: {gender} (must be male/female/neutral)")
        
        # Update voice ID
        if 'voice_id' in settings:
            self.voice_id = settings['voice_id']
            updated_fields.append('voice_id')
        
        # Update voice language
        if 'voice_language' in settings:
            self.voice_language = settings['voice_language']
            updated_fields.append('voice_language')
        
        if updated_fields:
            logger.info(f"Updated TTS config fields: {', '.join(updated_fields)}")
            # Persist changes
            self._save_persisted_config()
        
        return self.to_dict()
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert configuration to dictionary"""
        return {
            'voice_speed': self.voice_speed,
            'voice_volume': self.voice_volume,
            'voice_gender': self.voice_gender,
            'voice_id': self.voice_id,
            'voice_language': self.voice_language,
            'engine': TTS_ENGINE
        }


# Global configuration instance
tts_runtime_config = TTSConfig()
