"""Image processing service."""
import base64
import io
import re
from typing import Tuple
import numpy as np
from PIL import Image

from src.exceptions import (
    InvalidBase64Exception,
    ImageDecodingException,
    UnsupportedImageFormatException,
    ImageSizeException
)
from src.utils.validators import validate_base64_string, validate_image_size
from src.utils.logger import get_logger
from config import SUPPORTED_IMAGE_FORMATS

logger = get_logger(__name__)


class ImageService:
    """Service for handling image processing and validation."""
    
    @staticmethod
    def decode_base64_image(image_base64: str) -> Tuple[np.ndarray, int, int]:
        """Decode Base64-encoded image to NumPy array.
        
        Args:
            image_base64: Base64-encoded image string
            
        Returns:
            Tuple of (image_array, width, height)
            
        Raises:
            InvalidBase64Exception: If Base64 is invalid
            ImageDecodingException: If image decoding fails
            UnsupportedImageFormatException: If image format is not supported
            ImageSizeException: If image is too large
        """
        logger.debug("Starting Base64 image decoding")
        
        # Validate Base64 string
        validate_base64_string(image_base64)
        
        # Clean the Base64 string for decoding
        cleaned_base64 = image_base64.strip()
        # Handle data URI format (e.g., "data:image/png;base64,...")
        if ',' in cleaned_base64:
            cleaned_base64 = cleaned_base64.split(',', 1)[1]
        # Remove all whitespace (newlines, spaces, etc)
        cleaned_base64 = re.sub(r'\s', '', cleaned_base64)
        
        # Decode Base64 to bytes
        try:
            image_bytes = base64.b64decode(cleaned_base64)
            logger.debug(f"Decoded {len(image_bytes)} bytes from Base64")
        except Exception as e:
            logger.error(f"Base64 decoding failed: {str(e)}")
            raise InvalidBase64Exception(f"Failed to decode Base64: {str(e)}")
        
        # Validate image size
        try:
            validate_image_size(image_bytes)
        except Exception as e:
            logger.error(f"Image size validation failed: {str(e)}")
            raise ImageSizeException(str(e))
        
        # Decode image from bytes
        try:
            pil_image = Image.open(io.BytesIO(image_bytes))
            logger.debug(f"Image opened successfully: format={pil_image.format}, size={pil_image.size}")
        except Exception as e:
            logger.error(f"Image decoding failed: {str(e)}")
            raise ImageDecodingException(f"Failed to decode image: {str(e)}")
        
        # Validate image format
        if pil_image.format and pil_image.format.lower() not in SUPPORTED_IMAGE_FORMATS:
            logger.error(f"Unsupported image format: {pil_image.format}")
            raise UnsupportedImageFormatException(
                f"Image format '{pil_image.format}' is not supported. "
                f"Supported formats: {', '.join(SUPPORTED_IMAGE_FORMATS)}"
            )
        
        # Convert to RGB if necessary (handles RGBA, grayscale, etc.)
        if pil_image.mode != "RGB":
            logger.debug(f"Converting image from {pil_image.mode} to RGB")
            pil_image = pil_image.convert("RGB")
        
        # Convert to NumPy array (BGR for OpenCV compatibility)
        image_array = np.array(pil_image)
        # Convert RGB to BGR
        image_array = image_array[:, :, ::-1]
        
        width, height = pil_image.size
        logger.debug(f"Image successfully converted to NumPy array: shape={image_array.shape}")
        
        return image_array, width, height
    
    @staticmethod
    def get_image_dimensions(image_array: np.ndarray) -> Tuple[int, int]:
        """Get image dimensions from NumPy array.
        
        Args:
            image_array: Image as NumPy array
            
        Returns:
            Tuple of (width, height)
        """
        height, width = image_array.shape[:2]
        return width, height
