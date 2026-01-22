#!/usr/bin/env python3
"""
SAGE Glass BLE GATT Server Example for Raspberry Pi
This script creates a BLE GATT server that the SAGE mobile app can connect to for pairing.

Requirements:
    pip install bluez-peripheral

Based on: https://github.com/spacecheese/bluez_peripheral
"""

import json
import subprocess
import time
import dbus
import dbus.mainloop.glib
from gi.repository import GLib

# You may need to install bluez-peripheral library
# For a complete implementation, use this as a starting point

# Service and Characteristic UUIDs (must match bluetooth_service.dart)
CREDENTIALS_SERVICE_UUID = '12345678-1234-5678-1234-56789abcdef0'
CREDENTIALS_CHAR_UUID = '12345678-1234-5678-1234-56789abcdef1'
STATUS_CHAR_UUID = '12345678-1234-5678-1234-56789abcdef2'

class SAGEGlassBLEServer:
    """BLE GATT Server for receiving WiFi credentials from mobile app"""
    
    def __init__(self):
        self.ssid = None
        self.password = None
        self.connection_status = "waiting"
        
    def on_credentials_received(self, data):
        """
        Called when mobile app writes credentials to BLE characteristic
        
        Args:
            data: JSON string with format {"ssid": "...", "password": "..."}
        """
        try:
            credentials = json.loads(data)
            self.ssid = credentials.get('ssid')
            self.password = credentials.get('password')
            
            print(f"[BLE] Received credentials")
            print(f"  SSID: {self.ssid}")
            print(f"  Password: {'*' * len(self.password)}")
            
            # Connect to WiFi hotspot
            self.connect_to_wifi()
            
        except json.JSONDecodeError as e:
            print(f"[ERROR] Invalid JSON received: {e}")
        except Exception as e:
            print(f"[ERROR] Failed to process credentials: {e}")
    
    def connect_to_wifi(self):
        """Connect Raspberry Pi to the received WiFi hotspot"""
        if not self.ssid or not self.password:
            print("[ERROR] Missing SSID or password")
            return
        
        try:
            print(f"[WiFi] Connecting to {self.ssid}...")
            self.connection_status = "connecting"
            
            # Method 1: Using nmcli (NetworkManager)
            subprocess.run([
                'nmcli', 'device', 'wifi', 'connect', 
                self.ssid, 'password', self.password
            ], check=True)
            
            self.connection_status = "connected"
            print("[WiFi] Successfully connected!")
            
            # Get IP address
            time.sleep(2)
            result = subprocess.run(['hostname', '-I'], capture_output=True, text=True)
            ip = result.stdout.strip().split()[0]
            print(f"[WiFi] IP Address: {ip}")
            
        except subprocess.CalledProcessError as e:
            print(f"[ERROR] Failed to connect to WiFi: {e}")
            self.connection_status = "failed"
            
            # Method 2: Fallback using wpa_supplicant (if nmcli not available)
            # self.connect_via_wpa_supplicant()
    
    def connect_via_wpa_supplicant(self):
        """Alternative method using wpa_supplicant"""
        wpa_conf = f"""
network={{
    ssid="{self.ssid}"
    psk="{self.password}"
    key_mgmt=WPA-PSK
}}
"""
        try:
            # Write config
            with open('/tmp/wpa_supplicant_temp.conf', 'w') as f:
                f.write(wpa_conf)
            
            # Connect
            subprocess.run([
                'wpa_supplicant', '-B', '-i', 'wlan0',
                '-c', '/tmp/wpa_supplicant_temp.conf'
            ], check=True)
            
            subprocess.run(['dhclient', 'wlan0'], check=True)
            
            print("[WiFi] Connected via wpa_supplicant")
            self.connection_status = "connected"
            
        except Exception as e:
            print(f"[ERROR] wpa_supplicant method failed: {e}")
            self.connection_status = "failed"


