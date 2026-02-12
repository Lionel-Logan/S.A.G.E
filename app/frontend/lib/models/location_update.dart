/// Model for location update data
/// Represents a single location point with metadata

import 'dart:math' as math;

class LocationUpdate {
  final double latitude;
  final double longitude;
  final double? accuracy;      // Accuracy in meters
  final double? altitude;       // Altitude in meters
  final double? speed;          // Speed in meters/second
  final double? heading;        // Heading in degrees (0-360)
  final DateTime timestamp;

  LocationUpdate({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert to JSON for WebSocket transmission
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
  factory LocationUpdate.fromJson(Map<String, dynamic> json) {
    return LocationUpdate(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      accuracy: json['accuracy'] as double?,
      altitude: json['altitude'] as double?,
      speed: json['speed'] as double?,
      heading: json['heading'] as double?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// Create a copy with modified fields
  LocationUpdate copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    DateTime? timestamp,
  }) {
    return LocationUpdate(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'LocationUpdate(lat: $latitude, lng: $longitude, '
        'accuracy: ${accuracy?.toStringAsFixed(1)}m, '
        'speed: ${speed?.toStringAsFixed(1)}m/s, '
        'timestamp: $timestamp)';
  }

  /// Check if this location is valid for transmission
  bool isValid(double maxAccuracyMeters) {
    // Must have coordinates
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      return false;
    }
    
    // Check accuracy threshold if provided
    if (accuracy != null && accuracy! > maxAccuracyMeters) {
      return false;
    }
    
    return true;
  }

  /// Calculate distance to another location (meters)
  /// Uses Haversine formula
  double distanceTo(LocationUpdate other) {
    const double earthRadius = 6371000; // meters
    
    final lat1Rad = latitude * math.pi / 180;
    final lat2Rad = other.latitude * math.pi / 180;
    final deltaLat = (other.latitude - latitude) * math.pi / 180;
    final deltaLng = (other.longitude - longitude) * math.pi / 180;
    
    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    
    final c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }
}

/// Extension on num for trigonometric functions
extension _NumExtensions on num {
  double sin() => _sin(this.toDouble());
  double cos() => _cos(this.toDouble());
  double asin() => _asin(this.toDouble());
}

// Basic trigonometric functions using Taylor series approximations
double _sin(double x) {
  x = x % (2 * 3.141592653589793);
  if (x > 3.141592653589793) x -= 2 * 3.141592653589793;
  if (x < -3.141592653589793) x += 2 * 3.141592653589793;
  
  double result = x;
  double term = x;
  for (int i = 1; i <= 10; i++) {
    term *= -x * x / ((2 * i) * (2 * i + 1));
    result += term;
  }
  return result;
}

double _cos(double x) {
  return _sin(x + 3.141592653589793 / 2);
}

double _asin(double x) {
  if (x < -1 || x > 1) return double.nan;
  if (x == -1) return -3.141592653589793 / 2;
  if (x == 1) return 3.141592653589793 / 2;
  
  double result = x;
  double term = x;
  for (int i = 1; i <= 10; i++) {
    term *= x * x * (2 * i - 1) * (2 * i - 1) / ((2 * i) * (2 * i + 1));
    result += term;
  }
  return result;
}
