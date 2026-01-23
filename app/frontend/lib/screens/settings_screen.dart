import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app-theme.dart';
import '../widgets/sidebar.dart';
import '../services/storage_service.dart';
import '../services/bluetooth_service.dart';
import '../models/paired_device.dart';
import '../main.dart';
import 'pairing_flow_screen.dart';
import 'network_settings_screen.dart';
import 'bluetooth_settings_screen.dart';

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
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
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

  @override
  void dispose() {
    _scrollController.dispose();
    _animController.dispose();
    _statusPollTimer?.cancel();
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

  void _openBluetoothSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BluetoothSettingsScreen(),
      ),
    );
    
    // Reload data after returning from Bluetooth settings
    if (mounted) {
      await _loadPairingData();
    }
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
          const SizedBox(height: 16),
          _buildActionButton(
            'Network Settings',
            'Configure WiFi connection for S.A.G.E',
            Icons.wifi_rounded,
            AppTheme.cyan,
            _openNetworkSettings,
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Bluetooth Settings',
            'Manage Bluetooth audio devices',
            Icons.bluetooth_audio,
            AppTheme.purple,
            _openBluetoothSettings,
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
                  Icons.signal_cellular_alt_rounded,
                  'WiFi Signal',
                  _currentNetwork != null ? 'Good' : 'No signal',
                  _currentNetwork != null ? AppTheme.green : AppTheme.gray500,
                  onTap: () => _showWiFiSignalDetails(),
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
}
