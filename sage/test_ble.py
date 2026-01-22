#!/usr/bin/env python3
"""
SAGE BLE Test Script
Tests BLE advertising and GATT service
"""

import subprocess
import sys
import time

def run_command(cmd, description):
    """Run command and print result"""
    print(f"\n{'='*60}")
    print(f"{description}")
    print(f"{'='*60}")
    print(f"Command: {' '.join(cmd)}")
    print()
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        print(result.stdout)
        if result.stderr:
            print("STDERR:", result.stderr)
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        print("Command timed out")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    print("SAGE BLE System Test")
    print("=" * 60)
    
    # Check Bluetooth status
    run_command(['systemctl', 'status', 'bluetooth', '--no-pager'], 
                "1. Bluetooth Service Status")
    
    # Check if adapter is up
    run_command(['hciconfig'], 
                "2. Bluetooth Adapter Status")
    
    # Check if BLE service is running
    run_command(['systemctl', 'status', 'sage-ble', '--no-pager'], 
                "3. SAGE BLE Service Status")
    
    # Show recent logs
    run_command(['journalctl', '-u', 'sage-ble', '-n', '50', '--no-pager'], 
                "4. Recent Service Logs")
    
    # Scan for nearby devices (to test if BLE is working)
    print("\n" + "="*60)
    print("5. Testing BLE Scan (5 seconds)")
    print("="*60)
    print("Starting BLE scan...")
    
    proc = subprocess.Popen(['timeout', '5', 'hcitool', 'lescan'], 
                           stdout=subprocess.PIPE, 
                           stderr=subprocess.PIPE)
    
    time.sleep(6)
    stdout, stderr = proc.communicate()
    
    if stdout:
        print(stdout.decode())
    if stderr:
        print("STDERR:", stderr.decode())
    
    # Show D-Bus services
    run_command(['busctl', 'tree', 'org.bluez'], 
                "6. BlueZ D-Bus Services")
    
    print("\n" + "="*60)
    print("Test Complete!")
    print("="*60)
    print("\nTo view live logs: sudo journalctl -u sage-ble -f")
    print("To restart service: sudo systemctl restart sage-ble")
    print("To test from Android: Use nRF Connect app and scan for 'SAGE Glass X1'")
    print()

if __name__ == '__main__':
    main()
