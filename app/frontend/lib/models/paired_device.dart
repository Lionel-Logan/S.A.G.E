/// Model for paired device information
class PairedDevice {
  final String name;
  final String id;
  final DateTime pairedAt;

  PairedDevice({
    required this.name,
    required this.id,
    required this.pairedAt,
  });

  /// Create from JSON
  factory PairedDevice.fromJson(Map<String, dynamic> json) {
    return PairedDevice(
      name: json['name'] as String,
      id: json['id'] as String,
      pairedAt: DateTime.parse(json['paired_at'] as String),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'paired_at': pairedAt.toIso8601String(),
    };
  }

  /// Get time since pairing
  String getTimeSincePairing() {
    final duration = DateTime.now().difference(pairedAt);
    
    if (duration.inDays > 365) {
      final years = (duration.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (duration.inDays > 30) {
      final months = (duration.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (duration.inDays > 0) {
      return '${duration.inDays} ${duration.inDays == 1 ? 'day' : 'days'} ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} ${duration.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} ${duration.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
}
