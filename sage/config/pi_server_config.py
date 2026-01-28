"""
Configuration for SAGE Pi FastAPI Server
"""

# Server Configuration
SERVER_HOST = "0.0.0.0"  # Bind to all network interfaces
SERVER_PORT = 8001
SERVER_NAME = "SAGE Pi Server"
SERVER_VERSION = "1.0.0"

# Logging Configuration
LOG_LEVEL = "INFO"  # DEBUG, INFO, WARNING, ERROR, CRITICAL
LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
LOG_FILE = "/var/log/sage/pi_server.log"

# CORS Configuration
CORS_ORIGINS = [
    "*",  # Allow all origins for development
    # In production, specify Flutter app's origins:
    # "http://192.168.1.100",
    # "http://10.0.0.100",
]

# Service Metadata
DESCRIPTION = """
SAGE Pi Server - FastAPI backend running on Raspberry Pi smartglasses.

Handles:
- Camera capture and streaming (photos, videos, live preview)
- Audio input/output (TTS, STT)
- HUD display commands
- System monitoring
- Communication with mobile app
"""
