import 'package:flutter/material.dart';
import '../theme/app-theme.dart';
import '../widgets/sidebar.dart';
import '../services/storage_service.dart';
import '../models/paired_device.dart';
import '../main.dart';
import 'pairing_welcome_screen.dart';
import 'pairing_mode_selection_screen.dart';
import 'pairing_flow_screen.dart';

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
          'This will remove your SAGE Glass connection. You will need to pair again to use the device.',
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
        // Navigate to root and replace with pairing flow
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const _RepairNavigator(),
          ),
          (route) => false,
        );
      }
    }
  }

  void _repairDevice() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const _RepairNavigator(),
      ),
    );
    
    // Reload pairing data after repairing
    if (result == true || mounted) {
      await _loadPairingData();
    }
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
          // Device Pairing Section
          _buildSectionHeader('DEVICE PAIRING', 'Manage your SAGE Glass connection'),
          const SizedBox(height: 16),
          _buildPairedDeviceCard(),
          const SizedBox(height: 24),
          _buildConnectionDetails(),
          
          const SizedBox(height: 40),
          
          // Quick Actions
          _buildSectionHeader('QUICK ACTIONS', 'Device management shortcuts'),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppTheme.cyan,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.gray500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
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
        children: [
          _buildInfoRow('Version', 'SAGE v1.0.0'),
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

/// Re-pairing navigator
class _RepairNavigator extends StatefulWidget {
  const _RepairNavigator();

  @override
  State<_RepairNavigator> createState() => _RepairNavigatorState();
}

class _RepairNavigatorState extends State<_RepairNavigator> {
  int _currentStep = 0;
  bool _isAutoMode = true;

  void _goToModeSelection() {
    setState(() {
      _currentStep = 1;
    });
  }

  void _startPairing(bool isAutoMode) {
    setState(() {
      _isAutoMode = isAutoMode;
      _currentStep = 2;
    });
  }

  void _completePairing() {
    // Navigate to MainNavigator, removing all previous routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const MainNavigator(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return PairingWelcomeScreen(onContinue: _goToModeSelection);
      case 1:
        return PairingModeSelectionScreen(onModeSelected: _startPairing);
      case 2:
        return PairingFlowScreen(
          isAutoMode: _isAutoMode,
          onComplete: _completePairing,
        );
      default:
        return PairingWelcomeScreen(onContinue: _goToModeSelection);
    }
  }
}
