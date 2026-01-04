class ModelServerError(Exception):
    """Raised when an external model server (Face/Object) fails"""
    pass

class OCRError(Exception):
    """Raised when Google Vision fails"""
    pass

class TranslationError(Exception):
    """Raised when Translation service fails"""
    pass