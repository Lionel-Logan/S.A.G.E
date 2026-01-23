import 'package:flutter/material.dart';
import '../theme/app-theme.dart';
import '../services/bluetooth_service.dart';
import '../services/storage_service.dart';
import '../models/paired_device.dart';
import '../models/bluetooth_device.dart';
import 'dart:async';

class BluetoothSettingsScreen extends StatefulWidget {
  const BluetoothSettingsScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothSettingsScreen> createState() => _BluetoothSettingsScreenState();
}

class _BluetoothSettingsScreenState extends State<BluetoothSettingsScreen> {
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
    _startStatusPolling();
  }

  void _startStatusPolling() {
    // Poll Bluetooth status every 3 seconds
    _statusPollTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      _pollBluetoothStatus();
    });
    // Initial poll
    _pollBluetoothStatus();
  }

  Future<void> _pollBluetoothStatus() async {
    if (_pairedDevice == null) return;
    
    try {
      await BluetoothService.connectToDevice(_pairedDevice!.id);
      
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
    
    // Auto-scan on load
    if (_pairedDevice != null) {
      _scanDevices();
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
          _statusMessage = 'No audio devices found. Make sure your headphones are in pairing mode.';
          _isSuccess = false;
        }
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Failed to scan devices: $e';
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
          _statusMessage = 'Failed to initiate pairing. Please try again.';
          _isSuccess = false;
          _isPairing = false;
        });
        return;
      }

      // Wait for pairing to complete (poll status)
      await _waitForPairingCompletion(device);
      
    } catch (e) {
      setState(() {
        _statusMessage = 'Error pairing device: $e';
        _isSuccess = false;
        _isPairing = false;
      });
    }
  }

  Future<void> _waitForPairingCompletion(BluetoothAudioDevice device) async {
    // Show progress dialog
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.cyan),
              SizedBox(height: 24),
              Text(
                'Pairing with ${device.name}',
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Make sure your headphones are in pairing mode...',
                style: TextStyle(
                  color: AppTheme.gray500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    // Poll for status (30 second timeout)
    final deadline = DateTime.now().add(Duration(seconds: 30));
    bool success = false;

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(Duration(seconds: 2));
      
      try {
        final status = await BluetoothService.getBluetoothDeviceStatus(_pairedDevice!.id);
        
        if (status != null) {
          final statusStr = status['status'] as String?;
          final connectedDevice = status['device'] as String?;
          
          if (statusStr == 'connected' && connectedDevice == device.mac) {
            success = true;
            break;
          } else if (statusStr == 'failed') {
            break;
          }
        }
      } catch (e) {
        print('Error polling status: $e');
      }
    }

    // Close dialog
    if (mounted) {
      Navigator.of(context).pop();
      
      setState(() {
        _isPairing = false;
        if (success) {
          _statusMessage = 'Successfully paired and connected to ${device.name}!\nAudio output configured.';
          _isSuccess = true;
          _selectedDevice = null;
          _pollBluetoothStatus(); // Update connected device
        } else {
          _statusMessage = 'Pairing failed or timed out.\n\nPlease ensure:\n• Device is in pairing mode (hold power button)\n• Device is close to S.A.G.E\n• No other devices are trying to connect';
          _isSuccess = false;
        }
      });
    }
  }

  Future<void> _disconnectDevice() async {
    if (_pairedDevice == null || _connectedDevice == null) return;
    
    final mac = _connectedDevice!['device'] as String?;
    if (mac == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final success = await BluetoothService.disconnectBluetoothDevice(
        deviceId: _pairedDevice!.id,
        macAddress: mac,
      );

      setState(() {
        _isLoading = false;
        if (success) {
          _statusMessage = 'Disconnected successfully';
          _isSuccess = true;
          _connectedDevice = null;
        } else {
          _statusMessage = 'Failed to disconnect';
          _isSuccess = false;
        }
      });
      
      // Refresh status
      await Future.delayed(Duration(seconds: 1));
      _pollBluetoothStatus();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error disconnecting: $e';
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
    super.dispose();
  }
}
