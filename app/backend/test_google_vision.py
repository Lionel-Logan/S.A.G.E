"""
Test Google Cloud Vision OCR
Run after setting up service_account.json
"""
import asyncio
import base64
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.ocr_service import OCRService


async def test_google_vision_ocr():
    """Test Google Vision OCR with a sample image"""
    
    print("=" * 60)
    print("Testing Google Cloud Vision OCR")
    print("=" * 60)
    
    # Simple test image (1x1 red pixel - won't have text, but tests API connection)
    test_image = "iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg=="
    
    try:
        print("\n1. Initializing OCR Service...")
        ocr = OCRService()
        print("✅ OCR Service initialized successfully")
        print(f"   Using credentials: {os.environ.get('GOOGLE_APPLICATION_CREDENTIALS', 'Not set')}")
        
        print("\n2. Testing text extraction...")
        text = await ocr.extract_text(test_image)
        
        if text:
            print(f"✅ Extracted text: '{text}'")
        else:
            print("⚠️  No text found (expected - test image has no text)")
            print("✅ But API connection successful!")
        
        print("\n" + "=" * 60)
        print("✅ GOOGLE VISION OCR TEST PASSED!")
        print("=" * 60)
        print("\n📝 Next steps:")
        print("   1. Test with real image containing text")
        print("   2. Run full translation test: python test_translation.py")
        print("   3. Start backend and test via Swagger UI")
        
    except Exception as e:
        print("\n" + "=" * 60)
        print("❌ GOOGLE VISION OCR TEST FAILED")
        print("=" * 60)
        print(f"\n❌ Error: {e}")
        print("\n🔧 Troubleshooting:")
        print("   1. Make sure service_account.json exists in backend directory")
        print("   2. Verify GOOGLE_VISION_CREDENTIALS in .env")
        print("   3. Check Vision API is enabled in Google Cloud Console")
        print("   4. Verify service account has correct permissions")
        print("\n📚 See GOOGLE_VISION_SETUP.md for detailed instructions")


async def test_with_text_image():
    """Test with an actual image containing text (if you have one)"""
    print("\n" + "=" * 60)
    print("Optional: Test with your own image")
    print("=" * 60)
    
    # Example: Load an image file and convert to base64
    image_path = "test_image.jpg"  # Replace with your image path
    
    if not os.path.exists(image_path):
        print(f"⚠️  No test image found at: {image_path}")
        print("   Create a test image with text to test OCR accuracy")
        return
    
    try:
        with open(image_path, "rb") as image_file:
            image_base64 = base64.b64encode(image_file.read()).decode('utf-8')
        
        print(f"\n1. Loading image: {image_path}")
        ocr = OCRService()
        text = await ocr.extract_text(image_base64)
        
        print(f"\n✅ Extracted text:")
        print(f"   {text}")
        
    except Exception as e:
        print(f"❌ Error: {e}")


if __name__ == "__main__":
    print("\n🚀 Starting Google Vision OCR Test...\n")
    asyncio.run(test_google_vision_ocr())
    
    # Uncomment to test with your own image:
    # asyncio.run(test_with_text_image())
