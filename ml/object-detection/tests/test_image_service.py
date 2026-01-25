"""Tests for the image service."""
import base64
import io
import pytest
import numpy as np
from PIL import Image

from src.services.image_service import ImageService
from src.exceptions import (
    InvalidBase64Exception,
    ImageDecodingException,
    UnsupportedImageFormatException,
    ImageSizeException
)


class TestImageService:
    """Test cases for ImageService."""
    
    @staticmethod
    def create_test_image_base64(format="JPEG", size=(100, 100)):
        """Create a test image in Base64 format.
        
        Args:
            format: Image format (JPEG, PNG, BMP, etc.)
            size: Image size as (width, height)
            
        Returns:
            Base64-encoded image string
        """
        # Create a simple RGB image
        img = Image.new("RGB", size, color=(255, 0, 0))
        
        # Convert to bytes
        img_bytes = io.BytesIO()
        img.save(img_bytes, format=format)
        img_bytes.seek(0)
        
        # Encode to Base64
        return base64.b64encode(img_bytes.read()).decode()
    
    def test_decode_valid_base64_image(self):
        """Test decoding a valid Base64 image."""
        image_base64 = self.create_test_image_base64()
        
        image_array, width, height = ImageService.decode_base64_image(image_base64)
        
        assert isinstance(image_array, np.ndarray)
        assert image_array.shape == (100, 100, 3)
        assert width == 100
        assert height == 100
    
    def test_decode_invalid_base64_format(self):
        """Test decoding invalid Base64 format."""
        with pytest.raises(InvalidBase64Exception):
            ImageService.decode_base64_image("not_valid_base64!!!")
    
    def test_decode_empty_base64(self):
        """Test decoding empty Base64 string."""
        with pytest.raises(InvalidBase64Exception):
            ImageService.decode_base64_image("")
    
    def test_decode_corrupted_base64(self):
        """Test decoding corrupted image data."""
        # Valid Base64 but not a valid image
        invalid_image_base64 = base64.b64encode(b"this is not an image").decode()
        
        with pytest.raises(ImageDecodingException):
            ImageService.decode_base64_image(invalid_image_base64)
    
    def test_decode_png_format(self):
        """Test decoding PNG format."""
        image_base64 = self.create_test_image_base64(format="PNG")
        
        image_array, width, height = ImageService.decode_base64_image(image_base64)
        
        assert isinstance(image_array, np.ndarray)
        assert image_array.shape == (100, 100, 3)
    
    def test_get_image_dimensions(self):
        """Test getting image dimensions from array."""
        image_array = np.zeros((200, 300, 3), dtype=np.uint8)
        
        width, height = ImageService.get_image_dimensions(image_array)
        
        assert width == 300
        assert height == 200
