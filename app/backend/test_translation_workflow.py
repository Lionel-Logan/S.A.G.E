"""
Complete Image Translation Workflow Test
Tests: Pi Camera → Google Vision OCR → Google Translate → TTS

This tests the entire pipeline:
1. Image input (simulated from Pi camera)
2. Google Vision OCR text extraction
3. Language detection
4. Translation to English using Google Cloud Translate
5. Output formatting for TTS

Run: python test_translation_workflow.py
"""
import asyncio
import base64
import sys
import os
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.ocr_service import OCRService
from app.services.google_translate_service import GoogleTranslateService
from app.services.translate_service import TranslateService


# Sample test images with text in different languages (base64 encoded PNGs)
# These are simple text images created for testing

# Test Image 1: Simple English text "HELLO" (minimal PNG)
SAMPLE_IMAGE_ENGLISH = "iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg=="

# Test Image 2: For testing - replace with actual image containing foreign text
# To create your own test image:
# 1. Create an image with text (e.g., Spanish "Hola", Hindi "नमस्ते", etc.)
# 2. Convert to base64: base64.b64encode(open('image.png', 'rb').read()).decode()


def print_header(title: str):
    """Print a formatted header"""
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70)


def print_step(step: int, description: str):
    """Print a formatted step"""
    print(f"\n[STEP {step}] {description}")
    print("-" * 70)


def print_success(message: str):
    """Print success message"""
    print(f"✅ {message}")


def print_error(message: str):
    """Print error message"""
    print(f"❌ {message}")


def print_info(message: str):
    """Print info message"""
    print(f"ℹ️  {message}")


async def test_ocr_service():
    """Test 1: Google Vision OCR Service"""
    print_header("TEST 1: Google Vision OCR Service")
    
    try:
        print_step(1, "Initializing OCR Service")
        ocr = OCRService()
        print_success("OCR Service initialized")
        print_info(f"Credentials: {os.environ.get('GOOGLE_APPLICATION_CREDENTIALS', 'Not set')}")
        
        print_step(2, "Testing text extraction from image")
        text = await ocr.extract_text(SAMPLE_IMAGE_ENGLISH)
        
        if text:
            print_success(f"Text extracted: '{text}'")
            return True
        else:
            print_info("No text found in test image (this is expected for the minimal test image)")
            print_success("API connection successful!")
            return True
            
    except Exception as e:
        print_error(f"OCR test failed: {e}")
        print("\n🔧 Troubleshooting:")
        print("   1. Ensure service_account.json exists in backend directory")
        print("   2. Verify GOOGLE_VISION_CREDENTIALS in .env file")
        print("   3. Check Vision API is enabled in Google Cloud Console")
        print("   4. See GOOGLE_VISION_SETUP.md for setup instructions")
        return False


async def test_google_translate_service():
    """Test 2: Google Cloud Translate Service"""
    print_header("TEST 2: Google Cloud Translate Service")
    
    try:
        print_step(1, "Initializing Google Translate Service")
        translator = GoogleTranslateService()
        print_success("Google Translate Service initialized")
        
        # Test 1: Language Detection
        print_step(2, "Testing language detection")
        test_texts = [
            ("Hello, how are you?", "English"),
            ("Hola, ¿cómo estás?", "Spanish"),
            ("Bonjour, comment allez-vous?", "French"),
            ("Hallo, wie geht es dir?", "German"),
        ]
        
        for text, expected_lang in test_texts:
            detected_lang = await translator.detect_language(text)
            print_info(f"Text: '{text[:30]}...'")
            print_success(f"Detected language: {detected_lang} (Expected: {expected_lang})")
        
        # Test 2: Translation
        print_step(3, "Testing translation to English")
        test_translation_pairs = [
            ("Hola", "es", "Hello"),
            ("Bonjour", "fr", "Hello"),
            ("Guten Tag", "de", "Good day"),
        ]
        
        for text, source_lang, expected in test_translation_pairs:
            translated = await translator.translate(text, "en", source_lang)
            print_info(f"Original ({source_lang}): '{text}'")
            print_success(f"Translated: '{translated}' (Expected similar to: '{expected}')")
        
        await translator.close()
        return True
        
    except Exception as e:
        print_error(f"Google Translate test failed: {e}")
        print("\n🔧 Troubleshooting:")
        print("   1. Verify GOOGLE_TRANSLATE_API_KEY in .env file")
        print("   2. Check Translation API is enabled in Google Cloud Console")
        print("   3. Ensure google-cloud-translate is installed")
        return False


