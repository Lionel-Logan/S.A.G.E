import 'package:geolocator/geolocator.dart';

/// Location data model for tracking user position
/// Used to send location updates to the backend server for navigation
class LocationData {
  final double latitude;
  final double longitude;
  final double? accuracy; // in meters
  final double? altitude; // in meters
  final double? speed; // in m/s
  final double? heading; // in degrees (0-360)
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    required this.timestamp,
  });

  /// Create LocationData from Geolocator Position
  factory LocationData.fromPosition(Position position) {
    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
      timestamp: position.timestamp ?? DateTime.now(),
    );
  }

  /// Convert to JSON for API transmission
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  /// Create from JSON
  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: json['latitude'],
      longitude: json['longitude'],
      accuracy: json['accuracy'],
      altitude: json['altitude'],
      speed: json['speed'],
      heading: json['heading'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  /// Get compact JSON for WebSocket transmission (smaller payload)
  Map<String, dynamic> toCompactJson() {
    return {
      'lat': latitude,
      'lng': longitude,
      'acc': accuracy,
      'alt': altitude,
      'spd': speed,
      'hdg': heading,
      'ts': timestamp.millisecondsSinceEpoch ~/ 1000, // Unix timestamp
    };
  }

  /// Calculate distance to another location (in meters)
  double distanceTo(LocationData other) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  /// Check if this location is significantly different from another
  /// (useful for filtering redundant updates)
  bool isSignificantlyDifferentFrom(
    LocationData? other, {
    double distanceThreshold = 2.0, // meters
    double speedThreshold = 0.5, // m/s
  }) {
    if (other == null) return true;

    final distance = distanceTo(other);
    final currentSpeed = speed ?? 0.0;

    // If stationary (low speed and small distance), not significant
    if (currentSpeed < speedThreshold && distance < distanceThreshold) {
      return false;
    }

    // Otherwise, it's a significant change
    return true;
  }

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lng: $longitude, '
        'accuracy: ${accuracy?.toStringAsFixed(1)}m, '
        'speed: ${speed?.toStringAsFixed(1)}m/s)';
  }

  /// Create a copy with updated values
  LocationData copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    DateTime? timestamp,
  }) {
    return LocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Navigation update received from backend
class NavigationUpdate {
  final String? instruction;
  final double? distanceToNextTurn;
  final int? etaSeconds;
  final double? currentSpeed;
  final DateTime timestamp;

  NavigationUpdate({
    this.instruction,
    this.distanceToNextTurn,
    this.etaSeconds,
    this.currentSpeed,
    required this.timestamp,
  });

  factory NavigationUpdate.fromJson(Map<String, dynamic> json) {
    return NavigationUpdate(
      instruction: json['instruction'],
      distanceToNextTurn: json['distance_to_next_turn']?.toDouble(),
      etaSeconds: json['eta_seconds'],
      currentSpeed: json['current_speed']?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'NavigationUpdate(instruction: $instruction, '
        'distance: ${distanceToNextTurn?.toStringAsFixed(0)}m)';
  }
}
