import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/location_update.dart';
import '../config/backend_config.dart';

/// Service for managing GPS location tracking
/// Handles permission requests, location streaming, and smart mode switching
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Stream controllers
  final _locationStreamController = StreamController<LocationUpdate>.broadcast();
  final _statusStreamController = StreamController<LocationServiceStatus>.broadcast();

  // Internal state
  StreamSubscription<Position>? _positionSubscription;
  LocationUpdate? _lastLocation;
  DateTime? _lastMovementTime;
  bool _isTracking = false;
  LocationTrackingMode _currentMode = LocationTrackingMode.moving;

  // Getters
  Stream<LocationUpdate> get locationStream => _locationStreamController.stream;
  Stream<LocationServiceStatus> get statusStream => _statusStreamController.stream;
  bool get isTracking => _isTracking;
  LocationTrackingMode get currentMode => _currentMode;
  LocationUpdate? get lastLocation => _lastLocation;

  /// Request location permissions
  /// Returns true if granted, false otherwise
  Future<bool> requestLocationPermission() async {
    print('📍 [LocationService] Requesting location permissions...');
    
    // Check current permission status
    PermissionStatus status = await Permission.location.status;
    
    if (status.isGranted) {
      print('✅ [LocationService] Location permission already granted');
      return true;
    }

    // Request permission
    status = await Permission.location.request();
    
    if (status.isGranted) {
      print('✅ [LocationService] Location permission granted');
      return true;
    } else if (status.isPermanentlyDenied) {
      print('❌ [LocationService] Location permission permanently denied');
      // Open app settings
      await openAppSettings();
      return false;
    } else {
      print('❌ [LocationService] Location permission denied');
      return false;
    }
  }

  /// Request background location permission (Android 10+)
  Future<bool> requestBackgroundLocationPermission() async {
    print('📍 [LocationService] Requesting background location permission...');
    
    // First, ensure foreground permission is granted
    final foregroundGranted = await requestLocationPermission();
    if (!foregroundGranted) {
      print('❌ [LocationService] Foreground permission not granted');
      return false;
    }

    // Request background permission
    PermissionStatus status = await Permission.locationAlways.status;
    
    if (status.isGranted) {
      print('✅ [LocationService] Background location permission already granted');
      return true;
    }

    status = await Permission.locationAlways.request();
    
    if (status.isGranted) {
      print('✅ [LocationService] Background location permission granted');
      return true;
    } else {
      print('⚠️ [LocationService] Background location permission denied');
      // App can still track in foreground
      return false;
    }
  }

  /// Check if location services are enabled on device
  Future<bool> isLocationServiceEnabled() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      print('❌ [LocationService] Location services are disabled on device');
    }
    return enabled;
  }

  /// Start location tracking
  /// Automatically switches between moving and stationary modes
  Future<void> startTracking({LocationTrackingMode initialMode = LocationTrackingMode.moving}) async {
    if (_isTracking) {
      print('⚠️ [LocationService] Already tracking location');
      return;
    }

    print('🚀 [LocationService] Starting location tracking (mode: ${initialMode.name})...');

    // Check permissions
    final hasPermission = await requestLocationPermission();
    if (!hasPermission) {
      _updateStatus(LocationServiceStatus.permissionDenied);
      throw Exception('Location permission not granted');
    }

    // Check if location services are enabled
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      _updateStatus(LocationServiceStatus.serviceDisabled);
      throw Exception('Location services are disabled');
    }

    // Set initial mode
    _currentMode = initialMode;
    _isTracking = true;
    _lastMovementTime = DateTime.now();
    _updateStatus(LocationServiceStatus.active);

    // Get location settings based on mode
    final settings = _getLocationSettings(_currentMode);

    // Start listening to position stream
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      _onPositionUpdate,
      onError: _onPositionError,
      cancelOnError: false,
    );

    print('✅ [LocationService] Location tracking started');
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    if (!_isTracking) {
      print('⚠️ [LocationService] Location tracking not active');
      return;
    }

    print('🛑 [LocationService] Stopping location tracking...');

    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    _updateStatus(LocationServiceStatus.stopped);

    print('✅ [LocationService] Location tracking stopped');
  }

  /// Handle incoming position updates
  void _onPositionUpdate(Position position) {
    final location = LocationUpdate(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
      timestamp: position.timestamp ?? DateTime.now(),
    );

    // Validate location accuracy
    if (!location.isValid(BackendConfig.minAccuracyMeters)) {
      print('⚠️ [LocationService] Location filtered (poor accuracy: ${location.accuracy}m)');
      return;
    }

    // Detect movement and switch modes if needed
    _analyzeMovement(location);

    // Update last location
    _lastLocation = location;

    // Emit location update
    _locationStreamController.add(location);

    // Detailed debug logging
    if (BackendConfig.debugMode) {
      print('\n╔═══════════════════════════════════════════════════════════╗');
      print('║ 📍 LOCATION UPDATE                                        ║');
      print('╠═══════════════════════════════════════════════════════════╣');
      print('║ Latitude:  ${location.latitude.toStringAsFixed(8).padRight(40)}║');
      print('║ Longitude: ${location.longitude.toStringAsFixed(8).padRight(40)}║');
      print('║ Accuracy:  ${(location.accuracy?.toStringAsFixed(1) ?? 'N/A').padRight(40)}m║');
      print('║ Speed:     ${(location.speed?.toStringAsFixed(2) ?? 'N/A').padRight(40)}m/s║');
      print('║ Heading:   ${(location.heading?.toStringAsFixed(1) ?? 'N/A').padRight(40)}°║');
      print('║ Altitude:  ${(location.altitude?.toStringAsFixed(1) ?? 'N/A').padRight(40)}m║');
      print('║ Mode:      ${_currentMode.name.toUpperCase().padRight(40)}║');
      print('╚═══════════════════════════════════════════════════════════╝\n');
    } else {
      print('📍 [LocationService] Location update: ${location.latitude.toStringAsFixed(6)}, '
          '${location.longitude.toStringAsFixed(6)} '
          '(accuracy: ${location.accuracy?.toStringAsFixed(1)}m, '
          'speed: ${location.speed?.toStringAsFixed(1)}m/s, '
          'mode: ${_currentMode.name})');
    }
  }

  /// Analyze movement and switch tracking modes
  void _analyzeMovement(LocationUpdate newLocation) {
    final speed = newLocation.speed ?? 0.0;
    final now = DateTime.now();

    // Check if user is stationary or moving
    final isStationary = speed < BackendConfig.stationarySpeedThreshold;

    if (isStationary) {
      // User is stationary
      if (_currentMode == LocationTrackingMode.moving) {
        // Check if stationary for long enough to switch modes
        final timeSinceLastMovement = now.difference(_lastMovementTime ?? now).inSeconds;
        
        if (timeSinceLastMovement >= BackendConfig.stationaryDetectionDelaySeconds) {
          print('🔄 [LocationService] Switching to STATIONARY mode (battery saver)');
          _switchMode(LocationTrackingMode.stationary);
        }
      }
    } else {
      // User is moving
      _lastMovementTime = now;
      
      if (_currentMode == LocationTrackingMode.stationary) {
        print('🔄 [LocationService] Switching to MOVING mode (high accuracy)');
        _switchMode(LocationTrackingMode.moving);
      }
    }
  }

  /// Switch tracking mode (moving ↔ stationary)
  void _switchMode(LocationTrackingMode newMode) {
    if (_currentMode == newMode || !_isTracking) return;

    _currentMode = newMode;
    
    // Restart position stream with new settings
    _positionSubscription?.cancel();
    
    final settings = _getLocationSettings(newMode);
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      _onPositionUpdate,
      onError: _onPositionError,
      cancelOnError: false,
    );

    _updateStatus(LocationServiceStatus.modeChanged);
  }

  /// Get location settings based on tracking mode
  LocationSettings _getLocationSettings(LocationTrackingMode mode) {
    switch (mode) {
      case LocationTrackingMode.moving:
        // High accuracy, frequent updates (Google Maps level)
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // meters (from BackendConfig.movingModeDistanceFilterMeters)
          timeLimit: Duration(seconds: 3), // seconds (from BackendConfig.movingModeUpdateIntervalSeconds)
        );
      
      case LocationTrackingMode.stationary:
        // Reduced frequency for battery saving
        return const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 20, // meters (from BackendConfig.stationaryModeDistanceFilterMeters)
          timeLimit: Duration(seconds: 20), // seconds (from BackendConfig.stationaryModeUpdateIntervalSeconds)
        );
    }
  }

  /// Handle position stream errors
  void _onPositionError(dynamic error) {
    print('❌ [LocationService] Position stream error: $error');
    _updateStatus(LocationServiceStatus.error);
  }

  /// Update service status
  void _updateStatus(LocationServiceStatus status) {
    _statusStreamController.add(status);
  }

  /// Get current position once (no streaming)
  Future<LocationUpdate?> getCurrentPosition() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LocationUpdate(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        heading: position.heading,
        timestamp: position.timestamp ?? DateTime.now(),
      );
    } catch (e) {
      print('❌ [LocationService] Error getting current position: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _positionSubscription?.cancel();
    _locationStreamController.close();
    _statusStreamController.close();
  }
}

/// Location tracking modes
enum LocationTrackingMode {
  moving,      // High frequency, high accuracy (active navigation)
  stationary,  // Low frequency, battery saver
}

/// Location service status
enum LocationServiceStatus {
  stopped,
  active,
  permissionDenied,
  serviceDisabled,
  modeChanged,
  error,
}
