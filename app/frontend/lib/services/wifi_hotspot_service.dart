import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// Service for WiFi hotspot management
/// Contains both real and mock implementations
class WiFiHotspotService {
  // Mock mode flag - set to true for testing without hardware
  static bool useMockMode = true;

  /// Request WiFi permissions
  static Future<bool> requestPermissions() async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }

    final location = await Permission.locationWhenInUse.request();
    return location.isGranted;
  }

  /// Auto-detect current hotspot credentials
  static Future<HotspotCredentials?> autoDetectHotspot() async {
    if (useMockMode) {
      // Mock credentials
      await Future.delayed(const Duration(seconds: 1));
      return HotspotCredentials(
        ssid: 'MyPhone-Hotspot',
        password: 'password123',
      );
    }

    // Real implementation - try to get WiFi info
    try {
      final info = NetworkInfo();
      final wifiName = await info.getWifiName();
      
      // Note: Password cannot be retrieved programmatically for security reasons
      // User will need to enter it manually or we guide them to set it
      if (wifiName != null) {
        return HotspotCredentials(
          ssid: wifiName.replaceAll('"', ''),
          password: '', // User must provide
        );
      }
      
      return null;
    } catch (e) {
      print('Error detecting hotspot: $e');
      return null;
    }
  }

  /// Check if WiFi hotspot is enabled
  static Future<bool> isHotspotEnabled() async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return false; // Start as disabled
    }

    try {
      return await WiFiForIoTPlugin.isWiFiAPEnabled() ?? false;
    } catch (e) {
      print('Error checking hotspot status: $e');
      return false;
    }
  }

  /// Enable WiFi hotspot with given credentials
  static Future<bool> enableHotspot({
    required String ssid,
    required String password,
  }) async {
    if (useMockMode) {
      // Simulate enabling hotspot
      await Future.delayed(const Duration(seconds: 2));
      return true;
    }

    try {
      // Note: This functionality is limited on modern Android/iOS
      // User may need to enable manually
      return await WiFiForIoTPlugin.setWiFiAPEnabled(true) ?? false;
    } catch (e) {
      print('Error enabling hotspot: $e');
      return false;
    }
  }

  /// Disable WiFi hotspot
  static Future<bool> disableHotspot() async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }

    try {
      return await WiFiForIoTPlugin.setWiFiAPEnabled(false) ?? false;
    } catch (e) {
      print('Error disabling hotspot: $e');
      return false;
    }
  }

  /// Get list of connected devices to hotspot
  static Future<List<String>> getConnectedDevices() async {
    if (useMockMode) {
      await Future.delayed(const Duration(seconds: 1));
      // Simulate SAGE Glass connecting
      return ['SAGE Glass X1'];
    }

    // Real implementation would use WiFiForIoTPlugin
    // Note: This API may vary by platform and package version
    try {
      // Commented out due to API compatibility issues
      // final clients = await WiFiForIoTPlugin.getClientList(...);
      // return clients?.map((client) => client.toString()).toList() ?? [];
      return [];
    } catch (e) {
      print('Error getting connected devices: $e');
      return [];
    }
  }

  /// Wait for SAGE Glass to connect to hotspot
  static Stream<bool> waitForGlassConnection() async* {
    if (useMockMode) {
      // Simulate connection attempt
      yield false;
      await Future.delayed(const Duration(seconds: 2));
      yield false;
      await Future.delayed(const Duration(seconds: 2));
      yield true; // Connected!
      return;
    }

    // Real implementation - poll for connected devices
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 1));
      
      final devices = await getConnectedDevices();
      final glassConnected = devices.any(
        (device) => device.toLowerCase().contains('sage'),
      );
      
      yield glassConnected;
      
      if (glassConnected) break;
    }
  }
}

/// Hotspot credentials data class
class HotspotCredentials {
  final String ssid;
  final String password;

  HotspotCredentials({
    required this.ssid,
    required this.password,
  });

  bool get isComplete => ssid.isNotEmpty && password.isNotEmpty;
}
