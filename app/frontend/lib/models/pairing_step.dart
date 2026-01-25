/// Pairing step types
enum PairingStepType {
  initial,
  bluetoothPermission,
  bluetoothCheck,
  scanning,
  bluetoothConnect,
  hotspotDetection,
  credentialTransfer,
  hotspotEnable,
  glassConnection,
  verification,
  complete,
  // Manual mode specific
  manualScan,
  manualCredentials,
}

/// Step status
enum StepStatus {
  pending,
  inProgress,
  completed,
  failed,
  waitingForUser,
}

/// Pairing step model
class PairingStep {
  final PairingStepType type;
  final StepStatus status;
  final String? error;
  final Map<String, dynamic>? data;

  PairingStep({
    required this.type,
    required this.status,
    this.error,
    this.data,
  });

  factory PairingStep.initial() {
    return PairingStep(
      type: PairingStepType.initial,
      status: StepStatus.pending,
    );
  }

  /// Get human-readable step title
  String get title {
    switch (type) {
      case PairingStepType.initial:
        return 'Ready to pair';
      case PairingStepType.bluetoothPermission:
        return 'Requesting permissions';
      case PairingStepType.bluetoothCheck:
        return 'Checking Bluetooth';
      case PairingStepType.scanning:
        return 'Scanning for S.A.G.E';
      case PairingStepType.bluetoothConnect:
        return 'Connecting to Glass';
      case PairingStepType.hotspotDetection:
        return 'Detecting hotspot';
      case PairingStepType.credentialTransfer:
        return 'Transferring credentials';
      case PairingStepType.hotspotEnable:
        return 'Enabling WiFi hotspot';
      case PairingStepType.glassConnection:
        return 'Waiting for Glass connection';
      case PairingStepType.verification:
        return 'Verifying connection';
      case PairingStepType.complete:
        return 'Pairing complete!';
      case PairingStepType.manualScan:
        return 'Select your SAGE Glass';
      case PairingStepType.manualCredentials:
        return 'Enter hotspot credentials';
    }
  }

  /// Get step description
  String get description {
    switch (type) {
      case PairingStepType.initial:
        return 'Preparing to connect to your SAGE Glass';
      case PairingStepType.bluetoothPermission:
        return 'Requesting Bluetooth permissions...';
      case PairingStepType.bluetoothCheck:
        return 'Verifying Bluetooth is enabled...';
      case PairingStepType.scanning:
        return 'Looking for nearby SAGE Glass devices...';
      case PairingStepType.bluetoothConnect:
        return 'Establishing Bluetooth connection...';
      case PairingStepType.hotspotDetection:
        return 'Auto-detecting your hotspot credentials...';
      case PairingStepType.credentialTransfer:
        return 'Sending WiFi credentials to Glass...';
      case PairingStepType.hotspotEnable:
        return 'Please enable your WiFi hotspot';
      case PairingStepType.glassConnection:
        return 'Glass is connecting to your hotspot...';
      case PairingStepType.verification:
        return 'Finalizing connection...';
      case PairingStepType.complete:
        return 'Your SAGE Glass is ready to use!';
      case PairingStepType.manualScan:
        return 'Choose your device from the list below';
      case PairingStepType.manualCredentials:
        return 'Enter your WiFi hotspot details';
    }
  }

  /// Get step number for progress
  int get stepNumber {
    switch (type) {
      case PairingStepType.initial:
        return 0;
      case PairingStepType.bluetoothPermission:
        return 1;
      case PairingStepType.bluetoothCheck:
        return 2;
      case PairingStepType.scanning:
      case PairingStepType.manualScan:
        return 3;
      case PairingStepType.bluetoothConnect:
        return 4;
      case PairingStepType.hotspotDetection:
      case PairingStepType.manualCredentials:
        return 5;
      case PairingStepType.credentialTransfer:
        return 6;
      case PairingStepType.hotspotEnable:
        return 7;
      case PairingStepType.glassConnection:
        return 8;
      case PairingStepType.verification:
        return 9;
      case PairingStepType.complete:
        return 10;
    }
  }

  int get totalSteps => 10;

  bool get isComplete => type == PairingStepType.complete && status == StepStatus.completed;
  bool get isFailed => status == StepStatus.failed;
  bool get isWaitingForUser => status == StepStatus.waitingForUser;
}
