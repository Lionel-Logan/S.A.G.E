"""Comprehensive testing script for the Object Detection API."""
import base64
import io
import requests
import json
from pathlib import Path
from PIL import Image


class ObjectDetectionTester:
    """Test runner for the Object Detection API."""
    
    def __init__(self, base_url: str = "http://127.0.0.1:8001"):
        """Initialize tester.
        
        Args:
            base_url: Base URL of the API
        """
        self.base_url = base_url
        self.detect_endpoint = f"{base_url}/api/v1/objects/detect"
        self.health_endpoint = f"{base_url}/api/v1/objects/health"
    
    def test_connection(self) -> bool:
        """Test if server is running and accessible.
        
        Returns:
            True if connection successful, False otherwise
        """
        print("Testing server connection...")
        try:
            response = requests.get(self.health_endpoint, timeout=5)
            if response.status_code == 200:
                data = response.json()
                print(f"✓ Server is running!")
                print(f"  Status: {data.get('status')}")
                print(f"  Model loaded: {data.get('model_loaded')}")
                return True
            else:
                print(f"✗ Server returned status {response.status_code}")
                return False
        except requests.exceptions.ConnectionError:
            print("✗ Cannot connect to server!")
            print(f"  Make sure server is running: python -m uvicorn src.main:app --host 127.0.0.1 --port 8001")
            return False
        except Exception as e:
            print(f"✗ Error: {str(e)}")
            return False
    
    def create_test_image(self) -> str:
        """Create a simple test image and return as Base64.
        
        Returns:
            Base64-encoded image string
        """
        # Create a simple test image with shapes
        img = Image.new("RGB", (640, 480), color=(200, 200, 200))
        from PIL import ImageDraw
        draw = ImageDraw.Draw(img)
        
        # Draw some shapes (testing purposes)
        draw.rectangle([(100, 80), (200, 300)], fill=(255, 0, 0), outline=(0, 0, 0), width=2)
        draw.rectangle([(350, 250), (550, 350)], fill=(0, 0, 255), outline=(0, 0, 0), width=2)
        
        # Convert to Base64
        buffer = io.BytesIO()
        img.save(buffer, format="PNG")
        buffer.seek(0)
        return base64.b64encode(buffer.read()).decode()
    
    def test_detection(self, image_base64: str, confidence_threshold: float = 0.5) -> dict:
        """Run object detection on an image.
        
        Args:
            image_base64: Base64-encoded image
            confidence_threshold: Confidence threshold (0-1)
            
        Returns:
            Response JSON
        """
        print(f"\nRunning detection (confidence: {confidence_threshold})...")
        
        try:
            response = requests.post(
                self.detect_endpoint,
                json={
                    "image_base64": image_base64,
                    "confidence_threshold": confidence_threshold
                },
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"✓ Detection successful!")
                print(f"  Inference time: {result['inference_time_ms']:.2f}ms")
                print(f"  Objects detected: {result['total_detections']}")
                
                if result['detected_objects']:
                    print("\n  Detections:")
                    for i, obj in enumerate(result['detected_objects'], 1):
                        print(f"    {i}. {obj['label']} - {obj['position_description']}")
                        print(f"       Confidence: {obj['confidence']:.2%}")
                
                return result
            else:
                print(f"✗ Request failed with status {response.status_code}")
                print(f"  Response: {response.json()}")
                return None
        
        except requests.exceptions.Timeout:
            print("✗ Request timeout!")
            return None
        except Exception as e:
            print(f"✗ Error: {str(e)}")
            return None
    
    def test_invalid_base64(self) -> bool:
        """Test with invalid Base64.
        
        Returns:
            True if error handling works correctly
        """
        print("\nTesting error handling - Invalid Base64...")
        
        try:
            response = requests.post(
                self.detect_endpoint,
                json={"image_base64": "not_valid_base64!!!"},
                timeout=10
            )
            
            if response.status_code == 400:
                print("✓ Correctly rejected invalid Base64 (HTTP 400)")
                error = response.json()
                print(f"  Error type: {error['detail']['error_type']}")
                return True
            else:
                print(f"✗ Expected HTTP 400, got {response.status_code}")
                return False
        except Exception as e:
            print(f"✗ Error: {str(e)}")
            return False
    
    def test_empty_base64(self) -> bool:
        """Test with empty Base64.
        
        Returns:
            True if error handling works correctly
        """
        print("\nTesting error handling - Empty Base64...")
        
        try:
            response = requests.post(
                self.detect_endpoint,
                json={"image_base64": ""},
                timeout=10
            )
            
            if response.status_code == 400:
                print("✓ Correctly rejected empty Base64 (HTTP 400)")
                return True
            else:
                print(f"✗ Expected HTTP 400, got {response.status_code}")
                return False
        except Exception as e:
            print(f"✗ Error: {str(e)}")
            return False
    
    def test_invalid_confidence_threshold(self) -> bool:
        """Test with invalid confidence threshold.
        
        Returns:
            True if validation works correctly
        """
        print("\nTesting error handling - Invalid confidence threshold...")
        
        try:
            response = requests.post(
                self.detect_endpoint,
                json={
                    "image_base64": base64.b64encode(b"test").decode(),
                    "confidence_threshold": 1.5  # Invalid
                },
                timeout=10
            )
            
            if response.status_code in [400, 422]:
                print(f"✓ Correctly rejected invalid threshold (HTTP {response.status_code})")
                return True
            else:
                print(f"✗ Expected HTTP 400 or 422, got {response.status_code}")
                return False
        except Exception as e:
            print(f"✗ Error: {str(e)}")
            return False
    
    def test_different_thresholds(self, image_base64: str) -> list:
        """Test with different confidence thresholds.
        
        Args:
            image_base64: Base64-encoded image
            
        Returns:
            List of results
        """
        print("\nTesting with different confidence thresholds...")
        results = []
        
        for threshold in [0.3, 0.5, 0.7, 0.9]:
            result = self.test_detection(image_base64, confidence_threshold=threshold)
            if result:
                results.append({
                    "threshold": threshold,
                    "detections": result['total_detections'],
                    "inference_time": result['inference_time_ms']
                })
        
        return results
    
    def run_full_test_suite(self, test_image_path: str = None) -> dict:
        """Run complete test suite.
        
        Args:
            test_image_path: Path to test image (optional)
            
        Returns:
            Test results summary
        """
        print("=" * 60)
        print("Object Detection API - Full Test Suite")
        print("=" * 60)
        print()
        
        results = {
            "connection": False,
            "detection": False,
            "error_handling": False,
            "threshold_testing": False
        }
        
        # Test 1: Connection
        results["connection"] = self.test_connection()
        if not results["connection"]:
            print("\n✗ Server not running. Cannot continue tests.")
            return results
        
        # Test 2: Basic detection
        print("\n" + "-" * 60)
        if test_image_path and Path(test_image_path).exists():
            print(f"Loading test image: {test_image_path}")
            with open(test_image_path, "rb") as f:
                image_base64 = base64.b64encode(f.read()).decode()
        else:
            print("Creating test image...")
            image_base64 = self.create_test_image()
        
        detection_result = self.test_detection(image_base64)
        results["detection"] = detection_result is not None
        
        # Test 3: Error handling
        print("\n" + "-" * 60)
        print("Error Handling Tests:")
        invalid_base64 = self.test_invalid_base64()
        empty_base64 = self.test_empty_base64()
        invalid_threshold = self.test_invalid_confidence_threshold()
        results["error_handling"] = all([invalid_base64, empty_base64, invalid_threshold])
        
        # Test 4: Threshold testing
        print("\n" + "-" * 60)
        if results["detection"]:
            threshold_results = self.test_different_thresholds(image_base64)
            results["threshold_testing"] = len(threshold_results) > 0
            
            if threshold_results:
                print("\nThreshold Results Summary:")
                print(f"{'Threshold':<12} {'Detections':<15} {'Inference (ms)':<15}")
                print("-" * 42)
                for r in threshold_results:
                    print(f"{r['threshold']:<12} {r['detections']:<15} {r['inference_time']:<15.2f}")
        
        # Summary
        print("\n" + "=" * 60)
        print("Test Summary")
        print("=" * 60)
        print(f"Connection Test: {'✓ PASS' if results['connection'] else '✗ FAIL'}")
        print(f"Detection Test: {'✓ PASS' if results['detection'] else '✗ FAIL'}")
        print(f"Error Handling: {'✓ PASS' if results['error_handling'] else '✗ FAIL'}")
        print(f"Threshold Testing: {'✓ PASS' if results['threshold_testing'] else '✗ SKIP (no detection)'}")
        print()
        
        passed = sum(1 for v in results.values() if v)
        total = len([v for v in results.values() if v is not None])
        print(f"Overall: {passed}/{total} tests passed")
        print("=" * 60)
        print()
        
        return results


def main():
    """Run the test suite."""
    import sys
    
    tester = ObjectDetectionTester()
    
    # Check if test image path provided
    test_image = None
    if len(sys.argv) > 1:
        test_image = sys.argv[1]
    
    results = tester.run_full_test_suite(test_image)


if __name__ == "__main__":
    main()
