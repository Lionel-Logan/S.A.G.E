import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for Bluetooth device scanning and connection
/// Contains both real and mock implementations
class BluetoothService {
  static const String sageGlassPrefix = 'SAGE';
  static const Duration scanTimeout = Duration(seconds: 10);
  
  // Mock mode flag - set to true for testing without hardware
  static bool useMockMode = true;

  /// Request Bluetooth permissions
  static Future<bool> requestPermissions() async {
    if (useMockMode) {
      // Simulate permission request
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }

    // Real implementation
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final location = await Permission.locationWhenInUse.request();

    return bluetoothScan.isGranted &&
        bluetoothConnect.isGranted &&
        location.isGranted;
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

  /// Scan for SAGE Glass devices
  static Stream<List<BluetoothDeviceInfo>> scanForDevices() async* {
    if (useMockMode) {
      // Mock implementation - simulate device discovery
      yield* _mockScanForDevices();
      return;
    }

    // Real implementation
    final devices = <BluetoothDeviceInfo>[];
    
    try {
      FlutterBluePlus.startScan(timeout: scanTimeout);

      await for (final scanResult in FlutterBluePlus.scanResults) {
        devices.clear();
        
        for (var result in scanResult) {
          if (result.device.platformName.startsWith(sageGlassPrefix)) {
            devices.add(BluetoothDeviceInfo(
              name: result.device.platformName,
              id: result.device.remoteId.toString(),
              rssi: result.rssi,
            ));
          }
        }
        
        yield List.from(devices);
      }
    } catch (e) {
      print('Error scanning for devices: $e');
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
        name: 'SAGE Glass X1',
        id: 'mock-device-001',
        rssi: -45,
      ),
    ];
  }

  /// Connect to a Bluetooth device
  static Future<bool> connectToDevice(String deviceId) async {
    if (useMockMode) {
      await Future.delayed(const Duration(seconds: 2));
      return true;
    }

    // Real implementation
    try {
      final device = BluetoothDevice.fromId(deviceId);
      await device.connect(timeout: const Duration(seconds: 10));
      return true;
    } catch (e) {
      print('Error connecting to device: $e');
      return false;
    }
  }

  /// Send hotspot credentials to device via Bluetooth
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

    // Real implementation - send via Bluetooth characteristic
    try {
      final device = BluetoothDevice.fromId(deviceId);
      final services = await device.discoverServices();
      
      // Find the credentials service/characteristic
      // This would be defined by the Pi server's Bluetooth profile
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            final data = '$ssid|$password';
            await characteristic.write(data.codeUnits);
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      print('Error sending credentials: $e');
      return false;
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
