enum BluetoothPairingStatus {
  scanning,
  pairing,
  trusting,
  connecting,
  configuringAudio,
  connected,
  failed
}

class BluetoothPairingState {
  final BluetoothPairingStatus status;
  final int progress;
  final String message;
  final String timestamp;

  BluetoothPairingState({
    required this.status,
    required this.progress,
    required this.message,
    required this.timestamp,
  });

  factory BluetoothPairingState.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String;
    BluetoothPairingStatus status;
    
    switch (statusStr) {
      case 'scanning':
        status = BluetoothPairingStatus.scanning;
        break;
      case 'pairing':
        status = BluetoothPairingStatus.pairing;
        break;
      case 'trusting':
        status = BluetoothPairingStatus.trusting;
        break;
      case 'connecting':
        status = BluetoothPairingStatus.connecting;
        break;
      case 'configuring_audio':
        status = BluetoothPairingStatus.configuringAudio;
        break;
      case 'connected':
        status = BluetoothPairingStatus.connected;
        break;
      case 'failed':
        status = BluetoothPairingStatus.failed;
        break;
      default:
        status = BluetoothPairingStatus.pairing;
    }

    return BluetoothPairingState(
      status: status,
      progress: json['progress'] ?? 0,
      message: json['message'] ?? '',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }

  bool get isComplete => status == BluetoothPairingStatus.connected || status == BluetoothPairingStatus.failed;
  bool get isSuccess => status == BluetoothPairingStatus.connected;
  bool get isFailed => status == BluetoothPairingStatus.failed;

  String get statusLabel {
    switch (status) {
      case BluetoothPairingStatus.scanning:
        return 'Scanning';
      case BluetoothPairingStatus.pairing:
        return 'Pairing';
      case BluetoothPairingStatus.trusting:
        return 'Trusting Device';
      case BluetoothPairingStatus.connecting:
        return 'Connecting';
      case BluetoothPairingStatus.configuringAudio:
        return 'Configuring Audio';
      case BluetoothPairingStatus.connected:
        return 'Connected';
      case BluetoothPairingStatus.failed:
        return 'Failed';
    }
  }
}
