#!/usr/bin/env python3
"""
Test script to verify the Bluetooth scan bash script returns data
"""

import subprocess
import json
import sys

print("=" * 60)
print("TESTING BLUETOOTH SCAN SCRIPT")
print("=" * 60)

script_path = '/home/sage/sage/scripts/connect_bluetooth.sh'

print(f"\n1. Testing script execution: {script_path}")
print("-" * 60)

try:
    # Run the scan command
    print("Running: sudo {} scan".format(script_path))
    result = subprocess.run(
        ['sudo', script_path, 'scan'],
        capture_output=True,
        text=True,
        timeout=20
    )
    
    print(f"\nReturn code: {result.returncode}")
    print(f"\nSTDERR (debug output):")
    print(result.stderr)
    print(f"\nSTDOUT (JSON data):")
    print(result.stdout)
    
    # Try to parse JSON
    if result.stdout.strip():
        try:
            devices = json.loads(result.stdout)
            print(f"\n✓ JSON is valid!")
            print(f"✓ Found {len(devices)} devices")
            
            if devices:
                print("\nDevices found:")
                for i, dev in enumerate(devices, 1):
                    print(f"  {i}. {dev.get('name', 'Unknown')} ({dev.get('mac', 'N/A')})")
                    print(f"     Type: {dev.get('device_type', 'unknown')}, Class: {dev.get('device_class', 'N/A')}")
                    print(f"     RSSI: {dev.get('rssi', 'N/A')}, Paired: {dev.get('paired', False)}")
            else:
                print("\n⚠ No devices found")
        except json.JSONDecodeError as e:
            print(f"\n✗ JSON parsing failed: {e}")
            print("Output is not valid JSON")
    else:
        print("\n✗ No output received from script")
    
    print("\n" + "=" * 60)
    print("TEST COMPLETE")
    print("=" * 60)
    
except subprocess.TimeoutExpired:
    print("\n✗ Script timeout (20 seconds)")
    sys.exit(1)
except Exception as e:
    print(f"\n✗ Error: {e}")
    sys.exit(1)
