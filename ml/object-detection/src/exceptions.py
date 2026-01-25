"""Custom exceptions for the object detection service."""


class ObjectDetectionException(Exception):
    """Base exception for object detection service."""
    pass


class ImageProcessingException(ObjectDetectionException):
    """Raised when image processing fails."""
    pass


class InvalidBase64Exception(ImageProcessingException):
    """Raised when Base64 decoding fails."""
    pass


class UnsupportedImageFormatException(ImageProcessingException):
    """Raised when image format is not supported."""
    pass


class ImageDecodingException(ImageProcessingException):
    """Raised when image decoding fails."""
    pass


class ImageSizeException(ImageProcessingException):
    """Raised when image size exceeds maximum allowed."""
    pass


class YOLOModelException(ObjectDetectionException):
    """Raised when YOLO model operations fail."""
    pass


class ModelLoadException(YOLOModelException):
    """Raised when model loading fails."""
    pass


class InferenceException(YOLOModelException):
    """Raised when inference fails."""
    pass


class ValidationException(ObjectDetectionException):
    """Raised when input validation fails."""
    pass
