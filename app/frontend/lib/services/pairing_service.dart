import 'dart:async';
import 'storage_service.dart';
import 'bluetooth_service.dart';
import 'wifi_hotspot_service.dart';
import '../models/paired_device.dart';
import '../models/pairing_step.dart';

/// Orchestrates the entire pairing flow
class PairingService {
  final bool isAutoMode;
  final StreamController<PairingStep> _stepController = StreamController<PairingStep>.broadcast();
  
  PairingStep _currentStep = PairingStep.initial();
  
  // Manual mode data
  String? _selectedDeviceId;
  String? _manualSSID;
  String? _manualPassword;

  PairingService({required this.isAutoMode});

  Stream<PairingStep> get stepStream => _stepController.stream;
  PairingStep get currentStep => _currentStep;

  /// Start the pairing process
  Future<void> startPairing() async {
    if (isAutoMode) {
      await _autoModePairing();
    } else {
      await _manualModePairing();
    }
  }

  /// Auto-detect pairing flow
  Future<void> _autoModePairing() async {
    try {
      // Step 1: Check Bluetooth permissions
      _updateStep(PairingStepType.bluetoothPermission, StepStatus.inProgress);
      final btPermission = await BluetoothService.requestPermissions();
      
      if (!btPermission) {
        _updateStep(PairingStepType.bluetoothPermission, StepStatus.failed,
            error: 'Bluetooth permissions denied');
        return;
      }
      
      _updateStep(PairingStepType.bluetoothPermission, StepStatus.completed);

      // Step 2: Check Bluetooth availability
      _updateStep(PairingStepType.bluetoothCheck, StepStatus.inProgress);
      final btAvailable = await BluetoothService.isBluetoothAvailable();
      
      if (!btAvailable) {
        _updateStep(PairingStepType.bluetoothCheck, StepStatus.failed,
            error: 'Bluetooth is not enabled');
        return;
      }
      
      _updateStep(PairingStepType.bluetoothCheck, StepStatus.completed);

      // Step 3: Scan for SAGE Glass
      _updateStep(PairingStepType.scanning, StepStatus.inProgress);
      
      BluetoothDeviceInfo? foundDevice;
      await for (final devices in BluetoothService.scanForDevices()) {
        if (devices.isNotEmpty) {
          foundDevice = devices.first;
          _selectedDeviceId = foundDevice.id;
          break;
        }
      }
      
      if (foundDevice == null) {
        _updateStep(PairingStepType.scanning, StepStatus.failed,
            error: 'No SAGE Glass found. Please try manual mode.');
        return;
      }
      
      _updateStep(PairingStepType.scanning, StepStatus.completed,
          data: {'device_name': foundDevice.name});

      // Step 4: Connect to device
      _updateStep(PairingStepType.bluetoothConnect, StepStatus.inProgress);
      final connected = await BluetoothService.connectToDevice(_selectedDeviceId!);
      
      if (!connected) {
        _updateStep(PairingStepType.bluetoothConnect, StepStatus.failed,
            error: 'Failed to connect to device');
        return;
      }
      
      _updateStep(PairingStepType.bluetoothConnect, StepStatus.completed);

      // Step 5: Auto-detect hotspot credentials
      _updateStep(PairingStepType.hotspotDetection, StepStatus.inProgress);
      final credentials = await WiFiHotspotService.autoDetectHotspot();
      
      if (credentials == null || !credentials.isComplete) {
        _updateStep(PairingStepType.hotspotDetection, StepStatus.failed,
            error: 'Could not detect hotspot credentials. Please enter manually.');
        return;
      }
      
      _manualSSID = credentials.ssid;
      _manualPassword = credentials.password;
      
      _updateStep(PairingStepType.hotspotDetection, StepStatus.completed,
          data: {'ssid': credentials.ssid});

      // Step 6: Send credentials to Glass
      _updateStep(PairingStepType.credentialTransfer, StepStatus.inProgress);
      final sent = await BluetoothService.sendCredentials(
        deviceId: _selectedDeviceId!,
        ssid: credentials.ssid,
        password: credentials.password,
      );
      
      if (!sent) {
        _updateStep(PairingStepType.credentialTransfer, StepStatus.failed,
            error: 'Failed to send credentials to Glass');
        return;
      }
      
      _updateStep(PairingStepType.credentialTransfer, StepStatus.completed);

      // Step 7: Enable hotspot
      _updateStep(PairingStepType.hotspotEnable, StepStatus.inProgress);
      final enabled = await WiFiHotspotService.enableHotspot(
        ssid: credentials.ssid,
        password: credentials.password,
      );
      
      if (!enabled) {
        _updateStep(PairingStepType.hotspotEnable, StepStatus.failed,
            error: 'Please enable WiFi hotspot manually');
        // Don't return - guide user to enable manually
      }
      
      _updateStep(PairingStepType.hotspotEnable, StepStatus.completed);

      // Step 8: Wait for Glass to connect
      _updateStep(PairingStepType.glassConnection, StepStatus.inProgress);
      
      bool glassConnected = false;
      await for (final connected in WiFiHotspotService.waitForGlassConnection()) {
        if (connected) {
          glassConnected = true;
          break;
        }
      }
      
      if (!glassConnected) {
        _updateStep(PairingStepType.glassConnection, StepStatus.failed,
            error: 'Glass did not connect to hotspot');
        return;
      }
      
      _updateStep(PairingStepType.glassConnection, StepStatus.completed);

      // Step 9: Verify and save pairing
      await _completePairing(foundDevice.name, foundDevice.id);
      
    } catch (e) {
      _updateStep(_currentStep.type, StepStatus.failed, error: e.toString());
    }
  }

