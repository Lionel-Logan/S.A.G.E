"""Input validation utilities."""
import base64
import re
from config import SUPPORTED_IMAGE_FORMATS, MAX_IMAGE_SIZE_MB
from src.exceptions import InvalidBase64Exception, ValidationException


def validate_base64_string(image_base64: str) -> None:
    """Validate that a string is valid Base64.
    
    Args:
        image_base64: Base64-encoded string to validate
        
    Raises:
        InvalidBase64Exception: If string is not valid Base64
        ValidationException: If string is empty
    """
    if not image_base64:
        raise ValidationException("Image base64 string cannot be empty")
    
    # Clean the string: remove whitespace, newlines, and data URI prefix if present
    cleaned_base64 = image_base64.strip()
    
    # Handle data URI format (e.g., "data:image/png;base64,...")
    if ',' in cleaned_base64:
        cleaned_base64 = cleaned_base64.split(',', 1)[1]
    
    # Remove all whitespace (newlines, spaces, etc)
    cleaned_base64 = re.sub(r'\s', '', cleaned_base64)
    
    # Check if string matches Base64 pattern (allowing + / and = for padding)
    base64_pattern = r'^[A-Za-z0-9+/]*={0,2}$'
    if not re.match(base64_pattern, cleaned_base64):
        raise InvalidBase64Exception("Invalid Base64 format - contains invalid characters")
    
    # Validate Base64 length (should be multiple of 4)
    if len(cleaned_base64) % 4 != 0:
        raise InvalidBase64Exception("Base64 string length must be a multiple of 4")
    
    # Try to decode
    try:
        base64.b64decode(cleaned_base64, validate=True)
    except Exception as e:
        raise InvalidBase64Exception(f"Base64 decoding failed: {str(e)}")


def validate_image_size(image_bytes: bytes) -> None:
    """Validate image size is within limits.
    
    Args:
        image_bytes: Image data in bytes
        
    Raises:
        ValidationException: If image size exceeds maximum allowed
    """
    size_mb = len(image_bytes) / (1024 * 1024)
    if size_mb > MAX_IMAGE_SIZE_MB:
        raise ValidationException(
            f"Image size ({size_mb:.2f}MB) exceeds maximum allowed ({MAX_IMAGE_SIZE_MB}MB)"
        )


def validate_confidence_threshold(threshold: float) -> None:
    """Validate confidence threshold is in valid range.
    
    Args:
        threshold: Confidence threshold value
        
    Raises:
        ValidationException: If threshold is not between 0 and 1
    """
    if not (0 <= threshold <= 1):
        raise ValidationException("Confidence threshold must be between 0 and 1")
