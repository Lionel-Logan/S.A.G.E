import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/ble_config.dart';
import 'dart:convert';

/// Service for Bluetooth device scanning and connection
/// Real BLE implementation for Android 12+ with Raspberry Pi
/// 
/// Configuration is centralized in BLEConfig class
/// Update UUIDs in lib/config/ble_config.dart to match your Raspberry Pi
class BluetoothService {
  // Mock mode flag - set to false for production with real hardware
  static bool useMockMode = false;

  /// Request Bluetooth permissions for Android 12+
  static Future<bool> requestPermissions() async {
    if (useMockMode) {
      // Simulate permission request
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }

    // Real implementation for Android 12+ (API 31+)
    // Request all required permissions
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();

    // Check if all permissions are granted
    return statuses.values.every((status) => status.isGranted);
  }

  /// Check if Bluetooth is available and enabled
  static Future<bool> isBluetoothAvailable() async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }

    try {
      final isAvailable = await FlutterBluePlus.isAvailable;
      if (!isAvailable) return false;

      final isOn = await FlutterBluePlus.isOn;
      return isOn;
    } catch (e) {
      print('Error checking Bluetooth: $e');
      return false;
    }
  }

  /// Scan for S.A.G.E devices with improved filtering
  static Stream<List<BluetoothDeviceInfo>> scanForDevices() async* {
    if (useMockMode) {
      // Mock implementation - simulate device discovery
      yield* _mockScanForDevices();
      return;
    }

    // Real BLE implementation
    final devices = <String, BluetoothDeviceInfo>{}; // Use map to avoid duplicates
    
    try {
      // Stop any existing scan first
      await FlutterBluePlus.stopScan();
      
      // Start new scan with timeout
      await FlutterBluePlus.startScan(
        timeout: BLEConfig.scanTimeout,
        androidUsesFineLocation: true,
      );

      await for (final scanResults in FlutterBluePlus.scanResults) {
        for (var result in scanResults) {
          // Filter for SAGE devices by name or advertised services
          final deviceName = result.device.platformName;
          final hasName = deviceName.isNotEmpty;
          final isSageDevice = deviceName.startsWith(BLEConfig.deviceNamePrefix);
          
          // Also check for our custom service UUID in advertised services
          final hasCredentialService = result.advertisementData.serviceUuids
              .any((uuid) => uuid.toString().toLowerCase() == BLEConfig.credentialsServiceUuid.toLowerCase());
          
          if (hasName && (isSageDevice || hasCredentialService)) {
            final deviceId = result.device.remoteId.toString();
            devices[deviceId] = BluetoothDeviceInfo(
              name: deviceName.isEmpty ? 'S.A.G.E' : deviceName,
              id: deviceId,
              rssi: result.rssi,
            );
          }
        }
        
        yield devices.values.toList();
      }
    } catch (e) {
      print('Error scanning for BLE devices: $e');
      yield [];
    } finally {
      await FlutterBluePlus.stopScan();
    }
  }

  /// Mock scan implementation
  static Stream<List<BluetoothDeviceInfo>> _mockScanForDevices() async* {
    // Simulate searching
    yield [];
    await Future.delayed(const Duration(seconds: 1));
    
    yield [];
    await Future.delayed(const Duration(seconds: 1));
    
    // Device found!
    yield [
      BluetoothDeviceInfo(
        name: 'S.A.G.E X1',
        id: 'mock-device-001',
        rssi: -45,
      ),
    ];
  }

  /// Connect to a Bluetooth device with retry logic
  static Future<bool> connectToDevice(String deviceId, {int? maxRetries}) async {
    maxRetries ??= BLEConfig.maxConnectionRetries;
    
    if (useMockMode) {
      await Future.delayed(const Duration(seconds: 2));
      return true;
    }

    // Real BLE implementation with retry
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final device = BluetoothDevice.fromId(deviceId);
        
        // Check if already connected
        final isConnected = await device.isConnected;
        if (isConnected) return true;
        
        // Attempt connection
        await device.connect(
          timeout: BLEConfig.connectionTimeout,
          autoConnect: false,
        );
        
        // Verify connection
        final connected = await device.isConnected;
        if (connected) {
          print('Successfully connected to device on attempt ${attempt + 1}');
          return true;
        }
      } catch (e) {
        print('Connection attempt ${attempt + 1} failed: $e');
        if (attempt == maxRetries - 1) {
          print('Failed to connect after $maxRetries attempts');
          return false;
        }
        // Wait before retry
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
    
    return false;
  }

  /// Send hotspot credentials to device via BLE GATT characteristic
  static Future<bool> sendCredentials({
    required String deviceId,
    required String ssid,
    required String password,
  }) async {
    if (useMockMode) {
      // Simulate data transfer
      await Future.delayed(const Duration(seconds: 2));
      return true;
    }

    // Real BLE GATT implementation
    try {
      print('Attempting to send credentials to device: $deviceId');
      final device = BluetoothDevice.fromId(deviceId);
      
      // Ensure device is connected
      final isConnected = await device.isConnected;
      if (!isConnected) {
        print('Device not connected, cannot send credentials');
        return false;
      }
      
      print('Device connected, discovering GATT services...');
      
      // Discover GATT services
      final services = await device.discoverServices();
      print('Discovered ${services.length} services');
      
      // Find the S.A.G.E credentials service
      for (var service in services) {
        print('Checking service: ${service.uuid}');
        if (service.uuid.toString().toLowerCase() == BLEConfig.credentialsServiceUuid.toLowerCase()) {
          print('Found SAGE credentials service!');
          
          // Find the credentials characteristic
          for (var characteristic in service.characteristics) {
            print('  Checking characteristic: ${characteristic.uuid}');
            if (characteristic.uuid.toString().toLowerCase() == BLEConfig.credentialsCharacteristicUuid.toLowerCase()) {
              print('  Found credentials characteristic!');
              
              // Check write permission
              if (!characteristic.properties.write && !characteristic.properties.writeWithoutResponse) {
                print('  ERROR: Characteristic does not support write operations');
                return false;
              }
              
              // Format: JSON for better structure
              final credentialsJson = '{"ssid":"$ssid","password":"$password"}';
              final data = credentialsJson.codeUnits;
              
              print('  Writing ${data.length} bytes to characteristic...');
              
              // Write credentials to characteristic
              await characteristic.write(
                data,
                withoutResponse: characteristic.properties.writeWithoutResponse,
              );
              
              print('  Credentials sent successfully via BLE!');
              print('  Sent SSID: $ssid (${password.length} char password)');
              
              // Optional: Read status characteristic to verify
              await Future.delayed(const Duration(milliseconds: 500));
              return true;
            }
          }
        }
      }
      
      print('ERROR: S.A.G.E credentials service not found. Available services:');
      for (var service in services) {
        print('  - ${service.uuid}');
      }
      return false;
    } catch (e) {
      print('Error sending credentials via BLE: $e');
      return false;
    }
  }

  /// Read connection status from S.A.G.E
  static Future<Map<String, dynamic>?> readConnectionStatus(String deviceId) async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return {'status': 'connected', 'network': 'MockNetwork'};
    }

    try {
      print('Reading connection status from device: $deviceId');
      final device = BluetoothDevice.fromId(deviceId);
      
      // Ensure device is connected
      final isConnected = await device.isConnected;
      if (!isConnected) {
        print('Device not connected, cannot read status');
        return null;
      }
      
      // Discover GATT services
      final services = await device.discoverServices();
      print('Discovered ${services.length} services');
      
      // Find the S.A.G.E credentials service
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == BLEConfig.credentialsServiceUuid.toLowerCase()) {
          // Find the status characteristic
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == BLEConfig.statusCharacteristicUuid.toLowerCase()) {
              print('  Found status characteristic, reading...');
              
              // Read status
              final value = await characteristic.read();
              final statusStr = String.fromCharCodes(value);
              
              print('  Status data: $statusStr');
              
              // Parse JSON
              try {
                final statusData = json.decode(statusStr) as Map<String, dynamic>;
                return statusData;
              } catch (e) {
                print('  Error parsing status JSON: $e');
                return null;
              }
            }
          }
        }
      }
      
      print('Status characteristic not found');
      return null;
    } catch (e) {
      print('Error reading connection status: $e');
      return null;
    }
  }

  /// Read detailed network information from S.A.G.E
  static Future<Map<String, dynamic>?> readNetworkDetails(String deviceId) async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return {
        'rssi': '-45',
        'frequency': '2.4 GHz',
        'protocol': 'WPA2-PSK',
        'ip_address': '192.168.1.105',
        'link_speed': '65',
        'channel': '6',
        'noise': '-90'
      };
    }

    try {
      final device = BluetoothDevice.fromId(deviceId);
      final isConnected = await device.isConnected;
      if (!isConnected) return null;
      
      final services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == BLEConfig.credentialsServiceUuid.toLowerCase()) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == BLEConfig.networkDetailsCharacteristicUuid.toLowerCase()) {
              final value = await characteristic.read();
              final dataStr = String.fromCharCodes(value);
              try {
                return json.decode(dataStr) as Map<String, dynamic>;
              } catch (e) {
                print('Error parsing network details: $e');
                return null;
              }
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('Error reading network details: $e');
      return null;
    }
  }

  /// Read Bluetooth connection details from S.A.G.E
  static Future<Map<String, dynamic>?> readBluetoothDetails(String deviceId) async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return {
        'glass_device': 'SAGE Glass X1',
        'mobile_device': 'SM M526B',
        'rssi': '-45',
        'ble_version': '5.0',
        'connected': true
      };
    }

    try {
      final device = BluetoothDevice.fromId(deviceId);
      final isConnected = await device.isConnected;
      if (!isConnected) return null;
      
      final services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == BLEConfig.credentialsServiceUuid.toLowerCase()) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == BLEConfig.bluetoothDetailsCharacteristicUuid.toLowerCase()) {
              final value = await characteristic.read();
              final dataStr = String.fromCharCodes(value);
              try {
                return json.decode(dataStr) as Map<String, dynamic>;
              } catch (e) {
                print('Error parsing Bluetooth details: $e');
                return null;
              }
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('Error reading Bluetooth details: $e');
      return null;
    }
  }

  /// Read device information from S.A.G.E
  static Future<Map<String, dynamic>?> readDeviceInfo(String deviceId) async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return {
        'paired_timestamp': DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
        'firmware_version': 'v1.0.0',
        'device_type': 'Smart Glasses'
      };
    }

    try {
      final device = BluetoothDevice.fromId(deviceId);
      final isConnected = await device.isConnected;
      if (!isConnected) return null;
      
      final services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == BLEConfig.credentialsServiceUuid.toLowerCase()) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == BLEConfig.deviceInfoCharacteristicUuid.toLowerCase()) {
              final value = await characteristic.read();
              final dataStr = String.fromCharCodes(value);
              try {
                return json.decode(dataStr) as Map<String, dynamic>;
              } catch (e) {
                print('Error parsing device info: $e');
                return null;
              }
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('Error reading device info: $e');
      return null;
    }
  }

  /// Scan for WiFi networks available to the Glass device
  static Future<List<Map<String, dynamic>>> scanWiFiNetworks(String deviceId) async {
    if (useMockMode) {
      await Future.delayed(const Duration(seconds: 1));
      return [
        {'ssid': 'MockNetwork1', 'signal': 90, 'secured': true},
        {'ssid': 'MockNetwork2', 'signal': 75, 'secured': true},
        {'ssid': 'OpenNetwork', 'signal': 60, 'secured': false},
      ];
    }

    try {
      print('Scanning WiFi networks on device: $deviceId');
      final device = BluetoothDevice.fromId(deviceId);
      
      // Ensure device is connected
      final isConnected = await device.isConnected;
      if (!isConnected) {
        print('Device not connected, cannot scan networks');
        return [];
      }
      
      // Discover GATT services
      final services = await device.discoverServices();
      
      // Find the S.A.G.E credentials service
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == BLEConfig.credentialsServiceUuid.toLowerCase()) {
          // Find the scan characteristic
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == BLEConfig.scanCharacteristicUuid.toLowerCase()) {
              print('  Found scan characteristic, reading networks...');
              
              // Read networks
              final value = await characteristic.read();
              final networksStr = String.fromCharCodes(value);
              
              print('  Networks data: $networksStr');
              
              // Parse JSON array
              try {
                final networksList = json.decode(networksStr) as List<dynamic>;
                return networksList.cast<Map<String, dynamic>>();
              } catch (e) {
                print('  Error parsing networks JSON: $e');
                return [];
              }
            }
          }
        }
      }
      
      print('Scan characteristic not found');
      return [];
    } catch (e) {
      print('Error scanning WiFi networks: $e');
      return [];
    }
  }

  /// Disconnect from device
  static Future<void> disconnect(String deviceId) async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    try {
      final device = BluetoothDevice.fromId(deviceId);
      await device.disconnect();
    } catch (e) {
      print('Error disconnecting: $e');
    }
  }
}

/// Bluetooth device information
class BluetoothDeviceInfo {
  final String name;
  final String id;
  final int rssi;

  BluetoothDeviceInfo({
    required this.name,
    required this.id,
    required this.rssi,
  });

  int get signalStrength {
    if (rssi >= -50) return 5; // Excellent
    if (rssi >= -60) return 4; // Good
    if (rssi >= -70) return 3; // Fair
    if (rssi >= -80) return 2; // Weak
    return 1; // Very weak
  }
}
