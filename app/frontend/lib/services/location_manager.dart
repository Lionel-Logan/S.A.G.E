import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../models/location_data.dart';
import '../config/backend_config.dart';
import 'location_service.dart';
import 'location_websocket_service.dart';
import 'api_service.dart';

/// Location Manager - Orchestrates location tracking and transmission
/// Handles both WebSocket (primary) and HTTP (fallback) communication
class LocationManager {
  static bool _isRunning = false;
  static StreamSubscription<Position>? _positionSubscription;
  static StreamSubscription<NavigationUpdate>? _navigationSubscription;
  static LocationData? _lastSentLocation;
  static int _consecutiveFailures = 0;
  static bool _useWebSocket = true;
  static Timer? _healthCheckTimer;

  // Statistics
  static int _totalUpdatesSent = 0;
  static int _updatesFailed = 0;
  static DateTime? _trackingStartTime;

  /// Check if location tracking is active
  static bool get isRunning => _isRunning;

  /// Get last sent location
  static LocationData? get lastSentLocation => _lastSentLocation;

  /// Get tracking statistics
  static Map<String, dynamic> get statistics => {
        'is_running': _isRunning,
        'total_updates_sent': _totalUpdatesSent,
        'updates_failed': _updatesFailed,
        'consecutive_failures': _consecutiveFailures,
        'using_websocket': _useWebSocket,
        'tracking_duration_seconds': _trackingStartTime != null
            ? DateTime.now().difference(_trackingStartTime!).inSeconds
            : 0,
      };

  // ============================================================================
  // START/STOP TRACKING
  // ============================================================================

  /// Start location tracking and transmission for navigation
  static Future<bool> startNavigationMode() async {
    if (_isRunning) {
      debugPrint('⚠️ [LocationManager] Already running');
      return true;
    }

    debugPrint('🚀 [LocationManager] Starting NAVIGATION mode...');

    // Check and request permissions
    if (!await LocationService.hasPermission()) {
      final granted = await LocationService.requestPermission();
      if (!granted) {
        debugPrint('❌ [LocationManager] Permission denied');
        return false;
      }
    }

    // Start location tracking with navigation settings
    final trackingStarted =
        await LocationService.startNavigationTracking();
    if (!trackingStarted) {
      debugPrint('❌ [LocationManager] Failed to start location tracking');
      return false;
    }

    // Connect WebSocket
    _useWebSocket = await LocationWebSocketService.connect();
    if (!_useWebSocket) {
      debugPrint('⚠️ [LocationManager] WebSocket unavailable, using HTTP fallback');
    }

    // Subscribe to location updates
    _positionSubscription =
        LocationService.positionStream?.listen(_handleLocationUpdate);

    // Subscribe to navigation updates from backend
    _navigationSubscription =
        LocationWebSocketService.navigationUpdates.listen(_handleNavigationUpdate);

    // Start health check timer
    _startHealthCheck();

    _isRunning = true;
    _trackingStartTime = DateTime.now();
    _totalUpdatesSent = 0;
    _updatesFailed = 0;
    _consecutiveFailures = 0;

    debugPrint('✅ [LocationManager] Started successfully in NAVIGATION mode');
    debugPrint('📊 [LocationManager] WebSocket: $_useWebSocket, Tracking: ${LocationService.isTracking}');
    return true;
  }

  /// Start location tracking in normal mode (less frequent updates)
  static Future<bool> startNormalMode() async {
    if (_isRunning) return true;

    if (!await LocationService.hasPermission()) {
      if (!await LocationService.requestPermission()) {
        return false;
      }
    }

    final trackingStarted = await LocationService.startNormalTracking();
    if (!trackingStarted) return false;

    _useWebSocket = await LocationWebSocketService.connect();
    _positionSubscription =
        LocationService.positionStream?.listen(_handleLocationUpdate);
    _navigationSubscription =
        LocationWebSocketService.navigationUpdates.listen(_handleNavigationUpdate);

    _startHealthCheck();
    _isRunning = true;
    _trackingStartTime = DateTime.now();

    debugPrint('✅ [LocationManager] Started in NORMAL mode');
    return true;
  }

  /// Stop location tracking and transmission
  static Future<void> stop() async {
    if (!_isRunning) return;

    debugPrint('🛑 [LocationManager] Stopping...');

    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    await _positionSubscription?.cancel();
    await _navigationSubscription?.cancel();
    await LocationService.stopTracking();
    await LocationWebSocketService.disconnect();

    _positionSubscription = null;
    _navigationSubscription = null;
    _isRunning = false;
    _trackingStartTime = null;

    debugPrint('✅ [LocationManager] Stopped');
    debugPrint('📋 [LocationManager] Final stats: $_totalUpdatesSent sent, $_updatesFailed failed');
  }

  // ============================================================================
  // LOCATION UPDATE HANDLING
  // ============================================================================

