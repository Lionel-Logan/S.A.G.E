/// BLE GATT Configuration for S.A.G.E
/// 
/// IMPORTANT: Update these UUIDs to match your Raspberry Pi BLE server implementation
/// 
/// To generate new UUIDs (if needed):
/// - Online: https://www.uuidgenerator.net/
/// - Linux/Mac: uuidgen
/// - Python: import uuid; print(uuid.uuid4())
///
/// Format: '12345678-1234-5678-1234-56789abcdef0' (lowercase with hyphens)

class BLEConfig {
  // ============================================================================
  // GATT SERVICE UUID
  // ============================================================================
  
  /// Main S.A.G.E BLE GATT Service
  /// This is the primary service that your Raspberry Pi must advertise
  /// 
  /// Update this to match your Pi's service UUID
  static const String credentialsServiceUuid = '12345678-1234-5678-1234-56789abcdef0';
  
  // ============================================================================
  // GATT CHARACTERISTIC UUIDs
  // ============================================================================
  
  /// Credentials Characteristic (WRITE)
  /// Used to send WiFi hotspot credentials from phone to Pi
  /// 
  /// Properties: WRITE or WRITE_WITHOUT_RESPONSE
  /// Data Format: JSON string {"ssid":"...", "password":"..."}
  /// 
  /// Update this to match your Pi's characteristic UUID
  static const String credentialsCharacteristicUuid = '12345678-1234-5678-1234-56789abcdef1';
  
  /// Status Characteristic (READ/NOTIFY)
  /// Used to read connection status from Pi
  /// 
  /// Properties: READ, NOTIFY (optional)
  /// Data Format: JSON string {"status":"waiting|connecting|connected|failed"}
  /// 
  /// Update this to match your Pi's characteristic UUID
  static const String statusCharacteristicUuid = '12345678-1234-5678-1234-56789abcdef2';
  
  /// WiFi Scan Characteristic (READ)
  /// Used to get list of available WiFi networks from Pi
  /// 
  /// Properties: READ
  /// Data Format: JSON array [{"ssid":"...", "signal":90, "secured":true}, ...]
  /// 
  /// Update this to match your Pi's characteristic UUID
  static const String scanCharacteristicUuid = '12345678-1234-5678-1234-56789abcdef3';
  
  /// Network Details Characteristic (READ)
  /// Used to get detailed network information from Pi
  /// 
  /// Properties: READ
  /// Data Format: JSON {"rssi":"-50", "frequency":"2.4 GHz", "protocol":"WPA2-PSK", ...}
  static const String networkDetailsCharacteristicUuid = '12345678-1234-5678-1234-56789abcdef4';
  
  /// Bluetooth Details Characteristic (READ)
  /// Used to get Bluetooth connection details from Pi
  /// 
  /// Properties: READ
  /// Data Format: JSON {"glass_device":"...", "mobile_device":"...", "rssi":"-45", ...}
  static const String bluetoothDetailsCharacteristicUuid = '12345678-1234-5678-1234-56789abcdef5';
  
  /// Device Info Characteristic (READ)
  /// Used to get device information from Pi
  /// 
  /// Properties: READ
  /// Data Format: JSON {"paired_timestamp":"...", "firmware_version":"...", ...}
  static const String deviceInfoCharacteristicUuid = '12345678-1234-5678-1234-56789abcdef6';
  
  // ============================================================================
  // DEVICE CONFIGURATION
  // ============================================================================
  
  /// Device Name Prefix
  /// The app filters BLE devices that start with this prefix
  /// Your Raspberry Pi should advertise with a name like "S.A.G.E X1"
  static const String deviceNamePrefix = 'SAGE';
  
  /// BLE Scan Timeout
  /// How long to scan for devices before giving up
  static const Duration scanTimeout = Duration(seconds: 30);
  
  /// Connection Timeout
  /// How long to wait for a single connection attempt
  static const Duration connectionTimeout = Duration(seconds: 15);
  
