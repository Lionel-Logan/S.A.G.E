#!/usr/bin/env python3
"""
Test script to check available Pi Camera controls
"""
from picamera2 import Picamera2
import json

print("Initializing camera...")
camera = Picamera2()
camera.start()

print("\n" + "="*60)
print("AVAILABLE CAMERA CONTROLS")
print("="*60)

# Get camera controls
controls = camera.camera_controls

print("\nAll available controls:")
for control_name, control_info in sorted(controls.items()):
    print(f"\n{control_name}:")
    for key, value in control_info.items():
        print(f"  {key}: {value}")

print("\n" + "="*60)
print("TESTING CONTROL CHANGES")
print("="*60)

# Test setting some controls
test_controls = {
    "ExposureTime": 10000,  # 10ms in microseconds
    "AnalogueGain": 2.0,    # ISO ~200
    "Brightness": 0.1,      # +10% brightness
    "Contrast": 1.2,        # +20% contrast
    "Sharpness": 1.5,       # +50% sharpness
}

print("\nTesting control setting:")
for control, value in test_controls.items():
    try:
        camera.set_controls({control: value})
        print(f"✓ {control} = {value}")
    except Exception as e:
        print(f"✗ {control} failed: {e}")

print("\n" + "="*60)
print("CURRENT METADATA")
print("="*60)

# Capture and show metadata
import time
time.sleep(0.5)  # Let controls take effect
metadata = camera.capture_metadata()

print("\nCurrent camera metadata:")
for key, value in sorted(metadata.items()):
    print(f"  {key}: {value}")

camera.stop()
camera.close()
print("\nTest complete!")