  /// Handle new location update from GPS
  static void _handleLocationUpdate(Position position) async {
    print('\n🎯 [LocationManager] ← Received position from LocationService');
    print('   Converting Position → LocationData...');
    
    final locationData = LocationData.fromPosition(position);
    print('   ✓ LocationData created');

    // Filter out low-accuracy readings
    if (!LocationService.isAccuracyAcceptable(position)) {
      print('⚠️ [LocationManager] ✗ REJECTED: Low accuracy ${position.accuracy.toStringAsFixed(1)}m');
      return;
    }
    print('   ✓ Accuracy acceptable: ${position.accuracy.toStringAsFixed(1)}m');

    // Skip redundant updates when stationary (if configured)
    if (BackendConfig.skipStationaryUpdates) {
      if (!locationData.isSignificantlyDifferentFrom(_lastSentLocation)) {
        print('⚠️ [LocationManager] ✗ SKIPPED: No significant movement');
        return;
      }
    }
    print('   ✓ Position validated, preparing to send...');
    
    // Send location to backend
    await _sendLocation(locationData);
  }

  /// Send location to backend (WebSocket or HTTP fallback)
  static Future<void> _sendLocation(LocationData location) async {
    try {
      if (_useWebSocket && LocationWebSocketService.isConnected) {
        // Send via WebSocket (primary method)
        print('\n📤 [LocationManager] → Sending via WebSocket');
        print('   Coordinates: (${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)})');
        LocationWebSocketService.sendLocation(location);
        _onSendSuccess(location);
      } else {
        // Fallback to HTTP
        print('\n📡 [LocationManager] → Sending via HTTP (WebSocket unavailable)');
        print('   Coordinates: (${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)})');
        print('   Calling ApiService.postLocationUpdate()...');
        await _sendViaHttp(location);
      }
    } catch (e) {
      print('❌ [LocationManager] Error sending location: $e');
      _onSendFailure();
    }
  }

  /// Send location via HTTP (fallback method)
  static Future<void> _sendViaHttp(LocationData location) async {
    try {
      print('   Invoking HTTP POST...');
      final response = await ApiService.postLocationUpdate(
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracy,
        altitude: location.altitude,
        speed: location.speed,
        heading: location.heading,
      );
      print('✅ [LocationManager] ✓ HTTP POST completed successfully');
      _onSendSuccess(location);
    } catch (e) {
      print('❌ [LocationManager] ✗ HTTP POST failed: $e');
      _onSendFailure();
    }
  }

  /// Handle successful location send
  static void _onSendSuccess(LocationData location) {
    _lastSentLocation = location;
    _totalUpdatesSent++;
    _consecutiveFailures = 0;

    // Log every 10th update
    if (_totalUpdatesSent % 10 == 0) {
      debugPrint('📊 [LocationManager] Progress: $_totalUpdatesSent updates sent successfully');
    }
  }

  /// Handle failed location send
  static void _onSendFailure() {
    _updatesFailed++;
    _consecutiveFailures++;

    // If too many consecutive failures, try reconnecting WebSocket
    if (_consecutiveFailures >= 5 && _useWebSocket) {
      debugPrint('⚠️ [LocationManager] Too many failures ($_consecutiveFailures), reconnecting WebSocket...');
      _reconnectWebSocket();
    }
  }

  // ============================================================================
  // NAVIGATION UPDATE HANDLING
  // ============================================================================

  /// Handle navigation update from backend
  static void _handleNavigationUpdate(NavigationUpdate update) {
    debugPrint('🧭 [LocationManager] Navigation: ${update.instruction}');
    // Additional handling can be added here (e.g., emit to UI stream)
  }

  // ============================================================================
  // HEALTH CHECK & RECONNECTION
  // ============================================================================

  /// Start periodic health check
  static void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performHealthCheck(),
    );
  }

  /// Perform health check
  static void _performHealthCheck() {
    // Check WebSocket connection
    if (_useWebSocket && !LocationWebSocketService.isConnected) {
      debugPrint('❤️‍🩹 [LocationManager] Health check: WebSocket disconnected, reconnecting...');
      _reconnectWebSocket();
    }

    // Check location service
    if (!LocationService.isTracking) {
      debugPrint('⚠️ [LocationManager] Health check: Location tracking stopped unexpectedly');
      // Could attempt to restart tracking here
    }

    // Log statistics
    debugPrint('📊 [LocationManager] Health: ${_totalUpdatesSent} sent, ${_updatesFailed} failed, WS: ${LocationWebSocketService.isConnected}');
  }

  /// Reconnect WebSocket
  static Future<void> _reconnectWebSocket() async {
    await LocationWebSocketService.reconnect();
    _consecutiveFailures = 0;
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Get current location once (without starting continuous tracking)
  static Future<LocationData?> getCurrentLocation() async {
    final position = await LocationService.getCurrentLocation();
    if (position == null) return null;
    return LocationData.fromPosition(position);
  }

  /// Send location update immediately (one-time)
  static Future<bool> sendLocationNow() async {
    final location = await getCurrentLocation();
    if (location == null) return false;

    await _sendLocation(location);
    return true;
  }

  /// Switch between WebSocket and HTTP mode
  static void setUseWebSocket(bool useWs) {
    _useWebSocket = useWs;
    print('Switched to ${useWs ? "WebSocket" : "HTTP"} mode');
  }

  /// Reset statistics
  static void resetStatistics() {
    _totalUpdatesSent = 0;
    _updatesFailed = 0;
    _consecutiveFailures = 0;
  }
}
