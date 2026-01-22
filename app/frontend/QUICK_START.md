# 🚀 SAGE App - Quick Start Guide

## 📋 Pre-Flight Checklist

### Before Running the App:

- [ ] **Update BLE UUIDs** in `lib/config/ble_config.dart`
- [ ] **Raspberry Pi is ON** and BLE server is running
- [ ] **Android device** is Android 12+ (API 31+)
- [ ] **Flutter installed** and configured
- [ ] **Pi BLE server** is advertising with name starting with "SAGE"

## 🔧 Quick Setup

### 1. Configure BLE (5 minutes)

```bash
# Edit BLE configuration
code lib/config/ble_config.dart
```

Update these three UUIDs to match your Raspberry Pi:
```dart
static const String credentialsServiceUuid = 'YOUR-SERVICE-UUID-HERE';
static const String credentialsCharacteristicUuid = 'YOUR-CHAR-UUID-HERE';
static const String statusCharacteristicUuid = 'YOUR-STATUS-UUID-HERE';
```

### 2. Build & Run (2 minutes)

```bash
cd app/frontend
flutter clean
flutter pub get
flutter run
```

### 3. Grant Permissions

When app launches:
1. ✓ Allow Nearby devices
2. ✓ Allow Location access
3. ✓ Enable Bluetooth

### 4. Pair with SAGE Glass

**Auto Mode (Recommended)**:
- Tap "AUTO-DETECT"
- App scans automatically
- Connects to first SAGE device found
- Auto-detects or prompts for hotspot credentials
- Follow on-screen instructions to enable hotspot
- Wait for Glass to connect
- ✓ Done!

**Manual Mode**:
- Tap "MANUAL SETUP"
- Scan for devices
- Select your SAGE Glass from list
- Enter WiFi hotspot name (SSID)
- Enter WiFi hotspot password
- Enable hotspot manually when prompted
- Wait for Glass to connect
- ✓ Done!

## 🔍 Quick Troubleshooting

### App doesn't find device
- ✓ Check Pi is ON and BLE advertising
- ✓ Check device name starts with "SAGE"
- ✓ Move devices closer (< 5 meters)
- ✓ Restart Bluetooth on phone
- ✓ Check Pi BLE logs

### Connection fails
- ✓ Verify UUIDs match in both app and Pi
- ✓ Check Pi BLE server is running
- ✓ Try power cycling the Pi
- ✓ Check Android Bluetooth logs: `adb logcat | grep -i bluetooth`

### Can't send credentials
- ✓ Verify characteristic supports WRITE
- ✓ Check JSON format is correct
- ✓ Enable BLE logging on Pi
- ✓ Ensure UUIDs match exactly (case-insensitive)

### Hotspot won't enable
- ℹ️ Android 12+ requires manual enablement
- Follow the app's on-screen guide
- Settings → Network → Hotspot → Enable

### Glass doesn't connect to hotspot
- ✓ Verify exact SSID and password
- ✓ Check hotspot is 2.4GHz (Pi may not support 5GHz)
- ✓ Check Pi WiFi logs
- ✓ Verify hotspot is actually enabled

## 📱 Testing Without Hardware

Enable mock mode for UI testing:

```dart
// In lib/services/bluetooth_service.dart
static bool useMockMode = true;  // Enable mock mode

// In lib/services/wifi_hotspot_service.dart
static bool useMockMode = true;  // Enable mock mode
```

Then run: `flutter run`

## 🛠️ Development Commands

```bash
# Clean build
flutter clean && flutter pub get

# Run on device
flutter run

# Build APK
flutter build apk --release

# Check logs
adb logcat | grep -i flutter

# Check BLE permissions
adb shell dumpsys package com.sage.glass.mobile | grep permission

# Print BLE config (add to main.dart initState)
BLEConfig.printConfiguration();
```

## 📚 Documentation Files

- `BLE_SETUP_GUIDE.md` - Complete BLE setup documentation
- `RASPBERRY_PI_BLE_EXAMPLE.py` - Python BLE server example
- `IMPLEMENTATION_SUMMARY.md` - All changes made
- `lib/config/ble_config.dart` - Centralized BLE configuration

## 🎯 Next Steps After First Pairing

1. Test dashboard features
2. Verify camera capture works
3. Test voice assistant integration
4. Check face recognition
5. Test object detection
6. Verify HUD display
7. Test speaker output

## 🔐 Security Reminders

- [ ] Use WPA2/WPA3 for hotspot
- [ ] Change default UUIDs in production
- [ ] Implement authentication on Pi
- [ ] Consider BLE bonding for encryption
- [ ] Secure API endpoints

## 📞 Support

Having issues? Check:

1. **Flutter Logs**: `flutter run --verbose`
2. **Android Logs**: `adb logcat`
3. **Pi BLE Logs**: Check your BLE server output
4. **Permissions**: Android Settings → Apps → SAGE → Permissions
5. **BLE Test**: Use nRF Connect app to verify Pi advertising

## ✨ Current Status

✅ **Mock mode disabled** - Real BLE ready
✅ **Android 12+ compatible** - All permissions configured
✅ **BLE GATT ready** - Credential transfer implemented
✅ **Production build** - minSdk 31, targetSdk 34
✅ **Documentation complete** - All guides provided

## 🎉 Ready to Go!

Your app is **production-ready** for BLE pairing. Just:
1. Update UUIDs in `ble_config.dart`
2. Run Pi BLE server
3. `flutter run`
4. Start pairing!

Good luck! 🚀
