import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';
import 'bluetooth_audio_service.dart';

/// API Service for communicating with Pi Server and App Backend
class ApiService {
  // Development mode flag - set to true to use localhost without pairing
  static const bool useDevelopmentBackend = true;  // Set to false for production
  
  // Server URLs - dynamically resolved from settings
  static Future<String> getPiServerUrl() async {
    return await BluetoothAudioService.getPiServerUrl();
  }
  
  static Future<String> getBackendUrl() async {
    // For development/testing: use localhost without requiring pairing
    if (useDevelopmentBackend) {
      return BackendConfig.getBackendUrl();
    }
    
    // For production: derive from Pi server URL
    try {
      final piUrl = await getPiServerUrl();
      // Backend runs on port 8002 on same host as Pi server
      return piUrl.replaceAll(':8001', ':8002');
    } catch (e) {
      // Fallback to localhost if Pi server discovery fails
      return BackendConfig.getBackendUrl();
    }
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
  
  // ============================================================================
  // LOCATION TRACKING APIs (HTTP Fallback)
  // ============================================================================
  
  /// Post single location update to backend (HTTP fallback)
  static Future<Map<String, dynamic>> postLocationUpdate({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
  }) async {
    try {
      final backendUrl = await getBackendUrl();
      
      // Create the JSON payload
      final payload = {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'altitude': altitude,
        'speed': speed,
        'heading': heading,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      
      // Log the exact JSON being sent
      print('📤 [ApiService] Sending location payload:');
      print('   URL: $backendUrl/location/update');
      print('   JSON: ${json.encode(payload)}');
      
      final response = await http.post(
        Uri.parse('$backendUrl/location/update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        print('✅ [ApiService] Location sent successfully');
        return json.decode(response.body);
      } else {
        print('❌ [ApiService] Failed with status: ${response.statusCode}');
        throw Exception('Failed to update location: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error posting location: $e');
    }
  }
  
  /// Post batch of location updates to backend
  static Future<Map<String, dynamic>> postLocationBatch(
    List<Map<String, dynamic>> locations
  ) async {
    try {
      final backendUrl = await getBackendUrl();
      final response = await http.post(
        Uri.parse('$backendUrl/location/batch'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'locations': locations}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to post batch: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error posting batch: $e');
    }
  }
  
  /// Get current location from backend (if stored)
  static Future<Map<String, dynamic>> getCurrentLocationFromBackend() async {
    try {
      final backendUrl = await getBackendUrl();
      final response = await http.get(
        Uri.parse('$backendUrl/location/current'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get location: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting location: $e');
    }
  }
}