  /// Manual pairing flow
  Future<void> _manualModePairing() async {
    try {
      // Step 1: Bluetooth permissions
      _updateStep(PairingStepType.bluetoothPermission, StepStatus.inProgress);
      final btPermission = await BluetoothService.requestPermissions();
      
      if (!btPermission) {
        _updateStep(PairingStepType.bluetoothPermission, StepStatus.failed,
            error: 'Bluetooth permissions denied');
        return;
      }
      
      _updateStep(PairingStepType.bluetoothPermission, StepStatus.completed);

      // Step 2: User scans and selects device
      _updateStep(PairingStepType.manualScan, StepStatus.waitingForUser);
      // User interaction required - wait for setSelectedDevice()
      
    } catch (e) {
      _updateStep(_currentStep.type, StepStatus.failed, error: e.toString());
    }
  }

  /// Set selected device (manual mode)
  Future<void> setSelectedDevice(String deviceId, String deviceName) async {
    _selectedDeviceId = deviceId;
    _updateStep(PairingStepType.manualScan, StepStatus.completed,
        data: {'device_name': deviceName});
    
    // Continue with connection
    _updateStep(PairingStepType.bluetoothConnect, StepStatus.inProgress);
    final connected = await BluetoothService.connectToDevice(deviceId);
    
    if (!connected) {
      _updateStep(PairingStepType.bluetoothConnect, StepStatus.failed,
          error: 'Failed to connect to device');
      return;
    }
    
    _updateStep(PairingStepType.bluetoothConnect, StepStatus.completed);
    
    // Next: Wait for user to enter credentials
    _updateStep(PairingStepType.manualCredentials, StepStatus.waitingForUser);
  }

  /// Set hotspot credentials (manual mode)
  Future<void> setHotspotCredentials(String ssid, String password) async {
    _manualSSID = ssid;
    _manualPassword = password;
    
    _updateStep(PairingStepType.manualCredentials, StepStatus.completed,
        data: {'ssid': ssid});
    
    // Send credentials
    _updateStep(PairingStepType.credentialTransfer, StepStatus.inProgress);
    final sent = await BluetoothService.sendCredentials(
      deviceId: _selectedDeviceId!,
      ssid: ssid,
      password: password,
    );
    
    if (!sent) {
      _updateStep(PairingStepType.credentialTransfer, StepStatus.failed,
          error: 'Failed to send credentials');
      return;
    }
    
    _updateStep(PairingStepType.credentialTransfer, StepStatus.completed);
    
    // Guide user to enable hotspot
    _updateStep(PairingStepType.hotspotEnable, StepStatus.waitingForUser);
  }

  /// User confirms hotspot is enabled
  Future<void> confirmHotspotEnabled() async {
    _updateStep(PairingStepType.hotspotEnable, StepStatus.completed);
    
    // Wait for Glass connection
    _updateStep(PairingStepType.glassConnection, StepStatus.inProgress);
    
    bool glassConnected = false;
    await for (final connected in WiFiHotspotService.waitForGlassConnection()) {
      if (connected) {
        glassConnected = true;
        break;
      }
    }
    
    if (!glassConnected) {
      _updateStep(PairingStepType.glassConnection, StepStatus.failed,
          error: 'Glass did not connect to hotspot');
      return;
    }
    
    _updateStep(PairingStepType.glassConnection, StepStatus.completed);
    
    // Complete pairing
    await _completePairing('SAGE Glass', _selectedDeviceId!);
  }

  /// Complete and save pairing
  Future<void> _completePairing(String deviceName, String deviceId) async {
    _updateStep(PairingStepType.verification, StepStatus.inProgress);
    
    final device = PairedDevice(
      name: deviceName,
      id: deviceId,
      pairedAt: DateTime.now(),
    );
    
    await StorageService.savePairingData(
      device: device,
      hotspotSSID: _manualSSID!,
      hotspotPassword: _manualPassword!,
    );
    
    _updateStep(PairingStepType.verification, StepStatus.completed);
    _updateStep(PairingStepType.complete, StepStatus.completed);
  }

  /// Update current step
  void _updateStep(
    PairingStepType type,
    StepStatus status, {
    String? error,
    Map<String, dynamic>? data,
  }) {
    _currentStep = PairingStep(
      type: type,
      status: status,
      error: error,
      data: data,
    );
    _stepController.add(_currentStep);
  }

  /// Dispose resources
  void dispose() {
    _stepController.close();
  }
}
