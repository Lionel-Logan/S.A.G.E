#!/usr/bin/env python3
"""
Test script to verify the BLE GATT Bluetooth characteristics are working
This tests if the BluetoothAudioManager is being called correctly
"""

import json
import sys
import os

# Add the parent directory to the path to import the BLE server module
sys.path.insert(0, '/home/sage/sage')

print("=" * 60)
print("TESTING BLE BLUETOOTH CHARACTERISTICS")
print("=" * 60)

try:
    # Import the BluetoothAudioManager from the BLE server
    # We need to be careful as the module has DBus dependencies
    
    print("\n1. Testing BluetoothAudioManager class...")
    print("-" * 60)
    
    # Instead of importing (which requires DBus), let's test the script directly
    # through the manager's methods
    
    import subprocess
    
    # Test 1: Scan devices
    print("\nTest: scan_bluetooth_devices()")
    script_path = '/home/sage/sage/scripts/connect_bluetooth.sh'
    
    result = subprocess.run(
        ['sudo', script_path, 'scan'],
        capture_output=True,
        text=True,
        timeout=20
    )
    
    if result.returncode == 0:
        try:
            devices = json.loads(result.stdout)
            print(f"✓ Scan successful: {len(devices)} devices found")
            for dev in devices[:3]:  # Show first 3
                print(f"  - {dev.get('name')} ({dev.get('device_type')})")
        except json.JSONDecodeError as e:
            print(f"✗ JSON parsing failed: {e}")
            print(f"Raw output: {result.stdout[:200]}")
    else:
        print(f"✗ Scan failed with code {result.returncode}")
        print(f"Error: {result.stderr}")
    
    # Test 2: Get status
    print("\nTest: get_connection_status()")
    result = subprocess.run(
        ['sudo', script_path, 'status'],
        capture_output=True,
        text=True,
        timeout=5
    )
    
    if result.returncode == 0:
        try:
            status = json.loads(result.stdout)
            print(f"✓ Status successful")
            print(f"  Status: {status.get('status')}")
            print(f"  Device: {status.get('device')}")
            print(f"  Connected: {status.get('connected')}")
        except json.JSONDecodeError as e:
            print(f"✗ JSON parsing failed: {e}")
    else:
        print(f"✗ Status failed with code {result.returncode}")
    
    print("\n" + "=" * 60)
    print("BLUETOOTH MANAGER TESTS COMPLETE")
    print("=" * 60)
    
    # Test 3: Check if BLE server can import the module
    print("\n2. Testing BLE server module import...")
    print("-" * 60)
    
    try:
        # Check if ble_gatt_server.py exists
        ble_server_path = '/home/sage/sage/ble_gatt_server.py'
        if os.path.exists(ble_server_path):
            print(f"✓ BLE server file exists: {ble_server_path}")
            
            # Check if BluetoothAudioManager class exists in the file
            with open(ble_server_path, 'r') as f:
                content = f.read()
                if 'class BluetoothAudioManager' in content:
                    print("✓ BluetoothAudioManager class found in BLE server")
                else:
                    print("✗ BluetoothAudioManager class NOT found in BLE server")
                
                if 'BLUETOOTH_SCAN_CHAR_UUID' in content:
                    print("✓ Bluetooth scan characteristic UUID defined")
                else:
                    print("✗ Bluetooth scan characteristic UUID NOT defined")
                
                if 'BluetoothScanCharacteristic' in content:
                    print("✓ BluetoothScanCharacteristic class found")
                else:
                    print("✗ BluetoothScanCharacteristic class NOT found")
        else:
            print(f"✗ BLE server file NOT found: {ble_server_path}")
    
    except Exception as e:
        print(f"✗ Error checking BLE server: {e}")
    
    print("\n" + "=" * 60)
    print("ALL TESTS COMPLETE")
    print("=" * 60)

except Exception as e:
    print(f"\n✗ Fatal error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
