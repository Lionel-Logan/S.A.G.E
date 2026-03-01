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
    FACE_RECOGNITION_URL: str = "http://localhost:8002"
    OBJECT_DETECTION_URL: str = "http://localhost:8003"
    MODEL_REQUEST_TIMEOUT: int = 30
    
    # Pi Server (Raspberry Pi)
    PI_SERVER_URL: str = "http://sage-pi.local:8001"  # Pi camera and TTS
    PI_REQUEST_TIMEOUT: int = 10
    
    # External APIs
    GOOGLE_VISION_CREDENTIALS: str = "service_account.json"  # Path to JSON key for Vision + Gemini
    GOOGLE_TRANSLATE_API_KEY: str  # Google Cloud Translation API key
    
    # Performance
    MAX_IMAGE_SIZE_MB: int = 5
    MAX_CONCURRENT_JOBS: int = 10
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()