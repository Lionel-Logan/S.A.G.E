import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import '../config/backend_config.dart';
import '../models/location_data.dart';
import 'api_service.dart';

/// WebSocket service for real-time location streaming to backend
/// Optimized for navigation with minimal latency
class LocationWebSocketService {
  static WebSocketChannel? _channel;
  static StreamSubscription? _messageSubscription;
  static bool _isConnected = false;
  static Timer? _reconnectTimer;
  static int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // Stream controllers for navigation updates from backend
  static final _navigationUpdateController =
      StreamController<NavigationUpdate>.broadcast();

  // Stream controllers for connection status
  static final _connectionStatusController =
      StreamController<bool>.broadcast();

  /// Stream of navigation updates from backend
  static Stream<NavigationUpdate> get navigationUpdates =>
      _navigationUpdateController.stream;

  /// Stream of connection status changes
  static Stream<bool> get connectionStatus =>
      _connectionStatusController.stream;

  /// Check if WebSocket is connected
  static bool get isConnected => _isConnected;

  // ============================================================================
  // CONNECTION MANAGEMENT
  // ============================================================================

  /// Connect to backend WebSocket for location streaming
  static Future<bool> connect() async {
    if (_isConnected) {
      debugPrint('⚠️ [LocationWebSocket] Already connected');
      return true;
    }

    try {
      // Get backend URL and convert to WebSocket URL
      final backendUrl = await ApiService.getBackendUrl();
      final wsUrl = BackendConfig.getWebSocketUrl(backendUrl);
      final fullWsUrl = '$wsUrl${BackendConfig.locationWebSocketEndpoint}';

      debugPrint('🔌 [LocationWebSocket] Connecting to: $fullWsUrl');

      // Create WebSocket connection with timeout
      final channel = WebSocketChannel.connect(
        Uri.parse(fullWsUrl),
      );
      
      // Set a timeout to verify the connection actually works
      // The stream.listen will handle the actual connection
      _channel = channel;

      // Listen for messages from backend
      // This where the actual connection is established
      _messageSubscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStatusController.add(true);

      debugPrint('✅ [LocationWebSocket] Connected successfully');
      return true;
    } catch (e) {
      debugPrint('❌ [LocationWebSocket] Connection error: $e');
      _isConnected = false;
      _connectionStatusController.add(false);
      
      // Clean up the failed channel
      try {
        await _channel?.sink.close();
      } catch (_) {}
      _channel = null;
      
      // Attempt to reconnect
      _scheduleReconnect();
      
      return false;
    }
  }

  /// Disconnect WebSocket
  static Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _messageSubscription?.cancel();
    await _channel?.sink.close();

    _messageSubscription = null;
    _channel = null;
    _isConnected = false;
    _reconnectAttempts = 0;

    _connectionStatusController.add(false);

    debugPrint('🛑 [LocationWebSocket] Disconnected');
  }

  // ============================================================================
  // MESSAGE HANDLING
  // ============================================================================

  /// Handle incoming messages from backend
  static void _handleMessage(dynamic message) {
    try {
      final data = json.decode(message as String);

      // Check message type
      final type = data['type'];

      if (type == 'navigation_update') {
        // Parse navigation update
        final updateData = data['data'];
        final navigationUpdate = NavigationUpdate.fromJson(updateData);
        _navigationUpdateController.add(navigationUpdate);
        
        debugPrint('🧭 [LocationWebSocket] Navigation: ${navigationUpdate.instruction}');
      } else {
        debugPrint('⚠️ [LocationWebSocket] Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('❌ [LocationWebSocket] Error parsing message: $e');
    }
  }

  /// Handle WebSocket errors
  static void _handleError(error) {
    debugPrint('❌ [LocationWebSocket] Error: $error');
    _isConnected = false;
    _connectionStatusController.add(false);
    
    // Attempt to reconnect
    _scheduleReconnect();
  }

  /// Handle WebSocket disconnect
  static void _handleDisconnect() {
    debugPrint('⚠️ [LocationWebSocket] Connection closed');
    _isConnected = false;
    _connectionStatusController.add(false);
    
    // Attempt to reconnect
    _scheduleReconnect();
  }

  // ============================================================================
  // RECONNECTION LOGIC
  // ============================================================================

  /// Schedule automatic reconnection
  static void _scheduleReconnect() {
    if (_reconnectTimer != null) return; // Already scheduled
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ [LocationWebSocket] Max reconnection attempts ($_maxReconnectAttempts) reached');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(
      seconds: BackendConfig.websocketReconnectDelaySeconds * _reconnectAttempts,
    );

    debugPrint('🔄 [LocationWebSocket] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      debugPrint('🔄 [LocationWebSocket] Attempting reconnect...');
      final connected = await connect();
      
      if (!connected && _reconnectAttempts < _maxReconnectAttempts) {
        _scheduleReconnect();
      }
    });
  }

  /// Manually trigger reconnection
  static Future<void> reconnect() async {
    await disconnect();
    _reconnectAttempts = 0;
    await connect();
  }

  // ============================================================================
  // SEND LOCATION DATA
  // ============================================================================

  /// Send location update via WebSocket
  static void sendLocation(LocationData location) {
    if (!_isConnected || _channel == null) {
      debugPrint('⚠️ [LocationWebSocket] Not connected, cannot send');
      return;
    }

    try {
      // Use compact JSON format for efficiency
      final data = location.toCompactJson();
      final jsonString = json.encode(data);

      _channel!.sink.add(jsonString);
      
      // Log every 20th update to avoid spam
      if (location.latitude.hashCode % 20 == 0) {
        debugPrint('📤 [LocationWebSocket] Sent: (${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)})');
      }
    } catch (e) {
      debugPrint('❌ [LocationWebSocket] Send error: $e');
    }
  }

  /// Send multiple location updates at once (batch)
  static void sendLocationBatch(List<LocationData> locations) {
    if (!_isConnected || _channel == null) {
      debugPrint('⚠️ [LocationWebSocket] Not connected, cannot send batch');
      return;
    }

    try {
      final data = {
        'type': 'batch',
        'locations': locations.map((loc) => loc.toCompactJson()).toList(),
      };
      final jsonString = json.encode(data);

      _channel!.sink.add(jsonString);
      
      debugPrint('📦 [LocationWebSocket] Sent batch: ${locations.length} locations');
    } catch (e) {
      debugPrint('❌ [LocationWebSocket] Batch send error: $e');
    }
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  /// Dispose all resources
  static Future<void> dispose() async {
    await disconnect();
    await _navigationUpdateController.close();
    await _connectionStatusController.close();
  }
}
