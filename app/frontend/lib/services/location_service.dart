import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import '../config/backend_config.dart';

/// Service for managing location tracking using GPS
/// Handles permissions, location stream, and accuracy settings
class LocationService {
  static StreamSubscription<Position>? _positionStream;
  static StreamController<Position>? _positionController;
  static bool _isTracking = false;
  static Position? _lastPosition;

  /// Stream of GPS position updates
  static Stream<Position>? get positionStream => _positionController?.stream;

  /// Check if currently tracking location
  static bool get isTracking => _isTracking;

  /// Get the last known position
  static Position? get lastPosition => _lastPosition;

  // ============================================================================
  // PERMISSION MANAGEMENT
  // ============================================================================

  /// Check if location permissions are granted
  static Future<bool> hasPermission() async {
    final permission = await Permission.location.status;
    return permission.isGranted;
  }

  /// Request location permissions
  static Future<bool> requestPermission() async {
    debugPrint('🌍 [LocationService] Requesting location permission...');
    final status = await Permission.location.request();
    debugPrint(status.isGranted ? '✅ [LocationService] Permission granted' : '❌ [LocationService] Permission denied');
    return status.isGranted;
  }

  /// Request background location permission (for continuous tracking)
  static Future<bool> requestBackgroundPermission() async {
    // First ensure we have regular location permission
    if (!await hasPermission()) {
      if (!await requestPermission()) {
        return false;
      }
    }

    // Then request background location
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// Check location service status
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // ============================================================================
  // LOCATION SETTINGS
  // ============================================================================

  /// Get location settings optimized for navigation
  static LocationSettings getNavigationSettings() {
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0, // Get all updates for navigation
      // No timeLimit - let it wait as long as needed for first position
      // timeLimit will cause timeout errors on emulator/devices without GPS
    );
  }

  /// Get location settings for normal tracking (battery-optimized)
  static LocationSettings getNormalSettings() {
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: BackendConfig.minDistanceFilterMeters.toInt(),
    );
  }

  /// Get location settings for idle mode (minimal battery)
  static LocationSettings getIdleSettings() {
    return const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 20, // Only update every 20 meters
    );
  }

  // ============================================================================
  // LOCATION TRACKING
  // ============================================================================

  /// Start tracking location with navigation-level accuracy
  static Future<bool> startNavigationTracking() async {
    return await _startTracking(getNavigationSettings());
  }

  /// Start tracking location with normal accuracy
  static Future<bool> startNormalTracking() async {
    return await _startTracking(getNormalSettings());
  }

  /// Start tracking location with idle mode settings
  static Future<bool> startIdleTracking() async {
    return await _startTracking(getIdleSettings());
  }

  /// Internal method to start tracking with specific settings
  static Future<bool> _startTracking(LocationSettings settings) async {
    if (_isTracking) {
      debugPrint('⚠️ [LocationService] Already tracking location');
      return true;
    }

    // Check permissions
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        debugPrint('❌ [LocationService] Location permission denied');
        return false;
      }
    }

    // Check if location service is enabled
    if (!await isLocationServiceEnabled()) {
      debugPrint('❌ [LocationService] Location service is disabled');
      return false;
    }

    try {
      // Create stream controller
      _positionController = StreamController<Position>.broadcast();

      // Start listening to position stream
      debugPrint('🎧 [LocationService] Setting up position stream listener...');
      _positionStream = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (Position position) {
          print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('📍 [LocationService] GPS POSITION RECEIVED');
          print('   Latitude:  ${position.latitude.toStringAsFixed(6)}');
          print('   Longitude: ${position.longitude.toStringAsFixed(6)}');
          print('   Accuracy:  ±${position.accuracy.toStringAsFixed(1)}m');
          print('   Speed:     ${(position.speed * 3.6).toStringAsFixed(1)} km/h');
          print('   Altitude:  ${position.altitude.toStringAsFixed(1)}m');
          print('   Heading:   ${position.heading.toStringAsFixed(1)}°');
          print('   Timestamp: ${position.timestamp}');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
          
          _lastPosition = position;
          _positionController?.add(position);
        },
        onError: (error) {
          print('❌ [LocationService] Stream error: $error');
        },
      );

      _isTracking = true;
      debugPrint('✅ [LocationService] Tracking started (accuracy: ${settings.accuracy}, filter: ${settings.distanceFilter}m)');
      return true;
    } catch (e) {
      debugPrint('❌ [LocationService] Error starting tracking: $e');
      return false;
    }
  }

  /// Stop tracking location
  static Future<void> stopTracking() async {
    if (!_isTracking) return;

    await _positionStream?.cancel();
    await _positionController?.close();
    _positionStream = null;
    _positionController = null;
    _isTracking = false;

    debugPrint('🛑 [LocationService] Tracking stopped');
  }

  // ============================================================================
  // ONE-TIME LOCATION QUERY
  // ============================================================================

  /// Get current location once (no streaming)
  static Future<Position?> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    // Check permissions
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        debugPrint('❌ [LocationService] Permission denied for getCurrentLocation');
        return null;
      }
    }

    // Check if location service is enabled
    if (!await isLocationServiceEnabled()) {
      debugPrint('❌ [LocationService] Location service disabled for getCurrentLocation');
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: const Duration(seconds: 10),
      );

      _lastPosition = position;
      debugPrint('📍 [LocationService] Current location: (${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}) ±${position.accuracy.toStringAsFixed(1)}m');
      return position;
    } catch (e) {
      debugPrint('❌ [LocationService] Error getting current location: $e');
      return null;
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Calculate distance between two positions (in meters)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Check if position has acceptable accuracy
  static bool isAccuracyAcceptable(Position position) {
    return position.accuracy <= BackendConfig.minAccuracyMeters;
  }

  /// Check if position represents stationary user
  static bool isStationary(Position current, Position? previous) {
    if (previous == null) return false;

    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );

    final speed = current.speed;

    return distance < BackendConfig.stationaryDistanceThreshold &&
        speed < BackendConfig.stationarySpeedThreshold;
  }

  /// Open location settings on device
  static Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Open app settings
  static Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
