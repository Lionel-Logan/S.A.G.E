from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # App Info
    APP_NAME: str = "SAGE Backend"
    VERSION: str = "1.0.0"
    API_V1_PREFIX: str = "/api/v1"
    
    # Security
    SECRET_KEY: str  # Generate with: openssl rand -hex 32
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    
    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./sage.db"
    
    # Redis (for job queue)
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # Model Servers (Nikhil & Ananya)
    FACE_RECOGNITION_URL: str = "http://192.168.1.10:8002"
    OBJECT_DETECTION_URL: str = "http://localhost:8003"
    MODEL_REQUEST_TIMEOUT: int = 30
    
    # Pi Server (Raspberry Pi)
    PI_SERVER_URL: str = "http://sage-pi.local:8001"  # Pi camera and TTS
    PI_REQUEST_TIMEOUT: int = 10
    
    # External APIs
    GOOGLE_VISION_CREDENTIALS: str = "service_account.json"  # Path to JSON key for Vision API + Vertex AI
    GOOGLE_TRANSLATE_API_KEY: str  # Google Cloud Translation API key
    GOOGLE_CLOUD_PROJECT: str = "sage-glasses"  # GCP project ID for Vertex AI
    GOOGLE_CLOUD_LOCATION: str = "asia-south1"  # Vertex AI region (Mumbai, India)
    GOOGLE_MAPS_API_KEY: str = ""  # Google Maps Platform (Directions API + Places API)
    
    # Google Search API (uses API Key for authentication - not service account)
    GOOGLE_SEARCH_API_KEY: str = ""  # Custom Search API Key
    GOOGLE_SEARCH_ENGINE_ID: str = ""  # Custom Search Engine ID (CX)
    WEB_SEARCH_CACHE_TTL: int = 3600  # 1 hour cache for search results
    
    # Web Search Trigger Keywords
    TEMPORAL_KEYWORDS: list = [
        "latest", "current", "today", "recent", "now", "right now",
        "this week", "this month", "this year", "tomorrow", "yesterday",
        "news", "update", "breaking", "trending", "happening", "just",
        "just happened", "what's", "what is", "changed", "anymore", "no longer"
    ]
    
    POSITION_KEYWORDS: list = [
        "prime minister", "pm", "cm", "chief minister", "president", 
        "governor", "minister", "secretary", "ceo", "director", "chief",
        "leader", "mayor", "head", "chairman", "vice president", "vp",
        "who is", "who's", "current", "present", "newly appointed"
    ]
    
    # Performance
    MAX_IMAGE_SIZE_MB: int = 5
    MAX_CONCURRENT_JOBS: int = 10
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()