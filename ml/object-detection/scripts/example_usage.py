"""Example script showing how to use the Object Detection API."""
import base64
import requests
import json
from pathlib import Path


def encode_image_to_base64(image_path: str) -> str:
    """Encode an image file to Base64.
    
    Args:
        image_path: Path to image file
        
    Returns:
        Base64-encoded image string
    """
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode()


def detect_objects(image_path: str, confidence_threshold: float = 0.5):
    """Send image to object detection service and print results.
    
    Args:
        image_path: Path to image file
        confidence_threshold: Minimum confidence score (0-1)
    """
    print("=" * 60)
    print("Object Detection API Example")
    print("=" * 60)
    print()
    
    # Verify image exists
    if not Path(image_path).exists():
        print(f"✗ Image file not found: {image_path}")
        return
    
    print(f"Image: {image_path}")
    print(f"Confidence threshold: {confidence_threshold}")
    print()
    
    # Encode image
    print("Encoding image to Base64...")
    image_base64 = encode_image_to_base64(image_path)
    print(f"✓ Image encoded ({len(image_base64)} characters)")
    print()
    
    # Send request
    print("Sending request to object detection service...")
    print("Endpoint: POST http://127.0.0.1:8001/api/v1/objects/detect")
    print()
    
    try:
        response = requests.post(
            "http://127.0.0.1:8001/api/v1/objects/detect",
            json={
                "image_base64": image_base64,
                "confidence_threshold": confidence_threshold
            },
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            
            print("✓ Detection successful!")
            print()
            print(f"Inference time: {result['inference_time_ms']:.2f}ms")
            print(f"Objects detected: {result['total_detections']}")
            print()
            
            if result['detected_objects']:
                print("Detected Objects:")
                print("-" * 60)
                
                for i, obj in enumerate(result['detected_objects'], 1):
                    print(f"\n{i}. {obj['label'].upper()}")
                    print(f"   Description: {obj['position_description']}")
                    print(f"   Confidence: {obj['confidence']:.2%}")
                    print(f"   Position: {obj['relative_position']['horizontal']} / {obj['relative_position']['vertical']}")
                    print(f"   Bounding Box: x={obj['bounding_box']['x']:.1f}, y={obj['bounding_box']['y']:.1f}, "
                          f"w={obj['bounding_box']['width']:.1f}, h={obj['bounding_box']['height']:.1f}")
            else:
                print("No objects detected.")
            
            print()
            print("-" * 60)
            print("Full JSON Response:")
            print(json.dumps(result, indent=2))
        
        else:
            print(f"✗ Request failed with status {response.status_code}")
            print("Response:")
            print(json.dumps(response.json(), indent=2))
    
    except requests.exceptions.ConnectionError:
        print("✗ Connection failed!")
        print("Make sure the object detection service is running:")
        print("  python -m src.main")
    
    except Exception as e:
        print(f"✗ Error: {str(e)}")


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        image_file = sys.argv[1]
        confidence = float(sys.argv[2]) if len(sys.argv) > 2 else 0.5
        detect_objects(image_file, confidence)
    else:
        print("Usage: python example_usage.py <image_path> [confidence_threshold]")
        print()
        print("Example:")
        print("  python example_usage.py sample.jpg")
        print("  python example_usage.py sample.jpg 0.6")
