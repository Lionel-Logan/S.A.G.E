import 'package:flutter/material.dart';
import '../theme/app-theme.dart';
import '../services/bluetooth_service.dart';
import '../services/storage_service.dart';
import '../models/paired_device.dart';
import '../models/bluetooth_device.dart';
import 'dart:async';
import '../models/pairing_step.dart';
import '../widgets/pairing_step_widget.dart';
import '../config/ble_config.dart';

class BluetoothSettingsScreen extends StatefulWidget {
  const BluetoothSettingsScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothSettingsScreen> createState() => _BluetoothSettingsScreenState();
}

class _BluetoothSettingsScreenState extends State<BluetoothSettingsScreen> {
    StreamSubscription<Map<String, dynamic>?>? _btStatusStreamSub;
  bool _isLoading = false;
  bool _isScanning = false;
  bool _isPairing = false;
  String? _statusMessage;
  bool _isSuccess = false;
  PairedDevice? _pairedDevice;
  List<BluetoothAudioDevice> _availableDevices = [];
  BluetoothAudioDevice? _selectedDevice;
  Map<String, dynamic>? _connectedDevice;
  Timer? _statusPollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToBluetoothStatus();
  }

  Future<void> _subscribeToBluetoothStatus() async {
    // Wait for paired device to load
    await Future.delayed(Duration(milliseconds: 300));
    if (_pairedDevice == null) return;
    await BluetoothService.subscribeBluetoothStatusNotifications(_pairedDevice!.id);
    _btStatusStreamSub?.cancel();
    _btStatusStreamSub = BluetoothService.bluetoothStatusStream.listen((statusData) {
      if (statusData != null && mounted) {
        setState(() {
          _connectedDevice = statusData;
        });
      }
    });
  }

  // Polling is now only used as a fallback if notifications are not available
  void _startStatusPolling() {
    _statusPollTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      _pollBluetoothStatus();
    });
    _pollBluetoothStatus();
  }

  Future<void> _pollBluetoothStatus() async {
    if (_pairedDevice == null) return;
    
    // CRITICAL: Stop polling when operations are in progress to prevent race conditions
    if (_isPairing || _isLoading || _isScanning) {
      print('Bluetooth status polling skipped - operation in progress');
      return;
    }
    
    try {
      final statusData = await BluetoothService.getBluetoothDeviceStatus(_pairedDevice!.id);
      
      if (statusData != null && mounted) {
        setState(() {
          _connectedDevice = statusData;
        });
      }
    } catch (e) {
      print('Bluetooth status polling error: $e');
    }
  }

  Future<void> _loadData() async {
    final device = await StorageService.getPairedDevice();
    setState(() {
      _pairedDevice = device;
    });
    if (_pairedDevice != null) {
      _scanDevices();
      // Subscribe to notifications after device is loaded
      await BluetoothService.subscribeBluetoothStatusNotifications(_pairedDevice!.id);
      _btStatusStreamSub?.cancel();
      _btStatusStreamSub = BluetoothService.bluetoothStatusStream.listen((statusData) {
        if (statusData != null && mounted) {
          setState(() {
            _connectedDevice = statusData;
          });
        }
      });
    }
  }

  Future<void> _scanDevices() async {
    if (_pairedDevice == null) return;
    
    setState(() {
      _isScanning = true;
      _statusMessage = null;
      _availableDevices = [];
    });

    try {
      final devices = await BluetoothService.scanBluetoothAudioDevices(_pairedDevice!.id);
      setState(() {
        _availableDevices = devices;
        _isScanning = false;
        if (devices.isEmpty) {
          _statusMessage = '⚠ No audio devices found.\n\nMake sure your headphones are:\n• In pairing mode (LED flashing)\n• Powered on and nearby\n• Not connected to another device';
          _isSuccess = false;
        }
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = '✗ Failed to scan for devices:\n\n$e\n\nPlease check that S.A.G.E Glass is connected and try again.';
        _isSuccess = false;
      });
    }
  }

  Future<void> _pairDevice(BluetoothAudioDevice device) async {
    if (_pairedDevice == null || _isPairing) return;
    
    setState(() {
      _isPairing = true;
      _statusMessage = null;
    });

    try {
      // Send pair command
      final success = await BluetoothService.pairBluetoothDevice(
        deviceId: _pairedDevice!.id,
        macAddress: device.mac,
      );

      if (!success) {
        setState(() {
          _statusMessage = '✗ Failed to initiate pairing with ${device.name}.\n\nPlease check:\n• S.A.G.E Glass is connected via BLE\n• Bluetooth service is running on the Pi\n• Try scanning again';
          _isSuccess = false;
          _isPairing = false;
        });
        return;
      }

      // Wait for pairing to complete (poll status)
      await _waitForPairingCompletion(device);
      
    } catch (e) {
      setState(() {
        _statusMessage = '✗ Pairing error with ${device.name}:\n\n$e\n\nPlease check the connection and try again.';
        _isSuccess = false;
        _isPairing = false;
      });
    }
  }

  Future<void> _waitForPairingCompletion(BluetoothAudioDevice device) async {
    // Show progress dialog with realtime step updates
    PairingStep currentStep = PairingStep(
      type: PairingStepType.audioPairing,
      status: StepStatus.inProgress,
    );

    void Function(void Function())? setDialogState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: AppTheme.gray900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              setDialogState = setStateDialog;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PairingStepWidget(step: currentStep),
                  SizedBox(height: 16),
                  Text(
                    currentStep.description,
                    style: TextStyle(
                      color: AppTheme.gray500,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // Poll for status with configurable timeout/interval
    final deadline = DateTime.now().add(BLEConfig.audioPairingTimeout);
    bool success = false;

    // small delay to ensure dialog state's setter is captured
    await Future.delayed(Duration(milliseconds: 150));

    int idleCount = 0;
    const int maxIdle = 3; // tolerate up to 3 idle/nulls before failing
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(BLEConfig.audioPairingPollInterval);

      try {
        final status = await BluetoothService.getBluetoothDeviceStatus(_pairedDevice!.id);

        if (status != null) {
          print('[DEBUG] Pairing poll status: ${status.toString()}');
          final statusStr = (status['status'] ?? '') as String;
          final connectedDevice = status['device'] as String?;

          PairingStepType newType = PairingStepType.audioPairing;
          if (statusStr.contains('pair')) {
            newType = PairingStepType.audioPairing;
          } else if (statusStr.contains('trust')) {
            newType = PairingStepType.audioTrusting;
          } else if (statusStr.contains('connect')) {
            newType = PairingStepType.audioConnecting;
          } else if (statusStr.contains('route') || statusStr.contains('routing')) {
            newType = PairingStepType.audioRouting;
          } else if (statusStr.contains('connected')) {
            newType = PairingStepType.audioComplete;
          } else if (statusStr.contains('failed') || statusStr.contains('error')) {
            newType = PairingStepType.audioPairing;
          }

          currentStep = PairingStep(type: newType, status: StepStatus.inProgress);
          setDialogState?.call(() {});

          final deviceMatch = (connectedDevice ?? '').toString().toLowerCase() == device.mac.toLowerCase();
          final explicitConnected = (status['connected'] == true);

          if ((statusStr == 'connected' || statusStr.contains('connected') || explicitConnected) && deviceMatch) {
            currentStep = PairingStep(type: PairingStepType.audioComplete, status: StepStatus.completed);
            setDialogState?.call(() {});
            success = true;
            break;
          } else if (statusStr == 'failed') {
            break;
          } else if (statusStr == 'idle' || statusStr == '' || status == null) {
            idleCount++;
            if (idleCount >= maxIdle) {
              print('[DEBUG] Too many idle/null status responses, breaking as failed.');
              break;
            }
          } else {
            idleCount = 0; // reset on any non-idle
          }
        } else {
          idleCount++;
          if (idleCount >= maxIdle) {
            print('[DEBUG] Too many null status responses, breaking as failed.');
            break;
          }
        }
      } catch (e) {
        print('Error polling status: $e');
        idleCount++;
        if (idleCount >= maxIdle) {
          print('[DEBUG] Too many errors/nulls, breaking as failed.');
          break;
        }
      }

    }

    // Close dialog
    if (mounted) {
      Navigator.of(context).pop();

      setState(() {
        _isPairing = false;
        if (success) {
          _statusMessage = '✓ Successfully paired and connected to ${device.name}!\n\nAudio output is now configured.';
          _isSuccess = true;
          _selectedDevice = null;
          _connectedDevice = {'device': device.mac, 'name': device.name, 'connected': true, 'status': 'connected'};

          // Stop status polling for a stabilization window
          _statusPollTimer?.cancel();
          Future.delayed(Duration(seconds: BLEConfig.audioPostPairStabilizeSeconds), () {
            if (mounted) {
              _startStatusPolling(); // Restart polling after connection stabilizes
            }
          });
        } else {
          _statusMessage = '✗ Pairing with ${device.name} failed or timed out.\n\nPlease ensure:\n• Device is in pairing mode (LED flashing)\n• Hold power button for 5-10 seconds\n• Device is close to S.A.G.E Glass\n• Device is not connected to another device\n• Try again in a few seconds';
          _isSuccess = false;
        }
      });
    }
  }

  Future<void> _disconnectDevice() async {
    if (_pairedDevice == null || _connectedDevice == null) return;
    
    final mac = _connectedDevice!['device'] as String?;
    final deviceName = _connectedDevice!['name'] as String? ?? 'Device';
    if (mac == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Disconnecting and forgetting $deviceName...';
      _isSuccess = false;
    });

    try {
      final success = await BluetoothService.disconnectBluetoothDevice(
        deviceId: _pairedDevice!.id,
        macAddress: mac,
      );

      if (success) {
        // Clear ALL device state immediately
        setState(() {
          _isLoading = false;
          _statusMessage = '✓ $deviceName has been disconnected and forgotten.\n\nScanning for updated device list...';
          _isSuccess = true;
          _connectedDevice = null;
          _availableDevices = []; // Clear stale scan results
          _isScanning = true; // Show scanning state
        });
        
        // Wait for Pi to complete unpairing, then rescan to get fresh device states
        await Future.delayed(Duration(seconds: 3));
        
        if (mounted) {
          // Rescan to show device as unpaired
          await _scanDevices();
          
          // Update success message after scan
          if (mounted) {
            setState(() {
              _statusMessage = '✓ $deviceName has been disconnected and forgotten.\n\nYou can pair it again by scanning for devices.';
            });
          }
        }
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = '✗ Failed to disconnect $deviceName.\n\nPlease try again or check if the device is still in range.';
          _isSuccess = false;
        });
      }
      
      // Wait before refreshing status to allow cooldown period
      await Future.delayed(Duration(seconds: 2));
      if (mounted && !_isLoading && !_isPairing) {
        _pollBluetoothStatus();
      }
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '✗ Error disconnecting $deviceName:\n\n$e';
        _isSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectedDevice?['connected'] == true;
    final connectedDeviceName = _connectedDevice?['name'] as String?;

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.gray900,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Bluetooth Settings',
          style: TextStyle(color: AppTheme.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Audio Device Management',
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect Bluetooth headphones or speakers to S.A.G.E',
                style: TextStyle(
                  color: AppTheme.gray500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),

              // Pairing instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.purple.withOpacity(0.3), width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.purple,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PAIRING MODE',
                            style: TextStyle(
                              color: AppTheme.purple,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Put your headphones in pairing mode (usually hold power button for 5-10 seconds until LED flashes) before scanning.',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Connected device card
              if (isConnected && connectedDeviceName != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.green.withOpacity(0.2), AppTheme.green.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.green, width: 2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.headphones, color: AppTheme.green, size: 32),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CONNECTED',
                                  style: TextStyle(
                                    color: AppTheme.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  connectedDeviceName,
                                  style: TextStyle(
                                    color: AppTheme.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Audio Output Active',
                                  style: TextStyle(
                                    color: AppTheme.gray500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _disconnectDevice,
                          icon: Icon(Icons.link_off, color: Colors.red),
                          label: Text(
                            'DISCONNECT',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.red, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Scan button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_isScanning || _isPairing) ? null : _scanDevices,
                  icon: _isScanning
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyan),
                          ),
                        )
                      : Icon(Icons.bluetooth_searching, color: AppTheme.cyan),
                  label: Text(
                    _isScanning ? 'SCANNING...' : 'SCAN FOR AUDIO DEVICES',
                    style: TextStyle(
                      color: AppTheme.cyan,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppTheme.cyan, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              // Available devices list
              if (_availableDevices.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Available Audio Devices',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.gray800,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.gray700),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _availableDevices.length,
                    separatorBuilder: (context, index) => Divider(
                      color: AppTheme.gray700,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final device = _availableDevices[index];
                      final isDeviceConnected = _connectedDevice?['device'] == device.mac;

                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.cyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            device.deviceIcon,
                            color: AppTheme.cyan,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          device.name,
                          style: TextStyle(
                            color: AppTheme.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              device.deviceTypeName,
                              style: TextStyle(
                                color: AppTheme.gray500,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.signal_cellular_alt,
                                  size: 14,
                                  color: device.getSignalColor(),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${device.signalStrength}% • ${device.signalQuality}',
                                  style: TextStyle(
                                    color: device.getSignalColor(),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: isDeviceConnected
                            ? Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'CONNECTED',
                                  style: TextStyle(
                                    color: AppTheme.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _isPairing ? null : () => _pairDevice(device),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.cyan,
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  device.paired ? 'CONNECT' : 'PAIR',
                                  style: TextStyle(
                                    color: AppTheme.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ],

              // Status message
              if (_statusMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isSuccess 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSuccess 
                          ? Colors.green.withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle : Icons.warning,
                        color: _isSuccess ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _statusMessage!,
                              style: TextStyle(
                                color: AppTheme.white,
                                fontSize: 14,
                              ),
                            ),
                            if (!_isSuccess && !_isPairing) ...[
                              SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _scanDevices,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.cyan,
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  child: Text(
                                    'RETRY SCAN',
                                    style: TextStyle(
                                      color: AppTheme.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _btStatusStreamSub?.cancel();
    super.dispose();
  }
}