  /// Max Connection Retries
  /// Number of times to retry connection if it fails
  static const int maxConnectionRetries = 3;
  
  // ============================================================================
  // VALIDATION
  // ============================================================================
  
  /// Validate that UUIDs are in correct format
  static bool validateUUIDs() {
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    
    final serviceValid = uuidPattern.hasMatch(credentialsServiceUuid);
    final credentialsValid = uuidPattern.hasMatch(credentialsCharacteristicUuid);
    final statusValid = uuidPattern.hasMatch(statusCharacteristicUuid);
    
    if (!serviceValid) {
      print('ERROR: Invalid credentialsServiceUuid format');
    }
    if (!credentialsValid) {
      print('ERROR: Invalid credentialsCharacteristicUuid format');
    }
    if (!statusValid) {
      print('ERROR: Invalid statusCharacteristicUuid format');
    }
    
    return serviceValid && credentialsValid && statusValid;
  }
  
  /// Print current configuration (for debugging)
  static void printConfiguration() {
    print('═══════════════════════════════════════════════════════════');
    print('S.A.G.E BLE Configuration');
    print('═══════════════════════════════════════════════════════════');
    print('Service UUID:              $credentialsServiceUuid');
    print('Credentials Char UUID:     $credentialsCharacteristicUuid');
    print('Status Char UUID:          $statusCharacteristicUuid');
    print('Device Name Prefix:        $deviceNamePrefix');
    print('Scan Timeout:              ${scanTimeout.inSeconds}s');
    print('Connection Timeout:        ${connectionTimeout.inSeconds}s');
    print('Max Retries:               $maxConnectionRetries');
    print('═══════════════════════════════════════════════════════════');
    print('UUIDs Valid:               ${validateUUIDs() ? "✓" : "✗"}');
    print('═══════════════════════════════════════════════════════════');
  }
}

// ============================================================================
// RASPBERRY PI REFERENCE IMPLEMENTATION
// ============================================================================

/// Example Python code for Raspberry Pi BLE GATT Server:
/// 
/// ```python
/// import json
/// from bluez_peripheral.gatt.service import Service
/// from bluez_peripheral.gatt.characteristic import Characteristic
/// 
/// SERVICE_UUID = '12345678-1234-5678-1234-56789abcdef0'
/// CREDENTIALS_UUID = '12345678-1234-5678-1234-56789abcdef1'
/// STATUS_UUID = '12345678-1234-5678-1234-56789abcdef2'
/// 
/// class CredentialsCharacteristic(Characteristic):
///     def __init__(self, service):
///         super().__init__(CREDENTIALS_UUID, ['write'], service)
///     
///     def WriteValue(self, value, options):
///         data = ''.join(chr(b) for b in value)
///         credentials = json.loads(data)
///         # Connect to WiFi using credentials['ssid'] and credentials['password']
///         return []
/// 
/// class SAGEService(Service):
///     def __init__(self):
///         super().__init__(SERVICE_UUID, True)
///         self.add_characteristic(CredentialsCharacteristic(self))
/// ```

// ============================================================================
// TESTING WITH NRF CONNECT
// ============================================================================

/// To test your Raspberry Pi BLE server:
/// 
/// 1. Install nRF Connect app on Android
/// 2. Scan for BLE devices
/// 3. Look for device named "SAGE..." 
/// 4. Connect and view services
/// 5. Verify service UUID matches: 12345678-1234-5678-1234-56789abcdef0
/// 6. Find characteristics under the service
/// 7. Try writing test data: {"ssid":"test","password":"test123"}
/// 8. Check Pi logs to see if data was received

// ============================================================================
// CHANGELOG
// ============================================================================

/// v1.0.0 - Initial configuration
/// - Placeholder UUIDs (must be updated for production)
/// - Default device name prefix: SAGE
/// - 30 second scan timeout
/// - 3 connection retry attempts
