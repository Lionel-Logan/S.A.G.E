# SAGE Glass BLE Pairing Setup Guide

## Overview
This guide explains how to configure BLE (Bluetooth Low Energy) pairing between your Android phone and Raspberry Pi running SAGE Glass.

## Prerequisites
- Android device running Android 12+ (API level 31+)
- Raspberry Pi with Bluetooth LE support
- Flutter development environment set up

## BLE Service Configuration

### GATT Service UUIDs
The app expects your Raspberry Pi to advertise a BLE GATT service with the following UUIDs:

```dart
// Update these in bluetooth_service.dart to match your Pi implementation
static const String credentialsServiceUuid = '12345678-1234-5678-1234-56789abcdef0';
static const String credentialsCharacteristicUuid = '12345678-1234-5678-1234-56789abcdef1';
static const String statusCharacteristicUuid = '12345678-1234-5678-1234-56789abcdef2';
```

### Raspberry Pi BLE Server Setup

Your Raspberry Pi must implement a BLE GATT server with:

1. **Service UUID**: `12345678-1234-5678-1234-56789abcdef0`
2. **Credentials Characteristic** (UUID: `12345678-1234-5678-1234-56789abcdef1`):
   - Properties: WRITE or WRITE_WITHOUT_RESPONSE
   - Receives JSON: `{"ssid":"your-hotspot-name","password":"your-password"}`
3. **Status Characteristic** (UUID: `12345678-1234-5678-1234-56789abcdef2`):
   - Properties: READ or NOTIFY
   - Returns connection status

### Example Python BLE Server (Raspberry Pi)

```python
import dbus
import dbus.mainloop.glib
from gi.repository import GLib
from bluez_peripheral.gatt.service import Service
from bluez_peripheral.gatt.characteristic import characteristic, Characteristic
from bluez_peripheral.util import *

class CredentialsCharacteristic(Characteristic):
    def __init__(self, service):
        super().__init__(
            '12345678-1234-5678-1234-56789abcdef1',
            ['write', 'write-without-response'],
            service
        )
    
    def WriteValue(self, value, options):
        import json
        data = ''.join(chr(b) for b in value)
        credentials = json.loads(data)
        
        ssid = credentials.get('ssid')
        password = credentials.get('password')
        
        # Connect to WiFi hotspot
        print(f"Received credentials - SSID: {ssid}")
        # Implement your WiFi connection logic here
        
        return []

class SAGEGlassService(Service):
    def __init__(self):
        super().__init__(
            '12345678-1234-5678-1234-56789abcdef0',
            True  # Primary service
        )
        self.add_characteristic(CredentialsCharacteristic(self))

# Initialize and advertise
# ... (complete implementation in your Pi backend)
```

## Android Configuration

### Permissions (Already Added)
The following permissions are configured in `AndroidManifest.xml`:

✅ `BLUETOOTH_SCAN` - Discover BLE devices
✅ `BLUETOOTH_CONNECT` - Connect to BLE devices  
✅ `BLUETOOTH_ADVERTISE` - Advertise BLE services
✅ `ACCESS_FINE_LOCATION` - Required for BLE scanning
✅ `ACCESS_COARSE_LOCATION` - Required for BLE scanning

### Minimum SDK
- **minSdk**: 31 (Android 12)
- **targetSdk**: 34 (Android 14)

## Device Naming Convention

Your Raspberry Pi should advertise with a device name starting with **"SAGE"**:
- Examples: "SAGE Glass X1", "SAGE_Pi_001", etc.
- The app filters devices by this prefix

## Pairing Flow

### Auto Mode:
1. ✅ Request BLE permissions
2. ✅ Check Bluetooth enabled
3. ✅ Scan for devices (30s timeout)
4. ✅ Connect to first SAGE device found
5. ✅ Auto-detect hotspot credentials (or prompt user)
6. ✅ Send credentials via BLE GATT write
7. ⚠️ User enables WiFi hotspot manually (Android 12+ restriction)
8. ✅ Wait for Pi to connect to hotspot
9. ✅ Verify connection and save pairing

### Manual Mode:
- User selects device from scan results
- User enters hotspot credentials manually
- Same process as auto mode from step 6

## Testing

### Enable Mock Mode (for testing without hardware):
```dart
// In bluetooth_service.dart
static bool useMockMode = true;  // Set to false for production

// In wifi_hotspot_service.dart
static bool useMockMode = true;  // Set to false for production
```

### Production Mode (currently configured):
```dart
static bool useMockMode = false;  // Real BLE communication
```

## Known Limitations

### Android 12+ Hotspot Restrictions
- Apps cannot programmatically enable WiFi hotspot
- User MUST enable hotspot manually via system settings
- App guides user through the process with instructions

### Workaround:
The app displays clear instructions to:
1. Open Settings → Network & Internet → Hotspot & tethering
2. Enable "WiFi hotspot"
3. Return to the app

## Troubleshooting

### BLE Not Scanning
- Ensure location permissions granted
- Check Bluetooth is enabled in system settings
- Verify Pi is advertising and powered on
- Check Pi is within range (< 10m recommended)

### Connection Fails
- Verify GATT service UUIDs match between app and Pi
- Check Pi BLE server is running
- Try power cycling the Pi
- Check Android Bluetooth logs: `adb logcat | grep -i bluetooth`

### Credentials Not Received
- Verify characteristic supports WRITE operations
- Check JSON format is correct
- Enable BLE logging on Pi to see received data
- Ensure characteristic UUID matches exactly

### Hotspot Connection Fails
- Verify user enabled hotspot with exact SSID/password sent
- Check Pi WiFi configuration
- Verify hotspot is 2.4GHz (Pi may not support 5GHz)
- Check firewall/network settings on phone

## Development Commands

```bash
# Clean and rebuild
cd app/frontend
flutter clean
flutter pub get

# Run on Android device
flutter run

# Build release APK
flutter build apk --release

# Check BLE permissions granted
adb shell dumpsys package com.sage.glass.mobile | grep permission
```

## Integration with Backend

Once BLE pairing completes and Pi connects to hotspot, the app communicates via HTTP:

- **Pi Server API**: `http://192.168.122.153:8001` (update in api_service.dart)
- **Backend API**: `http://192.168.122.153:8002`

Ensure these IPs match your network configuration.

## Security Considerations

1. **Encryption**: BLE GATT is encrypted when bonded
2. **Credentials**: Transmitted once during pairing, stored securely
3. **Authentication**: Implement additional auth in your Pi server
4. **Network**: Use WPA2/WPA3 for hotspot encryption

## Next Steps

1. ✅ Update UUIDs in `bluetooth_service.dart` to match your Pi implementation
2. ✅ Implement BLE GATT server on Raspberry Pi
3. ✅ Test pairing flow with real hardware
4. ✅ Configure network settings (API endpoints)
5. ✅ Add additional security measures as needed

## Support

For issues:
1. Check logs: `flutter run` or `adb logcat`
2. Verify Pi BLE server logs
3. Test with BLE scanner app (nRF Connect) to debug Pi advertising
4. Ensure all permissions are granted in Android settings