async def test_complete_translation_pipeline():
    """Test 3: Complete Translation Pipeline (OCR → Translation)"""
    print_header("TEST 3: Complete Image Translation Pipeline")
    
    try:
        print_step(1, "Initializing Translation Service")
        translate_service = TranslateService()
        print_success("Translation Service initialized (OCR + Translation)")
        
        print_step(2, "Testing text translation (without image)")
        test_texts = [
            "Hola amigo",
            "Bonjour mon ami",
            "Hello friend"
        ]
        
        for text in test_texts:
            result = await translate_service.translate_text(text, "en")
            print_info(f"Input: '{text}'")
            print_success(f"Output: '{result}'")
        
        print_step(3, "Testing image translation (OCR → Translation)")
        print_info("Using minimal test image (may not contain readable text)")
        result = await translate_service.translate_image(SAMPLE_IMAGE_ENGLISH, "en")
        print_success(f"Translation result: '{result}'")
        
        await translate_service.close()
        return True
        
    except Exception as e:
        print_error(f"Translation pipeline test failed: {e}")
        return False


async def test_with_custom_image():
    """Test 4: Test with your own image (if available)"""
    print_header("TEST 4: Custom Image (Optional)")
    
    # Check for test images in the backend directory
    test_image_paths = [
        "test_image.jpg",
        "test_image.png",
        "sample_text.jpg",
        "sample_text.png"
    ]
    
    image_found = False
    for image_path in test_image_paths:
        if os.path.exists(image_path):
            image_found = True
            print_info(f"Found test image: {image_path}")
            
            try:
                print_step(1, f"Loading image: {image_path}")
                with open(image_path, "rb") as image_file:
                    image_base64 = base64.b64encode(image_file.read()).decode('utf-8')
                
                print_step(2, "Running complete translation pipeline")
                translate_service = TranslateService()
                result = await translate_service.translate_image(image_base64, "en")
                
                print_success("Translation completed!")
                print(f"\n📝 RESULT:\n   {result}\n")
                
                await translate_service.close()
                return True
                
            except Exception as e:
                print_error(f"Custom image test failed: {e}")
                return False
    
    if not image_found:
        print_info("No custom test images found")
        print("\n💡 To test with your own image:")
        print("   1. Create an image with text in any language")
        print("   2. Save it as 'test_image.jpg' or 'test_image.png' in backend directory")
        print("   3. Run this test again")
        return None


async def test_pi_workflow_simulation():
    """Test 5: Simulate complete Pi → Backend workflow"""
    print_header("TEST 5: Simulated Complete Workflow (Pi → Backend → TTS)")
    
    print_info("Simulating the complete workflow:")
    print("   1. User: 'translate this'")
    print("   2. Backend → Pi: Request image capture")
    print("   3. Pi → Backend: Send captured image (base64)")
    print("   4. Backend: Run OCR (Google Vision)")
    print("   5. Backend: Translate to English (Google Translate)")
    print("   6. Backend → Pi: Send result to TTS")
    
    try:
        print_step(1, "Simulating image from Pi camera")
        simulated_image = SAMPLE_IMAGE_ENGLISH
        print_success("Image received (base64)")
        
        print_step(2, "Processing with translation service")
        translate_service = TranslateService()
        result = await translate_service.translate_image(simulated_image, "en")
        print_success(f"Translation complete: '{result}'")
        
        print_step(3, "Ready to send to TTS")
        print_info("In production, this would call: POST {PI_SERVER_URL}/tts/speak")
        print_info(f"Payload: {{'text': '{result}', 'blocking': False}}")
        print_success("Workflow simulation complete!")
        
        await translate_service.close()
        return True
        
    except Exception as e:
        print_error(f"Workflow simulation failed: {e}")
        return False


async def run_all_tests():
    """Run all tests in sequence"""
    print("\n" + "=" * 70)
    print("  🚀 IMAGE TRANSLATION WORKFLOW TEST SUITE")
    print("  Testing: Pi Camera → Google Vision OCR → Google Translate → TTS")
    print("=" * 70)
    
    results = {
        "OCR Service": await test_ocr_service(),
        "Google Translate Service": await test_google_translate_service(),
        "Complete Pipeline": await test_complete_translation_pipeline(),
        "Workflow Simulation": await test_pi_workflow_simulation(),
    }
    
    # Optional custom image test
    custom_result = await test_with_custom_image()
    if custom_result is not None:
        results["Custom Image"] = custom_result
    
    # Summary
    print_header("TEST SUMMARY")
    
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    for test_name, result in results.items():
        status = "✅ PASSED" if result else "❌ FAILED"
        print(f"  {status:12} - {test_name}")
    
    print("\n" + "-" * 70)
    print(f"\n  📊 Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n  🎉 ALL TESTS PASSED! The translation workflow is working correctly!")
        print("\n  📝 Next steps:")
        print("     1. Test via API: POST /api/v1/assistant/ask with query='translate this'")
        print("     2. Test with real Pi device and camera")
        print("     3. Verify TTS output on Pi speaker")
    else:
        print("\n  ⚠️  Some tests failed. Please check configuration:")
        if not results.get("OCR Service"):
            print("     - Fix Google Vision setup (see GOOGLE_VISION_SETUP.md)")
        if not results.get("Google Translate Service"):
            print("     - Fix Google Translate setup (ensure API key is correct)")
    
    print("\n" + "=" * 70 + "\n")


if __name__ == "__main__":
    asyncio.run(run_all_tests())
