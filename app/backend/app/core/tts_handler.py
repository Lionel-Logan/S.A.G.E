"""
Improved TTS Handler with Connection Pooling and Retry Logic
Uses a shared httpx.AsyncClient to avoid connection exhaustion
Especially important for high-frequency TTS calls from navigation
"""

import asyncio
import httpx
from app.config import settings
import logging

logger = logging.getLogger(__name__)

# Global shared client for connection pooling (reuse TCP connections)
_tts_client: httpx.AsyncClient = None

async def get_tts_client() -> httpx.AsyncClient:
    """Get or create singleton TTS client with connection pooling"""
    global _tts_client
    if _tts_client is None:
        _tts_client = httpx.AsyncClient(
            timeout=settings.PI_REQUEST_TIMEOUT,
            limits=httpx.Limits(max_connections=10, max_keepalive_connections=5)
        )
        logger.info("🔌 TTS Client initialized with connection pooling")
    return _tts_client

async def close_tts_client():
    """Close the global TTS client (call at app shutdown)"""
    global _tts_client
    if _tts_client is not None:
        await _tts_client.aclose()
        _tts_client = None
        logger.info("🔌 TTS Client closed")


async def send_to_tts_robust(
    text: str,
    max_retries: int = 2,
    retry_delay: float = 0.1,
    silent_fail: bool = False
) -> bool:
    """
    Send text to Pi server for TTS output with retry logic
    Uses shared connection pool to avoid exhaustion on high-frequency calls
    
    Args:
        text: Text to speak
        max_retries: Number of retry attempts (default: 2)
        retry_delay: Delay between retries in seconds (default: 0.1s)
        silent_fail: If True, don't log errors (default: False)
    
    Returns:
        True if TTS sent successfully, False otherwise
    """
    
    if not text or not text.strip():
        logger.warning("Skipping TTS: empty text")
        return False
    
    pi_url = f"{settings.PI_SERVER_URL}/tts/speak"
    client = await get_tts_client()
    
    for attempt in range(max_retries):
        try:
            # Use shared client (connection pooling)
            response = await client.post(
                pi_url,
                json={"text": text, "blocking": False},
                headers={"Content-Type": "application/json"}
            )
            
            # Check for HTTP errors
            response.raise_for_status()
            
            if attempt > 0:
                logger.info(f"✅ TTS sent successfully (retry {attempt}): '{text}'")
            else:
                logger.debug(f"✅ TTS sent: '{text}'")
            return True
        
        except httpx.ConnectError as e:
            # DNS resolution or connection refused
            attempt_info = f"attempt {attempt + 1}/{max_retries}"
            
            if attempt < max_retries - 1:
                logger.warning(
                    f"⚠️  TTS connection error ({attempt_info}): {type(e).__name__} | "
                    f"Retrying in {retry_delay}s..."
                )
                await asyncio.sleep(retry_delay)
            else:
                if not silent_fail:
                    logger.error(
                        f"❌ TTS failed after {max_retries} attempts. "
                        f"Cannot reach Pi server at {pi_url}. "
                        f"Error: {type(e).__name__}: {e}"
                    )
                return False
        
        except httpx.HTTPStatusError as e:
            # HTTP error (4xx, 5xx)
            logger.error(
                f"❌ TTS HTTP error: {e.response.status_code} {e.response.reason_phrase} | "
                f"URL: {pi_url}"
            )
            return False
        
        except httpx.TimeoutException as e:
            # Request timeout
            attempt_info = f"attempt {attempt + 1}/{max_retries}"
            
            if attempt < max_retries - 1:
                logger.warning(
                    f"⚠️  TTS timeout ({attempt_info}): took longer than {settings.PI_REQUEST_TIMEOUT}s | "
                    f"Retrying..."
                )
                await asyncio.sleep(retry_delay)
            else:
                if not silent_fail:
                    logger.error(
                        f"❌ TTS timeout after {max_retries} attempts. "
                        f"Pi server not responding within {settings.PI_REQUEST_TIMEOUT}s"
                    )
                return False
        
        except httpx.RequestError as e:
            # General request error
            if not silent_fail:
                logger.error(f"❌ TTS request error: {type(e).__name__}: {e}")
            return False
        
        except Exception as e:
            # Unexpected error
            logger.error(f"❌ Unexpected TTS error: {type(e).__name__}: {e}", exc_info=True)
            return False
    
    return False


async def send_to_tts(text: str):
    """
    Wrapper function for backward compatibility
    Drop-in replacement for existing _send_to_tts calls
    """
    await send_to_tts_robust(text, max_retries=2, silent_fail=True)


# ============================================================================
# TESTING FUNCTION
# ============================================================================

async def test_tts_connection():
    """Test if TTS connection works"""
    test_messages = [
        "Connection test successful",
        "Testing one two three",
        "This is a test message"
    ]
    
    logger.info(f"🧪 Testing TTS connection to {settings.PI_SERVER_URL}")
    
    for msg in test_messages:
        success = await send_to_tts_robust(msg, max_retries=1)
        if not success:
            logger.error("❌ TTS test failed")
            return False
    
    logger.info("✅ TTS connection test passed!")
    return True


# ============================================================================
# USAGE EXAMPLES
# ============================================================================

"""
# Example 1: In Navigation Endpoint (app/api/v1/location.py)
-----------
if nav_result and nav_result.get("should_speak") and nav_result.get("instruction"):
    print(f"📢 Speaking instruction: {nav_result['instruction']}")
    success = await send_to_tts_robust(nav_result["instruction"])
    if not success:
        print(f"⚠️ Failed to send TTS for: {nav_result['instruction']}")


# Example 2: With Error Handling (app/api/v1/assistant.py)
-----------
await send_to_tts_robust(response_text, max_retries=3)
# Or use silent version:
await send_to_tts(response_text)  # Uses max_retries=2, silent_fail=True


# Example 3: In a service with custom retry logic (app/services/*)
-----------
success = await send_to_tts_robust(
    text="Turn right onto Main Street",
    max_retries=5,
    retry_delay=1.0,
    silent_fail=False
)

if not success:
    logger.warning(f"TTS failed, continuing without audio")
    # Optionally notify user via other means


# Example 4: Testing during development
-----------
# Add this to a test endpoint
import asyncio
from app.core.tts_handler import test_tts_connection

@router.get("/test-tts")
async def test_tts():
    success = await test_tts_connection()
    return {"tts_working": success, "pi_url": settings.PI_SERVER_URL}
"""

