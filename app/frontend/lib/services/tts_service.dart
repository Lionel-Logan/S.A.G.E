import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tts_config.dart';

class TTSService {
  static String? _baseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<TTSConfig> getConfig() async {
    if (_baseUrl == null) {
      throw Exception('Base URL not set. Call setBaseUrl() first.');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/tts/config'),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return TTSConfig.fromJson(data['config']);
    } else {
      throw Exception('Failed to get TTS config: ${response.statusCode}');
    }
  }

  static Future<void> updateConfig(TTSConfig config) async {
    if (_baseUrl == null) {
      throw Exception('Base URL not set. Call setBaseUrl() first.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/tts/config'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(config.toJson()),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Failed to update TTS config: ${response.statusCode}');
    }
  }

  static Future<List<TTSVoice>> getVoices() async {
    if (_baseUrl == null) {
      throw Exception('Base URL not set. Call setBaseUrl() first.');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/tts/voices'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final voicesList = data['voices'] as List;
      return voicesList.map((v) => TTSVoice.fromJson(v)).toList();
    } else {
      throw Exception('Failed to get voices: ${response.statusCode}');
    }
  }

  static Future<void> speak(String text, {bool blocking = true}) async {
    if (_baseUrl == null) {
      throw Exception('Base URL not set. Call setBaseUrl() first.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/tts/speak'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'text': text,
        'blocking': blocking,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Failed to speak: ${response.statusCode}');
    }
  }

  static Future<void> testVoice() async {
    if (_baseUrl == null) {
      throw Exception('Base URL not set. Call setBaseUrl() first.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/tts/test'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Failed to test voice: ${response.statusCode}');
    }
  }

  static Future<void> stop() async {
    if (_baseUrl == null) {
      throw Exception('Base URL not set. Call setBaseUrl() first.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/tts/stop'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Failed to stop TTS: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> getStatus() async {
    if (_baseUrl == null) {
      throw Exception('Base URL not set. Call setBaseUrl() first.');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/tts/status'),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get TTS status: ${response.statusCode}');
    }
  }

  /// Save Google Cloud TTS API key
  static Future<void> saveGoogleApiKey(String apiKey) async {
    if (_baseUrl == null) {
      throw Exception('Base URL not set. Call setBaseUrl() first.');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/tts/google-api-key'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'api_key': apiKey}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to save API key: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error saving Google TTS API key: $e');
    }
  }
}
