import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/paired_device.dart';

/// Service for managing persistent storage of pairing data
class StorageService {
  static const String _keyPairingComplete = 'pairing_complete';
  static const String _keyPairedDevice = 'paired_device';
  static const String _keyHotspotSSID = 'hotspot_ssid';
  static const String _keyHotspotPassword = 'hotspot_password';
  static const String _keyPairingTimestamp = 'pairing_timestamp';

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

  /// Save pairing information
  static Future<void> savePairingData({
    required PairedDevice device,
    required String hotspotSSID,
    required String hotspotPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool(_keyPairingComplete, true);
    await prefs.setString(_keyPairedDevice, json.encode(device.toJson()));
    await prefs.setString(_keyHotspotSSID, hotspotSSID);
    await prefs.setString(_keyHotspotPassword, hotspotPassword);
    await prefs.setString(_keyPairingTimestamp, DateTime.now().toIso8601String());
  }

  /// Get hotspot credentials
  static Future<Map<String, String>?> getHotspotCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final ssid = prefs.getString(_keyHotspotSSID);
    final password = prefs.getString(_keyHotspotPassword);
    
    if (ssid == null || password == null) return null;
    
    return {
      'ssid': ssid,
      'password': password,
    };
  }

  /// Clear all pairing data (unpair)
  static Future<void> clearPairingData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_keyPairingComplete);
    await prefs.remove(_keyPairedDevice);
    await prefs.remove(_keyHotspotSSID);
    await prefs.remove(_keyHotspotPassword);
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
}
