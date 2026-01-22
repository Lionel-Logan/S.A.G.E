# ✅ SAGE BLE Service - Setup Complete!

## 🎉 Status: **FULLY OPERATIONAL**

Your Raspberry Pi is now advertising as a BLE GATT server and ready to pair with the Android app!

---

## 📊 Service Information

### BLE Configuration
- **Device Name**: `SAGE Glass X1`
- **Service UUID**: `12345678-1234-5678-1234-56789abcdef0`
- **Credentials Characteristic UUID**: `12345678-1234-5678-1234-56789abcdef1`
- **Status Characteristic UUID**: `12345678-1234-5678-1234-56789abcdef2`

### Bluetooth Adapter
- **Interface**: hci0
- **BD Address**: B8:27:EB:FD:78:78
- **Status**: UP RUNNING
- **Type**: Primary (UART)

### Service Status
- **Service Name**: `sage-ble.service`
- **Status**: ✅ **Active and Running**
- **Auto-start**: ✅ Enabled
- **Location**: `/etc/systemd/system/sage-ble.service`
- **Script**: `/home/sage/sage/ble_gatt_server.py`

---

## 🔧 Service Management Commands

### View Status
```bash
sudo systemctl status sage-ble
```

### View Live Logs
```bash
sudo journalctl -u sage-ble -f
```

### Restart Service
```bash
sudo systemctl restart sage-ble
```

### Stop Service
```bash
sudo systemctl stop sage-ble
```

### Start Service
```bash
sudo systemctl start sage-ble
```

### Disable Auto-start
```bash
sudo systemctl disable sage-ble
```

### Enable Auto-start
```bash
sudo systemctl enable sage-ble
```

---

## 📱 Flutter App Configuration

**IMPORTANT**: The UUIDs are already configured correctly in the Flutter app since we used the same UUIDs!

### Current Configuration (Already Set)
File: `app/frontend/lib/config/ble_config.dart`

```dart
static const String credentialsServiceUuid = '12345678-1234-5678-1234-56789abcdef0';
static const String credentialsCharacteristicUuid = '12345678-1234-5678-1234-56789abcdef1';
static const String statusCharacteristicUuid = '12345678-1234-5678-1234-56789abcdef2';
static const String deviceNamePrefix = 'SAGE';
```

✅ **No changes needed** - App is already configured with matching UUIDs!

---

## 🧪 Testing the BLE Service

### 1. Test from Raspberry Pi
```bash
cd ~/sage
sudo python3 test_ble.py
```

### 2. Test from Android (nRF Connect App)
1. Install "nRF Connect" from Play Store
2. Open app and tap "SCAN"
3. Look for device named "SAGE Glass X1"
4. Connect to device
5. You should see service: `12345678-1234-5678-1234-56789abcdef0`
6. Under service, see characteristics:
   - `...def1` (Write) - Credentials
   - `...def2` (Read/Notify) - Status

### 3. Test from SAGE Flutter App
1. Run the app: `flutter run`
2. Choose "AUTO-DETECT" or "MANUAL SETUP"
3. App should find "SAGE Glass X1"
4. Complete pairing process
5. Check Pi logs: `sudo journalctl -u sage-ble -f`

---

## 📋 What Happens During Pairing

1. **Mobile app scans** → Finds "SAGE Glass X1"
2. **App connects** → BLE GATT connection established
3. **App writes credentials** → JSON `{"ssid":"...", "password":"..."}` sent to characteristic
4. **Pi receives data** → Python script parses credentials
5. **Pi connects to WiFi** → Automatically joins phone's hotspot
6. **Status updates** → Pi notifies app of connection status
7. **Pairing complete** → Both devices on same WiFi network

---

## 📁 Installed Files

### On Raspberry Pi (`~/sage/`)
- `ble_gatt_server.py` - Main BLE GATT server (18KB)
- `install_ble_service.sh` - Installation script (2.4KB)
- `test_ble.py` - Testing script (2.4KB)

