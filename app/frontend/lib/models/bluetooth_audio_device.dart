class BluetoothAudioDevice {
  final String name;
  final String mac;
  final int? rssi;
  final String? deviceClass;
  final bool isAudio;
  final String timestamp;

  BluetoothAudioDevice({
    required this.name,
    required this.mac,
    this.rssi,
    this.deviceClass,
    required this.isAudio,
    required this.timestamp,
  });

  factory BluetoothAudioDevice.fromJson(Map<String, dynamic> json) {
    return BluetoothAudioDevice(
      name: json['name'] ?? 'Unknown Device',
      mac: json['mac'] ?? '',
      rssi: json['rssi'],
      deviceClass: json['device_class'],
      isAudio: json['is_audio'] ?? false,
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mac': mac,
      'rssi': rssi,
      'device_class': deviceClass,
      'is_audio': isAudio,
      'timestamp': timestamp,
    };
  }

  /// Get signal strength as percentage (0-100)
  int get signalStrengthPercent {
    if (rssi == null) return 0;
    // RSSI typically ranges from -100 (weak) to -30 (strong)
    // Convert to 0-100 scale
    final clamped = rssi!.clamp(-100, -30);
    return ((clamped + 100) * 100 / 70).round();
  }

  /// Get signal strength category
  String get signalStrengthLabel {
    final percent = signalStrengthPercent;
    if (percent >= 75) return 'Excellent';
    if (percent >= 50) return 'Good';
    if (percent >= 25) return 'Fair';
    return 'Weak';
  }
}
