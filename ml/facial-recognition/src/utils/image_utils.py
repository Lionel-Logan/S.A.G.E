"""
Image utility functions for Face Recognition Service
Handles base64 decoding and image preprocessing
"""
import base64
import cv2
import numpy as np
from typing import Tuple, Optional
import logging

logger = logging.getLogger(__name__)


class ImageProcessingError(Exception):
    """Custom exception for image processing errors"""
    pass


def decode_base64_image(base64_string: str) -> np.ndarray:
    """
    Decode base64 string to OpenCV image (numpy array)
    
    Args:
        base64_string: Base64 encoded image string
        
    Returns:
        np.ndarray: Decoded image in BGR format (OpenCV format)
        
    Raises:
        ImageProcessingError: If decoding fails
    """
    try:
        # Remove data URI prefix if present (e.g., "data:image/jpeg;base64,")
        if ',' in base64_string:
            base64_string = base64_string.split(',', 1)[1]
        
        # Decode base64 to bytes
        image_bytes = base64.b64decode(base64_string)
        
        # Convert bytes to numpy array
        nparr = np.frombuffer(image_bytes, np.uint8)
        
        # Decode to OpenCV image
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            raise ImageProcessingError("Failed to decode image. Invalid image format.")
        
        logger.info(f"Successfully decoded image with shape: {image.shape}")
        return image
        
    except base64.binascii.Error as e:
        raise ImageProcessingError(f"Invalid base64 encoding: {str(e)}")
    except Exception as e:
        raise ImageProcessingError(f"Failed to decode image: {str(e)}")


def encode_image_to_base64(image: np.ndarray, format: str = '.jpg') -> str:
    """
    Encode OpenCV image to base64 string
    
    Args:
        image: OpenCV image (numpy array)
        format: Image format (.jpg, .png, etc.)
        
    Returns:
        str: Base64 encoded image string
        
    Raises:
        ImageProcessingError: If encoding fails
    """
    try:
        # Encode image to specified format
        success, buffer = cv2.imencode(format, image)
        
        if not success:
            raise ImageProcessingError(f"Failed to encode image to {format}")
        
        # Convert to base64
        base64_string = base64.b64encode(buffer).decode('utf-8')
        
        return base64_string
        
    except Exception as e:
        raise ImageProcessingError(f"Failed to encode image: {str(e)}")


def validate_image(image: np.ndarray) -> Tuple[bool, Optional[str]]:
    """
    Validate image dimensions and format
    
    Args:
        image: OpenCV image (numpy array)
        
    Returns:
        Tuple[bool, Optional[str]]: (is_valid, error_message)
    """
    if image is None:
        return False, "Image is None"
    
    if not isinstance(image, np.ndarray):
        return False, "Image must be a numpy array"
    
    if len(image.shape) != 3:
        return False, f"Invalid image dimensions: {image.shape}. Expected 3D array (H, W, C)"
    
    height, width, channels = image.shape
    
    if channels != 3:
        return False, f"Invalid number of channels: {channels}. Expected 3 (BGR)"
    
    if height < 32 or width < 32:
        return False, f"Image too small: {width}x{height}. Minimum size is 32x32"
    
    if height > 4096 or width > 4096:
        return False, f"Image too large: {width}x{height}. Maximum size is 4096x4096"
    
    return True, None


def preprocess_image(image: np.ndarray, max_size: int = 1920) -> np.ndarray:
    """
    Preprocess image for face detection
    Resizes large images while maintaining aspect ratio
    
    Args:
        image: Input image
        max_size: Maximum dimension (width or height)
        
    Returns:
        np.ndarray: Preprocessed image
    """
    height, width = image.shape[:2]
    
    # Only resize if image is larger than max_size
    if max(height, width) > max_size:
        scale = max_size / max(height, width)
        new_width = int(width * scale)
        new_height = int(height * scale)
        
        image = cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_AREA)
        logger.info(f"Resized image from {width}x{height} to {new_width}x{new_height}")
    
    return image


def get_image_info(image: np.ndarray) -> dict:
    """
    Get basic information about an image
    
    Args:
        image: OpenCV image
        
    Returns:
        dict: Image information (width, height, channels, dtype, size)
    """
    if image is None or not isinstance(image, np.ndarray):
        return {}
    
    height, width = image.shape[:2]
    channels = image.shape[2] if len(image.shape) == 3 else 1
    
    return {
        "width": width,
        "height": height,
        "channels": channels,
        "dtype": str(image.dtype),
        "size_bytes": image.nbytes,
        "shape": image.shape
    }
