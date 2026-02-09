/// Backend Configuration for S.A.G.E
/// 
/// Contains configuration for the FastAPI backend server,
/// WebSocket connections, and location tracking settings

class BackendConfig {
  // ============================================================================
  // DEBUG MODE
  // ============================================================================
  
  /// Enable debug mode for detailed logging and testing without backend
  /// Set to true to log all location updates and WebSocket messages to console
  static const bool debugMode = true;
  
  /// Mock WebSocket connection when backend is not available (for testing)
  static const bool mockWebSocketWhenOffline = true;
  
  // ============================================================================
  // BACKEND SERVER URLs
  // ============================================================================
  
  /// Development/Local backend URL
  /// The FastAPI backend runs on port 8000
  static const String localhostUrl = 'http://localhost:8000';
  
  /// Android emulator needs to use 10.0.2.2 instead of localhost
  static const String localhostAndroidEmulatorUrl = 'http://10.0.2.2:8000';
  
  /// Production backend URL (update when deployed)
  static const String productionUrl = 'http://your-backend-url.com';
  
  // ============================================================================
  // WEBSOCKET CONFIGURATION
  // ============================================================================
  
  /// WebSocket endpoint for live location streaming
  /// Backend team will implement: ws://backend/ws/location/{device_id}
  static const String websocketPath = '/ws/location';
  
  /// WebSocket reconnection settings
  static const int websocketMaxReconnectAttempts = 3;
  static const int websocketReconnectDelaySeconds = 5;
  static const int websocketReconnectMaxDelaySeconds = 60; // Max exponential backoff
  
  /// WebSocket heartbeat/ping interval (seconds)
  static const int websocketPingIntervalSeconds = 30;
  
  /// WebSocket timeout - consider backend unreachable after this duration
  static const int websocketTimeoutSeconds = 300; // 5 minutes
  
  // ============================================================================
  // LOCATION TRACKING CONFIGURATION
  // ============================================================================
  
  /// Moving Mode (Active Navigation) - Google Maps level accuracy
  /// Update every 3 seconds OR 5 meters, whichever comes first
  static const int movingModeUpdateIntervalSeconds = 3;
  static const double movingModeDistanceFilterMeters = 5.0;
  
  /// Stationary Mode (Battery Saver)
  /// Reduced frequency when user is not moving
  static const int stationaryModeUpdateIntervalSeconds = 20;
  static const double stationaryModeDistanceFilterMeters = 20.0;
  
  /// Speed threshold to detect stationary vs moving (meters/second)
  /// 0.5 m/s = 1.8 km/h (slower than slow walking)
  static const double stationarySpeedThreshold = 0.5;
  
  /// Time to wait before switching to stationary mode (seconds)
  static const int stationaryDetectionDelaySeconds = 30;
  
  /// Minimum acceptable location accuracy (in meters)
  /// Updates with accuracy worse than this will be filtered out
  static const double minAccuracyMeters = 50.0;
  
  // ============================================================================
  // LOCATION QUEUE CONFIGURATION
  // ============================================================================
  
  /// Maximum number of location updates to queue when WebSocket is disconnected
  /// Prevents memory overflow during extended disconnections
  static const int maxQueuedLocationUpdates = 50;
  
  /// Whether to batch-send queued updates or send one-by-one
  static const bool batchSendQueuedUpdates = true;
  
  /// Batch size for sending queued updates
  static const int queuedUpdatesBatchSize = 10;
  
  // ============================================================================
  // BACKGROUND SERVICE CONFIGURATION
  // ============================================================================
  
  /// Notification title for background location tracking
  static const String backgroundNotificationTitle = 'Navigation started by S.A.G.E';
  
  /// Notification message
  static const String backgroundNotificationMessage = 'Sharing live location with backend';
  
  /// Notification channel ID (Android)
  static const String notificationChannelId = 'sage_location_tracking';
  
  /// Notification channel name
  static const String notificationChannelName = 'Location Tracking';
  
  /// Notification ID
  static const int notificationId = 1001;
  
  // ============================================================================
  // API ENDPOINTS
  // ============================================================================
  
  /// Location REST API endpoints (HTTP fallback if WebSocket fails)
  static const String locationUpdateEndpoint = '/api/v1/location/update';
  static const String locationBatchEndpoint = '/api/v1/location/batch';
  static const String locationCurrentEndpoint = '/api/v1/location/current';
  
  // ============================================================================
  // HELPER METHODS
  // ============================================================================
  
  /// Get appropriate backend URL based on platform
  static String getBackendUrl({bool isEmulator = false}) {
    // In production, use productionUrl
    // For now, use localhost
    if (isEmulator) {
      return localhostAndroidEmulatorUrl;
    }
    return localhostUrl;
  }
  
  /// Get WebSocket URL from HTTP URL
  static String getWebSocketUrl(String httpUrl, String deviceId) {
    // Convert http:// to ws://
    final wsUrl = httpUrl.replaceFirst('http', 'ws');
    return '$wsUrl$websocketPath/$deviceId';
  }
  
  /// Get full WebSocket URL for the device
  static String getDeviceWebSocketUrl(String deviceId, {bool isEmulator = false}) {
    final baseUrl = getBackendUrl(isEmulator: isEmulator);
    return getWebSocketUrl(baseUrl, deviceId);
  }
}
