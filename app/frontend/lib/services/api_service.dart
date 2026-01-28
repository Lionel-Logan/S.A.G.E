import 'dart:convert';
import 'package:http/http.dart' as http;
import 'bluetooth_audio_service.dart';

/// API Service for communicating with Pi Server and App Backend
class ApiService {
  // Server URLs - dynamically resolved from settings
  static Future<String> getPiServerUrl() async {
    return await BluetoothAudioService.getPiServerUrl();
  }
  
  static Future<String> getBackendUrl() async {
    final piUrl = await getPiServerUrl();
    // Backend runs on port 8002 on same host as Pi server
    return piUrl.replaceAll(':8001', ':8002');
  }
  
  // Timeout duration - increased for network requests
  static const Duration timeout = Duration(seconds: 30);
  
  // ============================================================================
  // PI SERVER APIs
  // ============================================================================
  
  /// Get device identity and pairing status
  static Future<Map<String, dynamic>> getIdentity() async {
    try {
      final piServerUrl = await getPiServerUrl();
      final response = await http.get(
        Uri.parse('$piServerUrl/identity'),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get identity: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to Pi server: $e');
    }
  }
  
  /// Request pairing with Pi
  static Future<Map<String, dynamic>> requestPairing({
    required String appId,
    required String appName,
  }) async {
    try {
      final piServerUrl = await getPiServerUrl();
      final response = await http.post(
        Uri.parse('$piServerUrl/pairing/request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'app_id': appId,
          'app_name': appName,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to request pairing: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error requesting pairing: $e');
    }
  }
  
  /// Confirm pairing
  static Future<Map<String, dynamic>> confirmPairing({
    required String appId,
    required bool confirm,
  }) async {
    try {
      final piServerUrl = await getPiServerUrl();
      final response = await http.post(
        Uri.parse('$piServerUrl/pairing/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'app_id': appId,
          'confirm': confirm,
        }),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to confirm pairing: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error confirming pairing: $e');
    }
  }
  
  /// Capture camera frame from Pi
  static Future<Map<String, dynamic>> captureCamera() async {
    try {
      final piServerUrl = await getPiServerUrl();
      final response = await http.get(
        Uri.parse('$piServerUrl/camera/capture'),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to capture camera: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error capturing camera: $e');
    }
  }
  
  /// Display text on Pi HUD
  static Future<Map<String, dynamic>> displayHud({
    required String text,
    String position = 'center',
    int durationMs = 3000,
  }) async {
    try {
      final piServerUrl = await getPiServerUrl();
      final response = await http.post(
        Uri.parse('$piServerUrl/hud/display'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'position': position,
          'duration_ms': durationMs,
        }),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to display HUD: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error displaying HUD: $e');
    }
  }
  
  /// Speak text through Pi speaker
  static Future<Map<String, dynamic>> speak(String text) async {
    try {
      final piServerUrl = await getPiServerUrl();
      final response = await http.post(
        Uri.parse('$piServerUrl/speaker/speak'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': text}),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to speak: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error speaking: $e');
    }
  }
  
  // ============================================================================
  // BACKEND APIs
  // ============================================================================
  
  /// Voice assistant query
  static Future<Map<String, dynamic>> voiceAssistantQuery(String query) async {
    try {
      final backendUrl = await getBackendUrl();
      final response = await http.post(
        Uri.parse('$backendUrl/assistant/query'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed voice query: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error with voice assistant: $e');
    }
  }
  
  /// Face recognition
  static Future<Map<String, dynamic>> recognizeFaces({
    required String imageBase64,
    double threshold = 0.6,
  }) async {
    try {
      final backendUrl = await getBackendUrl();
      final response = await http.post(
        Uri.parse('$backendUrl/recognition/faces'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image_base64': imageBase64,
          'threshold': threshold,
        }),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed face recognition: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error with face recognition: $e');
    }
  }
  
  /// Object detection
  static Future<Map<String, dynamic>> detectObjects({
    required String imageBase64,
    double threshold = 0.5,
  }) async {
    try {
      final backendUrl = await getBackendUrl();
      final response = await http.post(
        Uri.parse('$backendUrl/detection/objects'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image_base64': imageBase64,
          'confidence_threshold': threshold,
        }),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed object detection: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error with object detection: $e');
    }
  }
  
  /// Translation workflow
  static Future<Map<String, dynamic>> translateImage({
    required String imageBase64,
    String targetLanguage = 'en',
  }) async {
    try {
      final backendUrl = await getBackendUrl();
      final response = await http.post(
        Uri.parse('$backendUrl/workflow/translate-image'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image_base64': imageBase64,
          'target_language': targetLanguage,
        }),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed translation: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error with translation: $e');
    }
  }
  
  /// Health check for backend
  static Future<bool> checkBackendHealth() async {
    try {
      final backendUrl = await getBackendUrl();
      final response = await http.get(
        Uri.parse('$backendUrl/health'),
      ).timeout(const Duration(seconds: 2));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Reset camera configuration to defaults
  static Future<Map<String, dynamic>> resetCameraSettings() async {
    try {
      final piUrl = await getPiServerUrl();
      final response = await http.post(
        Uri.parse('$piUrl/camera/config/reset'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to reset camera settings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error resetting camera settings: $e');
    }
  }
}
