# Network Configuration Flow

## Overview
The pairing and network configuration have been separated into two distinct processes for better flexibility and user experience.

## New Flow

### 1. **BLE Pairing** (First Time Setup)
- **Steps:**
  1. Scan for SAGE Glass devices via BLE
  2. Connect to device via BLE
  3. Save paired device information
  4. Navigate to Dashboard

- **What's Saved:** Only the device ID and name
- **No WiFi Required:** Pairing completes without any network configuration

### 2. **Network Configuration** (Dashboard → Settings → Network)
- **Access:** From the dashboard, go to Settings → Network Settings
- **Steps:**
  1. Enter WiFi network SSID (name)
  2. Enter WiFi password
  3. Click "Send to Glass"
  4. App sends credentials to Pi via BLE
  5. Pi attempts to connect to the network

- **What Happens:**
  - ✅ Credentials sent → Pi tries to connect
  - ✅ Connection successful → Pi joins the network
  - ❌ Connection fails → Pi stays disconnected (no false positives)

### 3. **Benefits of This Approach**

**Flexibility:**
- Configure any WiFi network (home, office, mobile hotspot)
- Not limited to phone's hotspot
- Can change networks anytime from settings

**Reliability:**
- No false "pairing complete" messages
- Pi connection status is real
- Can reconfigure if network changes

**User Experience:**
- Clear separation of concerns
- Pairing = BLE setup
- Network = WiFi setup
- Easy to troubleshoot

## Usage

### Initial Setup
```dart
1. Run pairing flow
2. Once paired, navigate to dashboard
3. Go to Settings → Network Settings
4. Enter WiFi credentials
5. Send to Glass
```

### Changing Networks
```dart
1. Dashboard → Settings → Network Settings
2. Enter new WiFi credentials
3. Send to Glass
```

### Monitoring Pi Connection
```bash
# On the Pi, check logs
journalctl -u sage-ble -f

# You'll see:
# - Credentials received
# - Connection attempt
# - Success/failure status
```

## Implementation Files

### Services
- `lib/services/network_service.dart` - Network configuration logic
- `lib/services/pairing_service.dart` - Simplified BLE pairing only
- `lib/services/storage_service.dart` - Separate storage for device & WiFi

### Screens
- `lib/screens/network_settings_screen.dart` - WiFi configuration UI
- `lib/screens/pairing_flow_screen.dart` - BLE pairing UI (simplified)

### Backend
- `sage/ble_gatt_server.py` - Receives WiFi credentials and connects

## Technical Details

### BLE Communication
- **Service UUID:** `12345678-1234-5678-1234-56789abcdef0`
- **Credentials Characteristic:** `...def1` (Write)
- **Status Characteristic:** `...def2` (Read/Notify)

### Data Format
```json
{
  "ssid": "YourWiFiName",
  "password": "YourWiFiPassword"
}
```

### Pi Behavior
1. Receives credentials via BLE write
2. Attempts to connect using NetworkManager (nmcli) or wpa_cli
3. Updates status characteristic with connection result
4. Stays connected or disconnected based on actual network availability

## Migration from Old Flow

The old flow tried to:
1. Auto-detect phone's current WiFi
2. Send those credentials to Pi
3. Wait for Pi to connect to phone's hotspot

**Problems:**
- Detected wrong network (current WiFi instead of hotspot)
- Couldn't verify actual connection
- Showed success even on failure

**New flow fixes all of these issues!**
