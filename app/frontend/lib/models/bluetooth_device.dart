import 'package:flutter/material.dart';

/// Model for Bluetooth audio device information
class BluetoothAudioDevice {
  final String mac;
  final String name;
  final String deviceClass;
  final String deviceType;
  final int rssi;
  final bool paired;
  final bool connected;
  final List<String> services;

  BluetoothAudioDevice({
    required this.mac,
    required this.name,
    required this.deviceClass,
    required this.deviceType,
    required this.rssi,
    required this.paired,
    required this.connected,
    required this.services,
  });

  /// Create from JSON
  factory BluetoothAudioDevice.fromJson(Map<String, dynamic> json) {
    return BluetoothAudioDevice(
      // Support both shortened and full field names for compatibility
      mac: json['m'] as String? ?? json['mac'] as String,
      name: json['n'] as String? ?? json['name'] as String,
      deviceClass: json['c'] as String? ?? json['device_class'] as String? ?? '0x000000',
      deviceType: json['t'] as String? ?? json['device_type'] as String? ?? 'unknown',
      rssi: json['r'] as int? ?? json['rssi'] as int? ?? -50,  // Default to good signal
      paired: json['p'] as bool? ?? json['paired'] as bool? ?? false,
      connected: json['x'] as bool? ?? json['connected'] as bool? ?? false,
      services: [], // Services removed to reduce size
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'mac': mac,
      'name': name,
      'device_class': deviceClass,
      'device_type': deviceType,
      'rssi': rssi,
      'paired': paired,
      'connected': connected,
      'services': services,
    };
  }

  /// Get signal strength as percentage (0-100)
  int get signalStrength {
    // RSSI typically ranges from -90 (weak) to -30 (strong)
    // Convert to 0-100 scale
    if (rssi >= -30) return 100;
    if (rssi <= -90) return 0;
    
    // Linear interpolation
    return ((rssi + 90) * 100 / 60).round();
  }

  /// Get signal quality label
  String get signalQuality {
    final strength = signalStrength;
    if (strength >= 75) return 'Excellent';
    if (strength >= 50) return 'Good';
    if (strength >= 25) return 'Fair';
    return 'Weak';
  }

  /// Get device type icon
  IconData get deviceIcon {
    // Parse device class to determine icon
    final classCode = deviceClass.toLowerCase();
    
    if (classCode == '0x240404') {
      return Icons.headphones; // Headphones
    } else if (classCode == '0x240408') {
      return Icons.headset_mic; // Hands-free device
    } else if (classCode == '0x24041c') {
      return Icons.speaker; // Loudspeaker
    } else if (classCode == '0x240418') {
      return Icons.headset; // Headset
    } else if (classCode == '0x240420') {
      return Icons.portable_wifi_off; // Portable Audio
    } else if (deviceType == 'audio') {
      return Icons.audiotrack; // Generic audio
    }
    
    return Icons.bluetooth_audio; // Default
  }

  /// Get device type display name
  String get deviceTypeName {
    final classCode = deviceClass.toLowerCase();
    
    if (classCode == '0x240404') {
      return 'Headphones';
    } else if (classCode == '0x240408') {
      return 'Hands-free Device';
    } else if (classCode == '0x24041c') {
      return 'Speaker';
    } else if (classCode == '0x240418') {
      return 'Headset';
    } else if (classCode == '0x240420') {
      return 'Portable Audio';
    } else if (deviceType == 'audio') {
      return 'Audio Device';
    }
    
    return 'Bluetooth Device';
  }

  /// Get signal strength color
  Color getSignalColor() {
    final strength = signalStrength;
    if (strength >= 75) return Colors.green;
    if (strength >= 50) return Colors.orange;
    return Colors.red;
  }

  /// Check if device is audio device
  bool get isAudioDevice {
    return deviceType == 'audio';
  }

  @override
  String toString() {
    return 'BluetoothAudioDevice{mac: $mac, name: $name, type: $deviceTypeName, signal: $signalStrength%, paired: $paired, connected: $connected}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BluetoothAudioDevice && other.mac == mac;
  }

  @override
  int get hashCode => mac.hashCode;
}
