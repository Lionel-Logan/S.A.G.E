import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app-theme.dart';
import '../widgets/sidebar.dart';
import '../services/storage_service.dart';
import '../services/bluetooth_service.dart';
import '../services/bluetooth_audio_service.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../models/paired_device.dart';
import '../models/tts_config.dart';
import '../main.dart';
import 'pairing_flow_screen.dart';
import 'network_settings_screen.dart';
import 'bluetooth_audio_settings_screen.dart';
import 'object_detection_settings_screen.dart';
import 'camera_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Function(String) onNavigate;
  final String currentRoute;

  const SettingsScreen({
    super.key,
    required this.onNavigate,
    required this.currentRoute,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _sidebarOpen = false;
  final ScrollController _scrollController = ScrollController();
  
  PairedDevice? _pairedDevice;
  DateTime? _pairingTimestamp;
  Map<String, String>? _hotspotCredentials;
  bool _isLoading = true;
  
  // Device status polling
  String? _currentNetwork;
  bool _isDeviceConnected = false;
  Timer? _statusPollTimer;
  
  // Detailed device information
  Map<String, dynamic>? _networkDetails;
  Map<String, dynamic>? _bluetoothDetails;
  Map<String, dynamic>? _deviceInfo;
  
  // Bluetooth Audio status
  String? _bluetoothAudioDeviceName;
  bool _bluetoothAudioConnected = false;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Clear cached Pi server URL to trigger fresh discovery
    BluetoothAudioService.clearCache();
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ),
    );
    
    _loadPairingData();
    _animController.forward();
    _startStatusPolling();
    _initializeTTSService();
    _initializeSTTService();
  }

  void _startStatusPolling() {
    // Poll device status every 3 seconds
    _statusPollTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      _pollDeviceStatus();
    });
    // Initial poll
    _pollDeviceStatus();
  }

  Future<void> _pollDeviceStatus() async {
    if (_pairedDevice == null) return;
    
    try {
      // Try to connect
      await BluetoothService.connectToDevice(_pairedDevice!.id);
      
      // Read status
      final statusData = await BluetoothService.readConnectionStatus(_pairedDevice!.id);
      
      // Read detailed information in parallel
      final results = await Future.wait([
        BluetoothService.readNetworkDetails(_pairedDevice!.id),
        BluetoothService.readBluetoothDetails(_pairedDevice!.id),
        BluetoothService.readDeviceInfo(_pairedDevice!.id),
      ]);
      
      // Also fetch Bluetooth audio status
      try {
        final audioStatus = await BluetoothAudioService.getStatus();
        if (mounted) {
          setState(() {
            _bluetoothAudioConnected = audioStatus['connected'] as bool? ?? false;
            _bluetoothAudioDeviceName = audioStatus['device_name'] as String?;
          });
        }
      } catch (e) {
        // Bluetooth audio status failed, just keep defaults
      }
      
      if (mounted) {
        setState(() {
          _isDeviceConnected = statusData != null;
          _currentNetwork = statusData?['network'] as String?;
          _networkDetails = results[0];
          _bluetoothDetails = results[1];
          _deviceInfo = results[2];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeviceConnected = false;
        });
      }
    }
  }

  Future<void> _loadPairingData() async {
    final device = await StorageService.getPairedDevice();
    final timestamp = await StorageService.getPairingTimestamp();
    final credentials = await StorageService.getHotspotCredentials();
    
    setState(() {
      _pairedDevice = device;
      _pairingTimestamp = timestamp;
      _hotspotCredentials = credentials;
      _isLoading = false;
    });
  }

  Future<void> _initializeTTSService() async {
    try {
      // Initialize TTS service with device URL from BluetoothAudioService
      final baseUrl = await BluetoothAudioService.getPiServerUrl();
      TTSService.setBaseUrl(baseUrl);
      
      // Wait a bit for device to be available, then load config
      await Future.delayed(const Duration(seconds: 2));
      await _loadTTSConfig();
    } catch (e) {
      print('Failed to initialize TTS service: $e');
    }
  }

  Future<void> _initializeSTTService() async {
    try {
      // Initialize STT service with device URL from BluetoothAudioService
      final baseUrl = await BluetoothAudioService.getPiServerUrl();
      STTService.setBaseUrl(baseUrl);
    } catch (e) {
      print('Failed to initialize STT service: $e');
    }
  }

  Future<void> _loadTTSConfig() async {
    try {
      // Load current config
      final config = await TTSService.getConfig();
      
      if (mounted) {
        setState(() {
          _currentTTSConfig = config;
          _ttsSpeed = config.voiceSpeed.toDouble();
          _ttsVolume = config.voiceVolume;
          
          // Find matching preset
          final presets = TTSPreset.getPresets();
          final matchingPreset = presets.firstWhere(
            (p) => p.voiceId == config.voiceId,
            orElse: () => presets[0],
          );
          _selectedPreset = matchingPreset.name;
        });
      }
    } catch (e) {
      print('Failed to load TTS config: $e');
      // Continue with defaults
    }
  }

  Future<void> _updateTTSSpeed(double speed) async {
    if (_currentTTSConfig == null) return;
    
    try {
      final updatedConfig = _currentTTSConfig!.copyWith(
        voiceSpeed: speed.round(),
      );
      
      await TTSService.updateConfig(updatedConfig);
      
      setState(() {
        _currentTTSConfig = updatedConfig;
      });
    } catch (e) {
      print('Failed to update TTS speed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update speed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTTSVolume(double volume) async {
    if (_currentTTSConfig == null) return;
    
    try {
      final updatedConfig = _currentTTSConfig!.copyWith(
        voiceVolume: volume,
      );
      
      await TTSService.updateConfig(updatedConfig);
      
      setState(() {
        _currentTTSConfig = updatedConfig;
      });
    } catch (e) {
      print('Failed to update TTS volume: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update volume: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTTSPreset(String voiceId) async {
    if (_currentTTSConfig == null) return;
    
    try {
      final updatedConfig = _currentTTSConfig!.copyWith(
        voiceId: voiceId,
      );
      
      await TTSService.updateConfig(updatedConfig);
      
      setState(() {
        _currentTTSConfig = updatedConfig;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice preset applied'),
            backgroundColor: AppTheme.purple,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Failed to update TTS preset: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply preset: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testTTSVoice() async {
    try {
      await TTSService.testVoice();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playing voice test...'),
            backgroundColor: AppTheme.purple,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Failed to test TTS voice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to test voice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animController.dispose();
    _statusPollTimer?.cancel();
    _googleTTSApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _unpairDevice() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.gray900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.purple.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.purple),
            const SizedBox(width: 12),
            Text(
              'Unpair Device?',
              style: TextStyle(color: AppTheme.white),
            ),
          ],
        ),
        content: Text(
          'This will remove your S.A.G.E connection. You will need to pair again to use the device.',
          style: TextStyle(color: AppTheme.gray500),
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
            ),
            child: Text('Unpair'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.clearPairingData();
      
      if (mounted) {
        // Navigate to pairing flow
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => PairingFlowScreen(
              isAutoMode: false,
              onComplete: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const MainNavigator()),
                  (route) => false,
                );
              },
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  void _repairDevice() async {
    // Start manual pairing directly, skip mode selection
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PairingFlowScreen(
          isAutoMode: false,  // Manual pairing only
          onComplete: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainNavigator()),
              (route) => false,
            );
          },
        ),
      ),
    );
    
    // Reload pairing data after repairing
    if (mounted) {
      await _loadPairingData();
    }
  }

  void _openNetworkSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NetworkSettingsScreen(),
      ),
    );
    
    // Reload data after returning from network settings
    if (mounted) {
      await _loadPairingData();
    }
  }

  void _openBluetoothAudioSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BluetoothAudioSettingsScreen(),
      ),
    );
  }
  
  void _configurePiServer() async {
    // Auto-discover immediately when dialog opens
    String? discoveredHost;
    bool isDiscovering = true;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Auto-discover on first build
          if (isDiscovering && discoveredHost == null) {
            BluetoothAudioService.discoverPiServer().then((discovered) {
              if (context.mounted) {
                setState(() {
                  discoveredHost = discovered;
                  isDiscovering = false;
                });
              }
            });
          }
          
          final controller = TextEditingController(text: discoveredHost ?? '');
          
          return AlertDialog(
            backgroundColor: AppTheme.gray900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.cyan.withOpacity(0.3)),
            ),
            title: Row(
              children: [
                Icon(Icons.dns_rounded, color: AppTheme.cyan),
                const SizedBox(width: 12),
                Text(
                  'Configure S.A.G.E Server',
                  style: TextStyle(color: AppTheme.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDiscovering) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppTheme.cyan),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Auto-discovering S.A.G.E server...',
                            style: TextStyle(color: AppTheme.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  if (discoveredHost != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'S.A.G.E Server Found!',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  discoveredHost!,
                                  style: TextStyle(
                                    color: Colors.green.shade300,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No S.A.G.E server found automatically',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
                Text(
                  'Enter the IP address or hostname of your S.A.G.E server:',
                  style: TextStyle(fontSize: 14, color: AppTheme.gray500),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  style: TextStyle(color: AppTheme.white),
                  decoration: InputDecoration(
                    labelText: 'Host',
                    labelStyle: TextStyle(color: AppTheme.gray500),
                    hintText: 'sage-pi.local or 192.168.1.110',
                    hintStyle: TextStyle(color: AppTheme.gray500),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.gray700),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.gray700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.cyan, width: 2),
                    ),
                  ),
                  enabled: !isDiscovering,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isDiscovering ? null : () async {
                      setState(() => isDiscovering = true);
                      final discovered = await BluetoothAudioService.discoverPiServer();
                      setState(() {
                        discoveredHost = discovered;
                        isDiscovering = false;
                      });
                      
                      if (discovered != null) {
                        controller.text = discovered;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Found S.A.G.E server at: $discovered'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No S.A.G.E server found on network'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    },
                    icon: isDiscovering 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.search, color: AppTheme.cyan),
                    label: Text(
                      isDiscovering ? 'Discovering...' : 'Re-Discover',
                      style: TextStyle(
                        color: AppTheme.cyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppTheme.cyan, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await BluetoothAudioService.resetPiServerHost();
                  // Reinitialize TTS and STT services with default host
                  await _initializeTTSService();
                  await _initializeSTTService();
                  Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Reset to default (sage-pi.local)'),
                        backgroundColor: AppTheme.purple,
                      ),
                    );
                  }
                },
                child: Text('Reset', style: TextStyle(color: AppTheme.gray500)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: AppTheme.gray500)),
              ),
              ElevatedButton(
                onPressed: isDiscovering ? null : () async {
                  final host = controller.text.trim();
                  if (host.isNotEmpty) {
                    await BluetoothAudioService.setPiServerHost(host);
                    // Reinitialize TTS and STT services with new host
                    await _initializeTTSService();
                    await _initializeSTTService();
                    Navigator.pop(context);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('S.A.G.E server set to: $host'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cyan,
                  foregroundColor: AppTheme.black,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showNetworkDetails() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Network Details',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(
            opacity: animation,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.gray900, AppTheme.gray800],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.cyan, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyan.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_rounded, size: 64, color: AppTheme.cyan),
                      const SizedBox(height: 24),
                      Text(
                        'Network Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildDetailRow('Network Name', _currentNetwork ?? 'Not connected', Icons.router_rounded),
                      _buildDetailRow('Signal Strength', _networkDetails?['rssi']?.toString() ?? 'Loading...', Icons.signal_cellular_alt),
                      _buildDetailRow('Frequency', _networkDetails?['frequency']?.toString() ?? 'Loading...', Icons.waves_rounded),
                      _buildDetailRow('Protocol', _networkDetails?['protocol']?.toString() ?? 'Loading...', Icons.security_rounded),
                      _buildDetailRow('IP Address', _networkDetails?['ip_address']?.toString() ?? 'Loading...', Icons.lan_rounded),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cyan,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: Text('CLOSE', style: TextStyle(color: AppTheme.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBluetoothDetails() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Bluetooth Details',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(
            opacity: animation,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.gray900, AppTheme.gray800],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.green, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.green.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bluetooth_rounded, size: 64, color: AppTheme.green),
                      const SizedBox(height: 24),
                      Text(
                        'Bluetooth Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildDetailRow('Glass Device', _bluetoothDetails?['glass_device']?.toString() ?? 'Loading...', Icons.blur_on_rounded),
                      _buildDetailRow('Mobile Device', _bluetoothDetails?['mobile_device']?.toString() ?? 'Loading...', Icons.phone_android_rounded),
                      _buildDetailRow('Signal Strength', _bluetoothDetails?['rssi']?.toString() ?? 'Loading...', Icons.signal_cellular_alt),
                      _buildDetailRow('Connection', _isDeviceConnected ? 'Active' : 'Inactive', Icons.link_rounded),
                      _buildDetailRow('BLE Version', _bluetoothDetails?['ble_version']?.toString() ?? 'Loading...', Icons.info_rounded),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.green,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: Text('CLOSE', style: TextStyle(color: AppTheme.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showWiFiSignalDetails() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'WiFi Signal Details',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(
            opacity: animation,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.gray900, AppTheme.gray800],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.purple, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.purple.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.signal_cellular_alt_rounded, size: 64, color: AppTheme.purple),
                      const SizedBox(height: 24),
                      Text(
                        'WiFi Signal Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildDetailRow('Signal Quality', _networkDetails?['rssi']?.toString() ?? 'Loading...', Icons.speed_rounded),
                      _buildDetailRow('RSSI', _networkDetails?['rssi']?.toString() ?? 'Loading...', Icons.insights_rounded),
                      _buildDetailRow('Link Speed', _networkDetails?['link_speed']?.toString() ?? 'Loading...', Icons.network_check_rounded),
                      _buildDetailRow('Channel', _networkDetails?['channel']?.toString() ?? 'Loading...', Icons.podcasts_rounded),
                      _buildDetailRow('Noise Level', _networkDetails?['noise']?.toString() ?? 'Loading...', Icons.graphic_eq_rounded),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.purple,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: Text('CLOSE', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeviceIdDetails() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Device Details',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(
            opacity: animation,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.gray900, AppTheme.gray800],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.cyan.withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyan.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.devices_rounded, size: 64, color: AppTheme.cyan),
                      const SizedBox(height: 24),
                      Text(
                        'Device Information',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildDetailRow('Device Name', _pairedDevice?.name ?? 'Unknown', Icons.badge_rounded),
                      _buildDetailRow('Device ID', _pairedDevice?.id ?? 'N/A', Icons.fingerprint_rounded),
                      _buildDetailRow('Paired Since', _deviceInfo?['paired_timestamp']?.toString() ?? 'Loading...', Icons.calendar_today_rounded),
                      _buildDetailRow('Device Type', _deviceInfo?['device_type']?.toString() ?? 'Loading...', Icons.remove_red_eye_rounded),
                      _buildDetailRow('Firmware', _deviceInfo?['firmware_version']?.toString() ?? 'Loading...', Icons.system_update_rounded),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cyan,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: Text('CLOSE', style: TextStyle(color: AppTheme.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppTheme.cyan),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.gray500,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0 && !_sidebarOpen) {
            setState(() => _sidebarOpen = true);
          }
          if (details.primaryVelocity! < 0 && _sidebarOpen) {
            setState(() => _sidebarOpen = false);
          }
        },
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                _buildHeader(),

                // Content
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _buildContent(),
                ),
              ],
            ),

            // Sidebar Overlay
            if (_sidebarOpen)
              GestureDetector(
                onTap: () => setState(() => _sidebarOpen = false),
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),

            // Sidebar
            AppSidebar(
              isOpen: _sidebarOpen,
              onClose: () => setState(() => _sidebarOpen = false),
              currentRoute: widget.currentRoute,
              onNavigate: (route) {
                widget.onNavigate(route);
                setState(() => _sidebarOpen = false);
              },
            ),
          ],
        ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => setState(() => _sidebarOpen = true),
              ),
              Text(
                'SETTINGS',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(AppTheme.cyan),
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        children: [
          // Device Status Widget - At the very top
          _buildDetailedDeviceStatusCard(),
          const SizedBox(height: 40),
          
          // CONNECTIVITY Section
          _buildSectionHeader('CONNECTIVITY', 'Network and connection management'),
          const SizedBox(height: 12),
          _buildActionButton(
            'Wi-Fi Settings',
            'Configure WiFi connection for S.A.G.E',
            Icons.wifi_rounded,
            AppTheme.cyan,
            _openNetworkSettings,
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            'Audio Settings',
            'Pair and manage Bluetooth audio devices',
            Icons.headphones_rounded,
            AppTheme.purple,
            _openBluetoothAudioSettings,
          ),
          
          const SizedBox(height: 40),
          
          // DEVICE Section
          _buildSectionHeader('DEVICE', 'Hardware configuration'),
          const SizedBox(height: 16),
          _buildActionButton(
            'Camera Settings',
            'Configure Pi Camera capture and recording',
            Icons.camera_outlined,
            AppTheme.cyan,
            () {
              widget.onNavigate('camera_settings');
            },
          ),
          
          const SizedBox(height: 40),
          
          // SERVICES Section
          _buildSectionHeader('SERVICES', 'Configure AI and processing services'),
          const SizedBox(height: 12),
          _buildSpeechToTextConfig(),
          const SizedBox(height: 16),
          _buildTextToSpeechConfig(),
          const SizedBox(height: 16),
          _buildMachineLearningConfig(),
          const SizedBox(height: 16),
          _buildActionButton(
            'Server IP Settings',
            'Configure S.A.G.E IP address for server connectivity',
            Icons.dns_rounded,
            AppTheme.cyan,
            _configurePiServer,
          ),
          
          const SizedBox(height: 40),
          
          // PAIRING Section  
          _buildSectionHeader('PAIRING', 'Device pairing management'),
          const SizedBox(height: 16),
          _buildActionButton(
            'Re-pair Device',
            'Start a new pairing process',
            Icons.refresh_rounded,
            AppTheme.cyan,
            _repairDevice,
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Unpair Device',
            'Remove current device connection',
            Icons.link_off_rounded,
            AppTheme.purple,
            _unpairDevice,
          ),
          
          const SizedBox(height: 40),
          
          // App Info
          _buildSectionHeader('ABOUT', 'Application information'),
          const SizedBox(height: 16),
          _buildInfoCard(),
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

  Widget _buildDetailedDeviceStatusCard() {
    if (_pairedDevice == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.gray900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.purple.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppTheme.purple,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'No device paired',
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.cyan.withOpacity(0.2),
            AppTheme.purple.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.cyan.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Device icon and name
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppTheme.cyan, AppTheme.purple],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.cyan.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.blur_on_rounded,
                  size: 32,
                  color: AppTheme.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pairedDevice!.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Connection status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isDeviceConnected 
                            ? AppTheme.green.withOpacity(0.2)
                            : AppTheme.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isDeviceConnected 
                              ? AppTheme.green.withOpacity(0.5)
                              : AppTheme.purple.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isDeviceConnected ? AppTheme.green : AppTheme.purple,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isDeviceConnected ? 'Connected' : 'Disconnected',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isDeviceConnected ? AppTheme.green : AppTheme.purple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(color: AppTheme.gray700, height: 1),
          const SizedBox(height: 20),

          // Device details grid
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  Icons.wifi_rounded,
                  'Network',
                  _currentNetwork ?? 'Not connected',
                  _currentNetwork != null ? AppTheme.cyan : AppTheme.gray500,
                  onTap: () => _showNetworkDetails(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusItem(
                  Icons.bluetooth_rounded,
                  'Bluetooth',
                  _isDeviceConnected ? 'Strong' : 'Weak',
                  _isDeviceConnected ? AppTheme.green : AppTheme.purple,
                  onTap: () => _showBluetoothDetails(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  Icons.headphones_rounded,
                  'Audio Device',
                  _bluetoothAudioConnected 
                    ? (_bluetoothAudioDeviceName ?? 'Connected')
                    : 'Not Connected',
                  _bluetoothAudioConnected ? AppTheme.green : AppTheme.gray500,
                  onTap: () => _showBluetoothAudioStatus(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusItem(
                  Icons.devices_rounded,
                  'Device ID',
                  _pairedDevice!.id.substring(0, 8) + '...',
                  AppTheme.gray500,
                  onTap: () => _showDeviceIdDetails(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, String value, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.gray900.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.gray800),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.gray500,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairedDeviceCard() {
    if (_pairedDevice == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.gray900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.purple.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppTheme.purple,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'No device paired',
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.cyan.withOpacity(0.2),
            AppTheme.purple.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.cyan.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Device icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.cyan, AppTheme.purple],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.cyan.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.blur_on_rounded,
              size: 40,
              color: AppTheme.white,
            ),
          ),

          const SizedBox(height: 16),

          // Device name
          Text(
            _pairedDevice!.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.white,
            ),
          ),

          const SizedBox(height: 8),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.green.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.green,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'CONNECTED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.green,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.gray700,
        ),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            'Device ID',
            _pairedDevice?.id ?? 'Unknown',
            Icons.fingerprint_rounded,
          ),
          const Divider(color: AppTheme.gray700, height: 24),
          _buildDetailRow(
            'Paired',
            _pairingTimestamp != null
                ? _pairedDevice!.getTimeSincePairing()
                : 'Unknown',
            Icons.access_time_rounded,
          ),
          const Divider(color: AppTheme.gray700, height: 24),
          _buildDetailRow(
            'Hotspot SSID',
            _hotspotCredentials?['ssid'] ?? 'Not configured',
            Icons.wifi_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.gray900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.gray700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'S.A.G.E',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Situational Awareness and Guidance Engine',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.gray500,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Divider(color: AppTheme.gray700, height: 24),
          _buildInfoRow('Version', 'v1.0.0'),
          const Divider(color: AppTheme.gray700, height: 24),
          _buildInfoRow('Build', '001'),
          const Divider(color: AppTheme.gray700, height: 24),
          _buildInfoRow('Platform', 'Flutter'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.gray500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Speech to Text Configuration Widget
  String _selectedSTTEngine = 'Vosk'; // Default to Vosk
  bool _showGoogleApiKeyInput = false;
  bool _showSTTEngineOptions = false; // Toggle for dropdown
  final TextEditingController _googleApiKeyController = TextEditingController();

  // Text to Speech Configuration
  String _selectedTTSEngine = 'On-device'; // Default to On-device
  bool _showTTSOptions = false; // Toggle for dropdown
  bool _showTTSAdvanced = false; // Toggle for advanced settings
  double _ttsSpeed = 175.0; // Default speed (WPM)
  double _ttsVolume = 0.9; // Default volume (0.0-1.0)
  String _selectedPreset = 'Default Female'; // Default preset
  bool _isTestingVoice = false;
  TTSConfig? _currentTTSConfig;
  final TextEditingController _googleTTSApiKeyController = TextEditingController();
  
  // Machine Learning Configuration
  bool _showMLOptions = false; // Toggle for ML dropdown

  Widget _buildSpeechToTextConfig() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (_showSTTEngineOptions || _showGoogleApiKeyInput) ? AppTheme.cyan : AppTheme.gray800,
          width: 2,
        ),
        boxShadow: (_showSTTEngineOptions || _showGoogleApiKeyInput)
            ? [
                BoxShadow(
                  color: AppTheme.cyan.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 0,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with current selection
          GestureDetector(
            onTap: () {
              setState(() {
                _showSTTEngineOptions = !_showSTTEngineOptions;
                // If closing dropdown, also close API key input
                if (!_showSTTEngineOptions) {
                  _showGoogleApiKeyInput = false;
                }
              });
            },
            child: Container(
              color: Colors.transparent,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.record_voice_over, color: AppTheme.cyan, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Speech-To-Text Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                          ),
                        ),
                        Text(
                          _selectedSTTEngine == 'Vosk' ? 'Vosk' : 'Google',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.cyan,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: (_showSTTEngineOptions || _showGoogleApiKeyInput) ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.expand_more,
                      color: AppTheme.gray500,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Engine Selection Cards with smooth animation
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: (_showSTTEngineOptions || _showGoogleApiKeyInput) 
              ? Column(
                  children: [
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSTTEngine = 'Vosk';
                          _showGoogleApiKeyInput = false;
                          // Keep dropdown open
                        });
                      },
                      child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selectedSTTEngine == 'Vosk' 
                      ? AppTheme.cyan.withOpacity(0.1)
                      : AppTheme.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedSTTEngine == 'Vosk'
                        ? AppTheme.cyan
                        : AppTheme.gray800,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _selectedSTTEngine == 'Vosk'
                            ? AppTheme.cyan.withOpacity(0.2)
                            : AppTheme.gray900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.asset(
                        'assets/images/vosk_logo.png',
                        width: 24,
                        height: 24,
                        color: _selectedSTTEngine == 'Vosk'
                            ? null
                            : AppTheme.gray500,
                        colorBlendMode: _selectedSTTEngine == 'Vosk'
                            ? BlendMode.dst
                            : BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vosk',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Local • Offline • Slower',
                            style: TextStyle(
                              color: AppTheme.gray500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedSTTEngine == 'Vosk')
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.cyan,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSTTEngine = 'Google';
                  _showGoogleApiKeyInput = true;
                  // Keep dropdown open to show API key input
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selectedSTTEngine == 'Google'
                      ? AppTheme.cyan.withOpacity(0.1)
                      : AppTheme.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedSTTEngine == 'Google'
                        ? AppTheme.cyan
                        : AppTheme.gray800,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _selectedSTTEngine == 'Google'
                            ? AppTheme.cyan.withOpacity(0.2)
                            : AppTheme.gray900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.asset(
                        'assets/images/google_logo.png',
                        width: 24,
                        height: 24,
                        color: _selectedSTTEngine == 'Google'
                            ? null
                            : AppTheme.gray500,
                        colorBlendMode: _selectedSTTEngine == 'Google'
                            ? BlendMode.dst
                            : BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Google',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cloud • Online • Faster',
                            style: TextStyle(
                              color: AppTheme.gray500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedSTTEngine == 'Google')
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.cyan,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
            
            // Google API Key Input (expandable)
            if (_showGoogleApiKeyInput) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cyan.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cyan.withOpacity(0.3)),
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Google Cloud API Key',
                    style: TextStyle(
                      color: AppTheme.cyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _googleApiKeyController,
                    style: TextStyle(color: AppTheme.white),
                    decoration: InputDecoration(
                      hintText: 'Enter your API key',
                      hintStyle: TextStyle(color: AppTheme.gray500),
                      filled: true,
                      fillColor: AppTheme.gray900,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.gray800),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.gray800),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.cyan),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.gray900,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: AppTheme.gray500),
                            const SizedBox(width: 8),
                            Text(
                              'Setup Instructions',
                              style: TextStyle(
                                color: AppTheme.gray500,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1. Go to Google Cloud Console\n'
                          '2. Enable Speech-to-Text API\n'
                          '3. Create credentials (API Key)\n'
                          '4. Copy and paste the key above',
                          style: TextStyle(
                            color: AppTheme.gray500,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final apiKey = _googleApiKeyController.text.trim();
                        if (apiKey.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please enter an API key'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        try {
                          await STTService.saveGoogleApiKey(apiKey);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Google STT API key saved successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to save API key: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cyan,
                        foregroundColor: AppTheme.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Save API Key',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                ),
              ),
            ],
                  ],
                )
              : const SizedBox.shrink(),
          ),
        ], // Closing children of main Column
      ), // Closing Column
    ); // Closing Container
  }

  // Text to Speech Configuration Widget
  Widget _buildTextToSpeechConfig() {
    final presets = TTSPreset.getPresets();
    final selectedPreset = presets.firstWhere(
      (p) => p.name == _selectedPreset,
      orElse: () => presets[0],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _showTTSOptions ? AppTheme.purple : AppTheme.gray800,
          width: 2,
        ),
        boxShadow: _showTTSOptions
            ? [
                BoxShadow(
                  color: AppTheme.purple.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 0,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with dropdown toggle
          GestureDetector(
            onTap: () {
              setState(() {
                _showTTSOptions = !_showTTSOptions;
                if (!_showTTSOptions) {
                  _showTTSAdvanced = false;
                }
              });
            },
            child: Container(
              color: Colors.transparent,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.campaign_rounded,
                      color: AppTheme.purple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Text-To-Speech Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                          ),
                        ),
                        Text(
                          _selectedTTSEngine,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.purple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showTTSOptions ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.expand_more,
                      color: AppTheme.gray500,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content with animation
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showTTSOptions
                ? Column(
                    children: [
                      const SizedBox(height: 20),

                      // Engine Selection (boilerplate)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTTSEngine = 'On-device';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _selectedTTSEngine == 'On-device'
                                ? AppTheme.purple.withOpacity(0.1)
                                : AppTheme.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedTTSEngine == 'On-device'
                                  ? AppTheme.purple
                                  : AppTheme.gray800,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _selectedTTSEngine == 'On-device'
                                      ? AppTheme.purple.withOpacity(0.2)
                                      : AppTheme.gray900,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.phone_android_rounded,
                                  color: _selectedTTSEngine == 'On-device'
                                      ? AppTheme.purple
                                      : AppTheme.gray500,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'On-device',
                                      style: TextStyle(
                                        color: AppTheme.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Local • Offline • Fast',
                                      style: TextStyle(
                                        color: AppTheme.gray500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_selectedTTSEngine == 'On-device')
                                Icon(
                                  Icons.check_circle,
                                  color: AppTheme.purple,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTTSEngine = 'Google';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _selectedTTSEngine == 'Google'
                                ? AppTheme.purple.withOpacity(0.1)
                                : AppTheme.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedTTSEngine == 'Google'
                                  ? AppTheme.purple
                                  : AppTheme.gray800,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _selectedTTSEngine == 'Google'
                                      ? AppTheme.purple.withOpacity(0.2)
                                      : AppTheme.gray900,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Image.asset(
                                  'assets/images/google_logo.png',
                                  width: 24,
                                  height: 24,
                                  color: _selectedTTSEngine == 'Google'
                                      ? null
                                      : AppTheme.gray500,
                                  colorBlendMode: _selectedTTSEngine == 'Google'
                                      ? BlendMode.dst
                                      : BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Google',
                                      style: TextStyle(
                                        color: AppTheme.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Cloud • Online • Premium',
                                      style: TextStyle(
                                        color: AppTheme.gray500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_selectedTTSEngine == 'Google')
                                Icon(
                                  Icons.check_circle,
                                  color: AppTheme.purple,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Show API Key input for Google, Voice controls for On-device
                      if (_selectedTTSEngine == 'Google') ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.purple.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.purple.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Google Cloud Text-to-Speech API Key',
                                style: TextStyle(
                                  color: AppTheme.purple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _googleTTSApiKeyController,
                                style: TextStyle(color: AppTheme.white),
                                decoration: InputDecoration(
                                  hintText: 'Enter your API key',
                                  hintStyle: TextStyle(color: AppTheme.gray500),
                                  filled: true,
                                  fillColor: AppTheme.gray900,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: AppTheme.gray800),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: AppTheme.gray800),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: AppTheme.purple),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.gray900,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline, size: 16, color: AppTheme.gray500),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Setup Instructions',
                                          style: TextStyle(
                                            color: AppTheme.gray500,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '1. Go to Google Cloud Console\n'
                                      '2. Create a new project or select existing\n'
                                      '3. Enable Cloud Text-to-Speech API\n'
                                      '4. Create credentials (API Key)\n'
                                      '5. Copy and paste the key above',
                                      style: TextStyle(
                                        color: AppTheme.gray500,
                                        fontSize: 11,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final apiKey = _googleTTSApiKeyController.text.trim();
                                    if (apiKey.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Please enter an API key'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    try {
                                      await TTSService.saveGoogleApiKey(apiKey);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Google TTS API key saved successfully'),
                                            backgroundColor: AppTheme.purple,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to save API key: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.purple,
                                    foregroundColor: AppTheme.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'Save API Key',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Voice controls only for On-device
                      if (_selectedTTSEngine == 'On-device') ...[
                        const SizedBox(height: 24),
                        Divider(color: AppTheme.gray800, height: 1),
                        const SizedBox(height: 24),

                        // Voice Preset Selection
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            color: AppTheme.purple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Voice Preset',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Preset Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.5,
                        ),
                        itemCount: presets.length,
                        itemBuilder: (context, index) {
                          final preset = presets[index];
                          final isSelected = _selectedPreset == preset.name;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPreset = preset.name;
                              });
                              _updateTTSPreset(preset.voiceId);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.purple.withOpacity(0.2)
                                    : AppTheme.black,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.purple
                                      : AppTheme.gray800,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    preset.icon,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          preset.name,
                                          style: TextStyle(
                                            color: AppTheme.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check,
                                            color: AppTheme.purple,
                                            size: 14,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Speed Control
                      Row(
                        children: [
                          Icon(
                            Icons.speed_rounded,
                            color: AppTheme.purple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Speed',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_ttsSpeed.round()} WPM',
                            style: TextStyle(
                              color: AppTheme.purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppTheme.purple,
                          inactiveTrackColor: AppTheme.gray800,
                          thumbColor: AppTheme.purple,
                          overlayColor: AppTheme.purple.withOpacity(0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _ttsSpeed,
                          min: 100,
                          max: 300,
                          divisions: 40,
                          onChanged: (value) {
                            setState(() {
                              _ttsSpeed = value;
                            });
                          },
                          onChangeEnd: (value) {
                            _updateTTSSpeed(value);
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Volume Control
                      Row(
                        children: [
                          Icon(
                            Icons.volume_up_rounded,
                            color: AppTheme.purple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Volume',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(_ttsVolume * 100).round()}%',
                            style: TextStyle(
                              color: AppTheme.purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppTheme.purple,
                          inactiveTrackColor: AppTheme.gray800,
                          thumbColor: AppTheme.purple,
                          overlayColor: AppTheme.purple.withOpacity(0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _ttsVolume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          onChanged: (value) {
                            setState(() {
                              _ttsVolume = value;
                            });
                          },
                          onChangeEnd: (value) {
                            _updateTTSVolume(value);
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Test Voice Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isTestingVoice
                              ? null
                              : () async {
                                  setState(() {
                                    _isTestingVoice = true;
                                  });
                                  try {
                                    await _testTTSVoice();
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isTestingVoice = false;
                                      });
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.purple,
                            foregroundColor: AppTheme.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _isTestingVoice
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      AppTheme.white,
                                    ),
                                  ),
                                )
                              : Icon(Icons.play_arrow_rounded, size: 20),
                          label: Text(
                            _isTestingVoice ? 'Testing...' : 'Test Voice',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Advanced Settings Toggle
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showTTSAdvanced = !_showTTSAdvanced;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.gray800),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                color: AppTheme.gray500,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Advanced Settings',
                                style: TextStyle(
                                  color: AppTheme.gray500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedRotation(
                                turns: _showTTSAdvanced ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.expand_more,
                                  color: AppTheme.gray500,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Advanced Settings Content
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: _showTTSAdvanced
                            ? Column(
                                children: [
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.black,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.gray800,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Current Voice ID',
                                          style: TextStyle(
                                            color: AppTheme.gray500,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          selectedPreset.voiceId,
                                          style: TextStyle(
                                            color: AppTheme.purple,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          selectedPreset.description,
                                          style: TextStyle(
                                            color: AppTheme.gray500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      ], // End of On-device conditional
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
  
  // Machine Learning Configuration Widget
  Widget _buildMachineLearningConfig() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _showMLOptions ? AppTheme.cyan : AppTheme.gray800,
          width: 2,
        ),
        boxShadow: _showMLOptions
            ? [
                BoxShadow(
                  color: AppTheme.cyan.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 0,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showMLOptions = !_showMLOptions;
              });
            },
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.smart_toy_outlined,
                    color: AppTheme.cyan,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Machine Learning Settings',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configure AI models and detection',
                        style: TextStyle(
                          color: AppTheme.gray500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _showMLOptions ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    color: AppTheme.cyan,
                  ),
                ),
              ],
            ),
          ),
          
          // Expandable content with animation
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showMLOptions
                ? Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // Object Detection Option
                      InkWell(
                        onTap: () {
                          widget.onNavigate('object_detection_settings');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.cyan.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.cyan.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.search_outlined,
                                  color: AppTheme.cyan,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Object Detection',
                                      style: TextStyle(
                                        color: AppTheme.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Configure detection settings',
                                      style: TextStyle(
                                        color: AppTheme.gray500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: AppTheme.gray500,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Facial Recognition Option
                      InkWell(
                        onTap: () {
                          // TODO: Navigate to facial recognition settings
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Facial Recognition - Coming Soon'),
                              backgroundColor: AppTheme.cyan,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.purple.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.face_outlined,
                                  color: AppTheme.purple,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Facial Recognition',
                                      style: TextStyle(
                                        color: AppTheme.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Configure face detection settings',
                                      style: TextStyle(
                                        color: AppTheme.gray500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: AppTheme.gray500,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // Bluetooth Audio Status Dialog
  void _showBluetoothAudioStatus() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.gray900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.purple.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.headphones_rounded, color: AppTheme.purple),
            const SizedBox(width: 12),
            Text(
              'Audio Device',
              style: TextStyle(color: AppTheme.white),
            ),
          ],
        ),
        content: FutureBuilder<Map<String, dynamic>>(
          future: BluetoothAudioService.getStatus(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppTheme.purple),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Checking Bluetooth status...',
                    style: TextStyle(color: AppTheme.gray500),
                  ),
                ],
              );
            }
            
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 32),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to get status',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: TextStyle(color: AppTheme.gray500, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            
            final status = snapshot.data!;
            final isConnected = status['connected'] as bool? ?? false;
            final deviceName = status['device_name'] as String?;
            final deviceAddress = status['device_address'] as String?;
            
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.gray900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.gray800),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isConnected ? Icons.check_circle : Icons.cancel,
                        color: isConnected ? Colors.green : AppTheme.gray500,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isConnected ? 'Connected' : 'Not Connected',
                          style: TextStyle(
                            color: isConnected ? Colors.green : AppTheme.gray500,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isConnected && deviceName != null) ...[
                    const Divider(color: AppTheme.gray800, height: 24),
                    _buildInfoRowInDialog('Device Name', deviceName),
                    if (deviceAddress != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRowInDialog('Address', deviceAddress),
                    ],
                  ],
                  if (!isConnected) ...[
                    const SizedBox(height: 12),
                    Text(
                      'No Bluetooth audio device is currently connected',
                      style: TextStyle(
                        color: AppTheme.gray500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppTheme.purple)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRowInDialog(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.gray500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
