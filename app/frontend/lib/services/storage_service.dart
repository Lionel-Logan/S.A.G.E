import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/paired_device.dart';
import 'network_service.dart';

/// Service for managing persistent storage of pairing data
class StorageService {
  static const String _keyPairingComplete = 'pairing_complete';
  static const String _keyPairedDevice = 'paired_device';
  static const String _keyWiFiSSID = 'wifi_ssid';
  static const String _keyWiFiPassword = 'wifi_password';
  static const String _keyWiFiTimestamp = 'wifi_timestamp';
  static const String _keyPairingTimestamp = 'pairing_timestamp';
  static const String _keyLastRoute = 'last_route';

  /// Check if device has been paired
  static Future<bool> isPaired() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPairingComplete) ?? false;
  }

  /// Get paired device information
  static Future<PairedDevice?> getPairedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceJson = prefs.getString(_keyPairedDevice);
    
    if (deviceJson == null) return null;
    
    try {
      final Map<String, dynamic> data = json.decode(deviceJson);
      return PairedDevice.fromJson(data);
    } catch (e) {
      print('Error parsing paired device: $e');
      return null;
    }
  }

  /// Save paired device only (without WiFi credentials)
  static Future<void> savePairedDevice(PairedDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool(_keyPairingComplete, true);
    await prefs.setString(_keyPairedDevice, json.encode(device.toJson()));
    await prefs.setString(_keyPairingTimestamp, DateTime.now().toIso8601String());
  }

  /// Save pairing information (deprecated - use savePairedDevice instead)
  static Future<void> savePairingData({
    required PairedDevice device,
    required String hotspotSSID,
    required String hotspotPassword,
  }) async {
    await savePairedDevice(device);
    await saveWiFiCredentials(ssid: hotspotSSID, password: hotspotPassword);
  }

  /// Save WiFi credentials
  static Future<void> saveWiFiCredentials({
    required String ssid,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_keyWiFiSSID, ssid);
    await prefs.setString(_keyWiFiPassword, password);
    await prefs.setString(_keyWiFiTimestamp, DateTime.now().toIso8601String());
  }

  /// Get WiFi credentials
  static Future<WiFiCredentials?> getWiFiCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final ssid = prefs.getString(_keyWiFiSSID);
    final password = prefs.getString(_keyWiFiPassword);
    final timestampStr = prefs.getString(_keyWiFiTimestamp);
    
    if (ssid == null || password == null) return null;
    
    DateTime? savedAt;
    if (timestampStr != null) {
      try {
        savedAt = DateTime.parse(timestampStr);
      } catch (e) {
        // ignore
      }
    }
    
    return WiFiCredentials(
      ssid: ssid,
      password: password,
      savedAt: savedAt,
    );
  }

  /// Clear WiFi credentials
  static Future<void> clearWiFiCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_keyWiFiSSID);
    await prefs.remove(_keyWiFiPassword);
    await prefs.remove(_keyWiFiTimestamp);
  }

  /// Get hotspot credentials (deprecated - use getWiFiCredentials instead)
  static Future<Map<String, String>?> getHotspotCredentials() async {
    final creds = await getWiFiCredentials();
    if (creds == null) return null;
    
    return {
      'ssid': creds.ssid,
      'password': creds.password,
    };
  }

  /// Clear all pairing data (unpair)
  static Future<void> clearPairingData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_keyPairingComplete);
    await prefs.remove(_keyPairedDevice);
    await prefs.remove(_keyWiFiSSID);
    await prefs.remove(_keyWiFiPassword);
    await prefs.remove(_keyWiFiTimestamp);
    await prefs.remove(_keyPairingTimestamp);
  }

  /// Get pairing timestamp
  static Future<DateTime?> getPairingTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_keyPairingTimestamp);
    
    if (timestamp == null) return null;
    
    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      return null;
    }
  }
  
  /// Save last viewed route
  static Future<void> saveLastRoute(String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastRoute, route);
  }
  
  /// Get last viewed route
  static Future<String?> getLastRoute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastRoute);
  }
  
  /// Clear last route (useful when logging out or resetting)
  static Future<void> clearLastRoute() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastRoute);
  }
}