### System Service
- `/etc/systemd/system/sage-ble.service` - Systemd service file

---

## 🔍 Troubleshooting

### Service Won't Start
```bash
# Check logs for errors
sudo journalctl -u sage-ble -n 50 --no-pager

# Check if Bluetooth service is running
sudo systemctl status bluetooth

# Restart Bluetooth
sudo systemctl restart bluetooth
sudo systemctl restart sage-ble
```

### Not Advertising
```bash
# Check if adapter is up
sudo hciconfig hci0 up

# Enable advertising
sudo hciconfig hci0 leadv

# Restart service
sudo systemctl restart sage-ble
```

### App Can't Find Device
- Check service is running: `sudo systemctl status sage-ble`
- Check Bluetooth adapter: `sudo hciconfig`
- Check logs: `sudo journalctl -u sage-ble -f`
- Try scanning with nRF Connect app first
- Ensure devices are within 10 meters
- Restart both devices

### WiFi Connection Fails
- Check credentials were received: `sudo journalctl -u sage-ble | grep credential`
- Check network manager: `nmcli device status`
- Manually test connection: `nmcli device wifi connect "SSID" password "PASSWORD"`
- Check WiFi adapter: `ip link show wlan0`

---

## 🔐 Security Notes

### Current Setup
- BLE GATT is open (no pairing/bonding required)
- Credentials transmitted once during pairing
- Credentials stored temporarily during connection

### Recommended Improvements
1. **Add BLE bonding** - Require PIN for pairing
2. **Encrypt credentials** - Add encryption layer
3. **Add authentication** - Verify mobile app identity
4. **Secure storage** - Store credentials encrypted
5. **Connection timeout** - Auto-disconnect after inactivity

---

## 📊 Service Logs

Recent logs show successful startup:
```
✅ SAGE BLE GATT Server started
✅ Device Name: SAGE Glass X1
✅ Service UUID: 12345678-1234-5678-1234-56789abcdef0
✅ Bluetooth adapter: /org/bluez/hci0
✅ GATT application registered
✅ Advertisement registered
✅ Waiting for connections...
```

---

## 🚀 Next Steps

### 1. Test BLE Advertising
```bash
cd ~/sage
sudo python3 test_ble.py
```

### 2. Test from Android
- Download nRF Connect
- Scan for "SAGE Glass X1"
- Verify service and characteristics

### 3. Test Full Pairing
- Run Flutter app on Android 12+ device
- Follow pairing flow
- Monitor Pi logs during process

### 4. Verify WiFi Connection
- Complete pairing
- Check if Pi connects to hotspot
- Verify IP address: `hostname -I`

---

## ✨ Success Indicators

✅ Service running: `sudo systemctl status sage-ble`
✅ Adapter up: Bluetooth adapter UP and RUNNING
✅ Advertising: Device visible in BLE scan
✅ GATT registered: Service and characteristics available
✅ Auto-start enabled: Will start on boot
✅ Logs clean: No errors in journalctl

---

## 📞 Support Commands

```bash
# Full diagnostic
cd ~/sage
sudo python3 test_ble.py

# Watch logs live
sudo journalctl -u sage-ble -f

# Check all Bluetooth services
sudo systemctl | grep blue

# Scan for BLE devices
sudo timeout 5 hcitool lescan

# Check WiFi status
nmcli device wifi list
```

---

## 🎉 **YOU'RE ALL SET!**

Your Raspberry Pi is now:
- ✅ Advertising as "SAGE Glass X1"
- ✅ Running BLE GATT server
- ✅ Ready to receive WiFi credentials
- ✅ Ready to pair with Flutter app
- ✅ Auto-starts on boot

**Ready to test pairing from your Android device!** 🚀

---

**Created**: January 21, 2026
**Service**: sage-ble.service
**Status**: Active and Operational
