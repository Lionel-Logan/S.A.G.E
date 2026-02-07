/// Backend Configuration for S.A.G.E
/// 
/// Contains configuration for the FastAPI backend server
/// and location tracking settings

class BackendConfig {
  // ============================================================================
  // BACKEND SERVER URLs
  // ============================================================================
  
  /// Development/Local backend URL
  /// The FastAPI backend runs on port 8002 (separate from Pi server on 8001)
  static const String localhostUrl = 'http://localhost:8002';
  
  /// Android emulator needs to use 10.0.2.2 instead of localhost
  static const String localhostAndroidEmulatorUrl = 'http://10.0.2.2:8002';
  
  /// Production backend URL (update when deployed)
  static const String productionUrl = 'http://your-backend-url.com';
  
  // ============================================================================
  // API ENDPOINTS
  // ============================================================================
  
  /// Location endpoints (to be implemented by backend team)
  static const String locationUpdateEndpoint = '/api/v1/location/update';
  static const String locationBatchEndpoint = '/api/v1/location/batch';
  static const String locationWebSocketEndpoint = '/api/v1/location/stream';
  
  // ============================================================================
  // LOCATION TRACKING SETTINGS
  // ============================================================================
  
  /// How often to send location updates during navigation (in seconds)
  static const int navigationUpdateIntervalSeconds = 1;
  
  /// Minimum distance change to trigger update (in meters)
  /// Set to 0 for time-based updates only
  static const double minDistanceFilterMeters = 0.0;
  
  /// Maximum number of location updates to batch before sending
  static const int maxBatchSize = 10;
  
  /// Maximum time to wait before sending a batch (in seconds)
  static const int maxBatchWaitSeconds = 5;
  
  /// Maximum number of retry attempts for failed requests
  static const int maxRetryAttempts = 3;
  
  /// Delay between retry attempts (in seconds)
  static const int retryDelaySeconds = 2;
  
  /// Request timeout for HTTP requests (in seconds)
  static const int requestTimeoutSeconds = 5;
  
  /// WebSocket reconnect delay (in seconds)
  static const int websocketReconnectDelaySeconds = 2;
  
  // ============================================================================
  // LOCATION ACCURACY SETTINGS
  // ============================================================================
  
  /// Minimum acceptable location accuracy (in meters)
  /// Updates with accuracy worse than this will be filtered out
  static const double minAccuracyMeters = 50.0;
  
  /// Skip updates when stationary (distance < threshold and speed low)
  static const bool skipStationaryUpdates = true;
  static const double stationaryDistanceThreshold = 2.0; // meters
  static const double stationarySpeedThreshold = 0.5; // m/s
  
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
  static String getWebSocketUrl(String httpUrl) {
    return httpUrl.replaceFirst('http', 'ws');
  }
}