# ============================================================================
# Example using bluez-peripheral library (recommended)
# ============================================================================

"""
# Install: pip install bluez-peripheral

from bluez_peripheral.gatt.service import Service
from bluez_peripheral.gatt.characteristic import characteristic, Characteristic, CharacteristicFlags
from bluez_peripheral.advert import Advertisement
from bluez_peripheral.agent import NoIoAgent

server = SAGEGlassBLEServer()

class CredentialsCharacteristic(Characteristic):
    def __init__(self, service):
        super().__init__(
            CREDENTIALS_CHAR_UUID,
            [CharacteristicFlags.WRITE, CharacteristicFlags.WRITE_WITHOUT_RESPONSE],
            service
        )
    
    @characteristic(
        CREDENTIALS_CHAR_UUID,
        [CharacteristicFlags.WRITE, CharacteristicFlags.WRITE_WITHOUT_RESPONSE]
    )
    def credentials_char(self, options):
        # This will be called on write
        pass
    
    def WriteValue(self, value, options):
        # Decode bytes to string
        data = bytes(value).decode('utf-8')
        server.on_credentials_received(data)
        return []


class StatusCharacteristic(Characteristic):
    def __init__(self, service):
        super().__init__(
            STATUS_CHAR_UUID,
            [CharacteristicFlags.READ, CharacteristicFlags.NOTIFY],
            service
        )
    
    def ReadValue(self, options):
        # Return current status
        status_json = json.dumps({
            'status': server.connection_status
        })
        return [dbus.Byte(c) for c in status_json.encode()]


class SAGEService(Service):
    def __init__(self):
        super().__init__(
            CREDENTIALS_SERVICE_UUID,
            True  # Primary service
        )
        self.add_characteristic(CredentialsCharacteristic(self))
        self.add_characteristic(StatusCharacteristic(self))


def main():
    # Initialize DBus
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    
    # Create advertisement
    advert = Advertisement(
        'SAGE Glass X1',  # Device name (must start with "SAGE")
        [CREDENTIALS_SERVICE_UUID],
        0x0340,  # Appearance: Generic Computer
        60  # Timeout
    )
    
    # Create service
    service = SAGEService()
    
    # Register agent (for pairing)
    agent = NoIoAgent()
    
    # Start advertising
    print("[BLE] Starting SAGE Glass BLE server...")
    print(f"[BLE] Device name: SAGE Glass X1")
    print(f"[BLE] Service UUID: {CREDENTIALS_SERVICE_UUID}")
    
    advert.register()
    service.register()
    agent.register()
    
    print("[BLE] Server ready, waiting for connections...")
    
    # Run main loop
    try:
        GLib.MainLoop().run()
    except KeyboardInterrupt:
        print("\n[BLE] Shutting down...")

if __name__ == '__main__':
    main()
"""

# ============================================================================
# Simpler example using PyBluez or Bleak (alternative)
# ============================================================================

print("""
SAGE Glass BLE Server Setup Instructions:

1. Install dependencies:
   sudo apt-get update
   sudo apt-get install -y bluetooth bluez python3-pip
   pip3 install bluez-peripheral

2. Enable Bluetooth:
   sudo systemctl enable bluetooth
   sudo systemctl start bluetooth

3. Configure Bluetooth adapter:
   sudo hciconfig hci0 up
   sudo hciconfig hci0 piscan

4. Update UUIDs in this script to match your mobile app

5. Run the script:
   sudo python3 RASPBERRY_PI_BLE_EXAMPLE.py

6. The mobile app should now be able to discover and connect

For complete implementation, see bluez-peripheral documentation:
https://github.com/spacecheese/bluez_peripheral
""")

# Minimal working example for testing
if __name__ == '__main__':
    server = SAGEGlassBLEServer()
    
    # Simulate receiving credentials (for testing)
    test_credentials = '{"ssid":"TestHotspot","password":"test12345"}'
    server.on_credentials_received(test_credentials)
