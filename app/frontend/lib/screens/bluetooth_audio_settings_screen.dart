import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../theme/app-theme.dart';
import '../models/bluetooth_audio_device.dart';
import '../models/bluetooth_pairing_status.dart';
import '../services/bluetooth_audio_service.dart';

class BluetoothAudioSettingsScreen extends StatefulWidget {
  const BluetoothAudioSettingsScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothAudioSettingsScreen> createState() => _BluetoothAudioSettingsScreenState();
}

class _BluetoothAudioSettingsScreenState extends State<BluetoothAudioSettingsScreen>
    with TickerProviderStateMixin {
  bool _isScanning = false;
  List<BluetoothAudioDevice> _discoveredDevices = [];
  Map<String, dynamic>? _connectedDevice;
  bool _isLoading = true;
  String? _statusMessage;
  bool _isSuccess = false;
  StreamSubscription<BluetoothAudioDevice>? _scanSubscription;
  Timer? _scanTimeout;
  
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _loadStatus();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _scanTimeout?.cancel();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await BluetoothAudioService.getStatus();
      setState(() {
        _connectedDevice = status['connected_device'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading status: $e';
      });
    }
  }

  Future<void> _startScan() async {
    // Cancel existing scan if any
    await _scanSubscription?.cancel();
    _scanTimeout?.cancel();
    
    // Stop previous scan (scan off)
    await BluetoothAudioService.stopScan();
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
      _statusMessage = null;
      _isSuccess = false;
    });

    try {
      // Start new scan (scan on) - continues until manually stopped
      _scanSubscription = BluetoothAudioService.scanDevices().listen(
        (device) {
          if (mounted) {
            setState(() {
              final index = _discoveredDevices.indexWhere((d) => d.mac == device.mac);
              if (index >= 0) {
                _discoveredDevices[index] = device;
              } else {
                _discoveredDevices.add(device);
              }
            });
          }
        },
        onError: (e) {
          if (mounted) {
            final errorMsg = e.toString();
            setState(() {
              _isScanning = false;
              if (errorMsg.contains('WiFi')) {
                _statusMessage = 'No WiFi connection. Connect to WiFi and try again.';
              } else if (errorMsg.contains('Pi server') || errorMsg.contains('reach')) {
                _statusMessage = 'Cannot reach Pi server. Check Settings → Pi Server Address.';
              } else {
                _statusMessage = 'Scan error: ${errorMsg.replaceAll('Exception: ', '')}';
              }
              _isSuccess = false;
            });
            
            // Show error with retry option
            if (errorMsg.contains('Pi server') || errorMsg.contains('reach')) {
              _showErrorSnackBar('Cannot reach Pi server. Check your Pi Server Address in Settings.');
            } else if (errorMsg.contains('WiFi')) {
              _showErrorSnackBar('No WiFi connection detected.');
            }
          }
        },
      );
      
      // Set 15 second timeout for UI updates (scan continues in background)
      _scanTimeout = Timer(const Duration(seconds: 15), () {
        if (mounted) {
          setState(() {
            _isScanning = false;
            if (_discoveredDevices.isEmpty) {
              _statusMessage = 'No devices found. Make sure device is in pairing mode.';
              _isSuccess = false;
            }
          });
        }
      });
      
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        setState(() {
          _isScanning = false;
          if (errorMsg.contains('WiFi')) {
            _statusMessage = 'No WiFi connection. Connect to WiFi and try again.';
          } else if (errorMsg.contains('Pi server') || errorMsg.contains('reach')) {
            _statusMessage = 'Cannot reach Pi server. Check Settings → Pi Server Address.';
          } else {
            _statusMessage = 'Scan error: ${errorMsg.replaceAll('Exception: ', '')}';
          }
          _isSuccess = false;
        });
      }
    }
  }

  Future<void> _pairDevice(BluetoothAudioDevice device) async {
    // Check if already connected
    if (_connectedDevice != null) {
      _showErrorSnackBar('Please disconnect the current device first');
      return;
    }

    // Prevent pairing during scan
    if (_isScanning) {
      _showErrorSnackBar('Please wait for scan to complete');
      return;
    }

    // Show pairing dialog
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PairingDialog(device: device),
    );

    if (success == true) {
      HapticFeedback.mediumImpact();
      await _loadStatus();
      setState(() {
        _discoveredDevices.clear(); // Clear list after successful pairing
        _statusMessage = 'Successfully paired with ${device.name}';
        _isSuccess = true;
      });
      _showSuccessSnackBar('Successfully paired with ${device.name}');
    } else {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _disconnectDevice() async {
    if (_connectedDevice == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.gray900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.purple.withOpacity(0.3), width: 2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.purple.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bluetooth_disabled_rounded, color: AppTheme.purple, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Disconnect Device?',
              style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'This will disconnect ${_connectedDevice!['name']} from your S.A.G.E.',
          style: TextStyle(color: AppTheme.gray500, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.gray500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.purple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Disconnect', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await BluetoothAudioService.disconnectDevice(_connectedDevice!['mac']);
        setState(() {
          _connectedDevice = null;
          _discoveredDevices.clear(); // Clear list after disconnecting
          _statusMessage = 'Device disconnected';
          _isSuccess = true;
        });
        _showSuccessSnackBar('Device disconnected');
      } catch (e) {
        _showErrorSnackBar('Failed to disconnect: $e');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _getSignalColor(int rssi) {
    if (rssi >= -60) return Colors.green;
    if (rssi >= -70) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading 
                ? _buildLoadingState()
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.black, Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppTheme.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  'AUDIO DEVICES',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: AppTheme.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48), // Balance back button
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyan.withOpacity(0.2),
              ),
              child: Icon(Icons.headphones_rounded, size: 48, color: AppTheme.cyan),
            ),
          ),
          const SizedBox(height: 24),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppTheme.cyan),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Status message
          if (_statusMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (_isSuccess ? Colors.green : Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_isSuccess ? Colors.green : Colors.orange).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSuccess ? Icons.check_circle : Icons.info_outline,
                    color: _isSuccess ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Connected device section
          if (_connectedDevice != null) ...[
            _buildSectionHeader('CONNECTED DEVICE', 'Currently active audio output'),
            const SizedBox(height: 16),
            _buildConnectedDeviceCard(),
            const SizedBox(height: 32),
          ],

          // Scan section
          _buildSectionHeader('SCAN DEVICES', 'Discover available Bluetooth audio devices'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isScanning ? null : _startScan,
              icon: _isScanning
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyan),
                      ),
                    )
                  : Icon(Icons.bluetooth_searching_rounded, color: AppTheme.cyan),
              label: Text(
                _isScanning ? 'SCANNING...' : 'START SCAN',
                style: TextStyle(
                  color: AppTheme.cyan,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
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
          
          const SizedBox(height: 24),

          // Available devices
          if (_discoveredDevices.isNotEmpty) ...[
            _buildSectionHeader(
              'AVAILABLE DEVICES',
              _isScanning ? 'Scanning... tap devices to pair' : 'Tap to pair',
            ),
            const SizedBox(height: 16),
            ..._discoveredDevices.asMap().entries.map((entry) {
              final index = entry.key;
              final device = entry.value;
              final isConnected = _connectedDevice?['mac'] == device.mac;
              final isDisabled = _isScanning || isConnected;
              
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 400 + (index * 100)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(
                      opacity: value * (isDisabled ? 0.5 : 1.0),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildDeviceTile(device, isConnected, isDisabled),
                ),
              );
            }),
          ],

          // Empty state
          if (!_isScanning && _discoveredDevices.isEmpty && _connectedDevice == null) ...[
            const SizedBox(height: 60),
            _buildEmptyState(),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.cyan,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.gray500,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedDeviceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.purple.withOpacity(0.2), AppTheme.cyan.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyan.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cyan.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.headphones_rounded, color: AppTheme.cyan, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _connectedDevice!['name'],
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Connected',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: AppTheme.purple),
            onPressed: _disconnectDevice,
            tooltip: 'Disconnect',
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(BluetoothAudioDevice device, bool isConnected, bool isDisabled) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : () => _pairDevice(device),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isConnected 
                ? AppTheme.cyan.withOpacity(0.1)
                : AppTheme.gray800,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isConnected 
                  ? AppTheme.cyan
                  : AppTheme.gray700,
              width: isConnected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.headphones_rounded,
                color: isConnected ? AppTheme.cyan : AppTheme.gray500,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 16,
                        fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.mac,
                      style: TextStyle(
                        color: AppTheme.gray500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (device.rssi != null) ...[
                Column(
                  children: [
                    Icon(
                      Icons.signal_cellular_alt,
                      color: _getSignalColor(device.rssi!),
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${device.rssi} dBm',
                      style: TextStyle(
                        color: AppTheme.gray500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
              if (isConnected) ...[
                const SizedBox(width: 12),
                Icon(Icons.check_circle, color: AppTheme.cyan, size: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.gray800,
                border: Border.all(color: AppTheme.gray700, width: 2),
              ),
              child: Icon(
                Icons.bluetooth_disabled_rounded,
                size: 64,
                color: AppTheme.gray500,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No Devices Found',
            style: TextStyle(
              color: AppTheme.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a scan to discover Bluetooth audio devices',
            style: TextStyle(
              color: AppTheme.gray500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Stunning Pairing Dialog with animations
class _PairingDialog extends StatefulWidget {
  final BluetoothAudioDevice device;

  const _PairingDialog({required this.device});

  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog> with TickerProviderStateMixin {
  BluetoothPairingState? _currentState;
  bool _isComplete = false;
  late AnimationController _glowController;
  late AnimationController _rotateController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    _startPairing();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _startPairing() async {
    try {
      await for (final status in BluetoothAudioService.pairDevice(mac: widget.device.mac, name: widget.device.name)) {
        if (mounted) {
          setState(() {
            _currentState = status;
            _isComplete = status.isComplete;
          });

          if (status.isSuccess) {
            HapticFeedback.heavyImpact();
            await Future.delayed(const Duration(milliseconds: 1500));
            if (mounted) Navigator.pop(context, true);
          } else if (status.isFailed) {
            HapticFeedback.vibrate();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentState = BluetoothPairingState(
            status: BluetoothPairingStatus.failed,
            progress: 0,
            message: 'Error: $e',
            timestamp: DateTime.now().toIso8601String(),
          );
          _isComplete = true;
        });
      }
    }
  }

  void _retry() {
    setState(() {
      _currentState = null;
      _isComplete = false;
    });
    _startPairing();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.gray900,
                  AppTheme.gray800.withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _currentState?.isSuccess == true
                    ? Colors.green
                    : _currentState?.isFailed == true
                        ? Colors.red
                        : AppTheme.cyan,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_currentState?.isSuccess == true
                          ? Colors.green
                          : _currentState?.isFailed == true
                              ? Colors.red
                              : AppTheme.cyan)
                      .withOpacity(0.3 * _glowAnimation.value),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Device icon with rotation animation
            RotationTransition(
              turns: _rotateController,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.cyan.withOpacity(0.3),
                      AppTheme.purple.withOpacity(0.3),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    _currentState?.isSuccess == true
                        ? Icons.check_circle_rounded
                        : _currentState?.isFailed == true
                            ? Icons.error_rounded
                            : Icons.headphones_rounded,
                    size: 50,
                    color: _currentState?.isSuccess == true
                        ? Colors.green
                        : _currentState?.isFailed == true
                            ? Colors.red
                            : AppTheme.cyan,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Device name
            Text(
              widget.device.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Pairing steps
            _buildPairingSteps(),
            
            const SizedBox(height: 24),

            // Progress bar
            if (_currentState != null && !_isComplete) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: _currentState!.progress / 100),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: value,
                      backgroundColor: AppTheme.gray700,
                      valueColor: AlwaysStoppedAnimation(AppTheme.cyan),
                      minHeight: 8,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_currentState!.progress}%',
                style: TextStyle(
                  color: AppTheme.gray500,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],

            // Retry/Close button
            if (_isComplete) ...[
              const SizedBox(height: 16),
              if (_currentState?.isFailed == true)
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: Icon(Icons.refresh_rounded),
                  label: Text('RETRY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyan,
                    foregroundColor: AppTheme.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
              else if (_currentState?.isSuccess == true)
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: Icon(Icons.check_rounded),
                  label: Text('DONE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPairingSteps() {
    final steps = [
      {'label': 'Scanning', 'status': 'scanning', 'icon': Icons.bluetooth_searching_rounded},
      {'label': 'Pairing', 'status': 'pairing', 'icon': Icons.sync_rounded},
      {'label': 'Trusting', 'status': 'trusting', 'icon': Icons.verified_user_rounded},
      {'label': 'Connecting', 'status': 'connecting', 'icon': Icons.link_rounded},
      {'label': 'Audio Setup', 'status': 'configuring_audio', 'icon': Icons.volume_up_rounded},
    ];

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final status = step['status'] as String;
        final label = step['label'] as String;
        final iconData = step['icon'] as IconData;
        
        bool isActive = _currentState?.status.toString().split('.').last == status;
        bool isComplete = _currentState != null && index < steps.indexWhere(
          (s) => s['status'] == _currentState!.status.toString().split('.').last
        );
        bool isFailed = _currentState?.isFailed == true;

        IconData finalIcon;
        Color color;

        if (isFailed && isActive) {
          finalIcon = Icons.error_rounded;
          color = Colors.red;
        } else if (isComplete || _currentState?.isSuccess == true) {
          finalIcon = Icons.check_circle_rounded;
          color = Colors.green;
        } else if (isActive) {
          finalIcon = iconData;
          color = AppTheme.cyan;
        } else {
          finalIcon = Icons.circle_outlined;
          color = AppTheme.gray700;
        }

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive ? color.withOpacity(0.2) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(finalIcon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive ? AppTheme.white : AppTheme.gray500,
                      fontSize: 16,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isActive && !_isComplete)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppTheme.cyan),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
