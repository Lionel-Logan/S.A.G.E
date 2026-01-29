import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for managing Speech-to-Text configuration
class STTService {
  static String? _baseUrl;

  /// Set the base URL for the STT service
  static void setBaseUrl(String url) {
    _baseUrl = url;
  }

  /// Get current STT configuration
  static Future<Map<String, dynamic>> getConfig() async {
    if (_baseUrl == null) {
      throw Exception('STT service base URL not set');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stt/config'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get STT config: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting STT config: $e');
    }
  }

  /// Update STT configuration
  static Future<void> updateConfig(Map<String, dynamic> config) async {
    if (_baseUrl == null) {
      throw Exception('STT service base URL not set');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/stt/config'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(config),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to update STT config: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating STT config: $e');
    }
  }

  /// Save Google API key
  static Future<void> saveGoogleApiKey(String apiKey) async {
    if (_baseUrl == null) {
      throw Exception('STT service base URL not set');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/stt/google-api-key'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'api_key': apiKey}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to save API key: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error saving API key: $e');
    }
  }

  /// Test STT with a sample audio
  static Future<String> test() async {
    if (_baseUrl == null) {
      throw Exception('STT service base URL not set');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stt/test'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['text'] ?? 'Test successful';
      } else {
        throw Exception('STT test failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error testing STT: $e');
    }
  }
}
