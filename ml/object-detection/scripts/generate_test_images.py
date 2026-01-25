"""Generate test images and Base64 encodings for API testing."""
import base64
import io
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json


def create_test_image_with_objects(filename: str, output_base64: bool = False) -> str:
    """Create a test image with simple drawn objects.
    
    Args:
        filename: Output filename
        output_base64: If True, return Base64 string instead of saving
        
    Returns:
        Base64 string if output_base64=True, otherwise filename
    """
    # Create image
    width, height = 640, 480
    img = Image.new("RGB", (width, height), color=(200, 200, 200))
    draw = ImageDraw.Draw(img)
    
    # Draw red rectangle (simulating a person)
    draw.rectangle(
        [(100, 80), (200, 300)],
        fill=(255, 0, 0),
        outline=(0, 0, 0),
        width=2
    )
    
    # Draw blue rectangle (simulating a car)
    draw.rectangle(
        [(350, 250), (550, 350)],
        fill=(0, 0, 255),
        outline=(0, 0, 0),
        width=2
    )
    
    # Draw green circle (simulating a ball/object)
    draw.ellipse(
        [(500, 100), (600, 200)],
        fill=(0, 255, 0),
        outline=(0, 0, 0),
        width=2
    )
    
    # Add labels
    draw.text((110, 320), "Person", fill=(0, 0, 0))
    draw.text((370, 360), "Car", fill=(0, 0, 0))
    draw.text((510, 210), "Object", fill=(0, 0, 0))
    
    if output_base64:
        # Save to bytes and encode
        buffer = io.BytesIO()
        img.save(buffer, format="PNG")
        buffer.seek(0)
        return base64.b64encode(buffer.read()).decode()
    else:
        # Save to file
        img.save(filename)
        return filename


def create_solid_color_image(filename: str, color: tuple = (100, 150, 200)) -> str:
    """Create a solid color test image.
    
    Args:
        filename: Output filename
        color: RGB color tuple
        
    Returns:
        Filename
    """
    img = Image.new("RGB", (640, 480), color=color)
    img.save(filename)
    return filename


def encode_image_file(filepath: str) -> str:
    """Encode an existing image file to Base64.
    
    Args:
        filepath: Path to image file
        
    Returns:
        Base64-encoded string
    """
    with open(filepath, "rb") as f:
        return base64.b64encode(f.read()).decode()


def main():
    """Generate test images and create a testing guide."""
    print("=" * 60)
    print("Test Image Generator for Object Detection API")
    print("=" * 60)
    print()
    
    # Create test images directory
    test_dir = Path("tests/sample_images")
    test_dir.mkdir(parents=True, exist_ok=True)
    
    print("Generating test images...")
    print()
    
    # Test 1: Image with drawn objects
    print("1. Creating test image with objects...")
    img_path = test_dir / "objects.png"
    create_test_image_with_objects(str(img_path))
    print(f"   ✓ Created: {img_path}")
    
    # Test 2: Solid color image (no objects)
    print("2. Creating solid color image...")
    color_path = test_dir / "solid_color.jpg"
    create_solid_color_image(str(color_path))
    print(f"   ✓ Created: {color_path}")
    
    # Test 3: Another test image
    print("3. Creating another test image...")
    img_path2 = test_dir / "objects2.png"
    create_test_image_with_objects(str(img_path2))
    print(f"   ✓ Created: {img_path2}")
    
    print()
    print("=" * 60)
    print("Base64 Encodings for API Testing")
    print("=" * 60)
    print()
    
    # Generate Base64 strings
    test_cases = {}
    
    for image_file in test_dir.glob("*"):
        if image_file.suffix.lower() in ['.jpg', '.jpeg', '.png']:
            name = image_file.stem
            print(f"Encoding {image_file.name}...")
            base64_str = encode_image_file(str(image_file))
            test_cases[name] = {
                "file": str(image_file),
                "base64": base64_str[:100] + "..." if len(base64_str) > 100 else base64_str,
                "full_base64": base64_str
            }
            print(f"   ✓ Length: {len(base64_str)} characters")
            print()
    
    # Save test cases to JSON
    test_config_path = test_dir / "test_cases.json"
    
    # Create a more readable version without full base64 in the summary
    summary = {
        name: {
            "file": info["file"],
            "base64_length": len(info["full_base64"])
        }
        for name, info in test_cases.items()
    }
    
    with open(test_config_path, "w") as f:
        json.dump(summary, f, indent=2)
    
    print("=" * 60)
    print("Testing Instructions")
    print("=" * 60)
    print()
    print("1. Start the server:")
    print("   python -m uvicorn src.main:app --host 127.0.0.1 --port 8001")
    print()
    print("2. Use Python script to test:")
    print()
    print("   from scripts.generate_test_images import encode_image_file")
    print("   import requests")
    print()
    print("   # Encode image")
    print("   base64_str = encode_image_file('tests/sample_images/objects.png')")
    print()
    print("   # Send request")
    print("   response = requests.post(")
    print("       'http://127.0.0.1:8001/api/v1/objects/detect',")
    print("       json={")
    print("           'image_base64': base64_str,")
    print("           'confidence_threshold': 0.5")
    print("       }")
    print("   )")
    print("   print(response.json())")
    print()
    print("3. Or use Swagger UI at:")
    print("   http://127.0.0.1:8001/docs")
    print()
    print("=" * 60)
    print()
    print("✓ Test images generated successfully!")
    print(f"  Location: {test_dir}")
    print()
    
    # Print sample Base64 for manual testing (first 50 chars)
    if test_cases:
        first_case = list(test_cases.items())[0]
        print("Sample Base64 for manual testing (first case):")
        print(f"File: {first_case[0]}")
        print(f"Base64 (first 100 chars): {first_case[1]['base64']}")
        print()


if __name__ == "__main__":
    main()
