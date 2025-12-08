enum ConnectionStatus { connected, disconnected, searching }

class GlassStatus {
  final ConnectionStatus status;
  final String deviceName;
  final int batteryLevel;
  final DateTime? lastConnected;

  GlassStatus({
    required this.status,
    this.deviceName = 'SAGE Glass',
    this.batteryLevel = 100,
    this.lastConnected,
  });

  bool get isConnected => status == ConnectionStatus.connected;
  
  String get statusText {
    switch (status) {
      case ConnectionStatus.connected:
        return 'CONNECTED';
      case ConnectionStatus.disconnected:
        return 'DISCONNECTED';
      case ConnectionStatus.searching:
        return 'SEARCHING...';
    }
  }

  String get statusDescription {
    switch (status) {
      case ConnectionStatus.connected:
        return 'Glass is paired and ready';
      case ConnectionStatus.disconnected:
        return 'No device found';
      case ConnectionStatus.searching:
        return 'Looking for your glass...';
    }
  }
}