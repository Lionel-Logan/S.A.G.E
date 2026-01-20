import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app-theme.dart';
import '../models/pairing_step.dart';
import '../services/pairing_service.dart';
import '../services/bluetooth_service.dart';
import '../widgets/pairing_step_widget.dart';
import '../widgets/animated_check_icon.dart';

/// Main pairing flow screen with immersive animated experience
class PairingFlowScreen extends StatefulWidget {
  final bool isAutoMode;
  final VoidCallback onComplete;

  const PairingFlowScreen({
    super.key,
    required this.isAutoMode,
    required this.onComplete,
  });

  @override
  State<PairingFlowScreen> createState() => _PairingFlowScreenState();
}

class _PairingFlowScreenState extends State<PairingFlowScreen>
    with TickerProviderStateMixin {
  late PairingService _pairingService;
  PairingStep _currentStep = PairingStep.initial();
  StreamSubscription? _stepSubscription;

  // For manual mode
  List<BluetoothDeviceInfo> _scannedDevices = [];
  bool _isScanning = false;
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  // Animations
  late AnimationController _progressAnimController;
  late AnimationController _stepAnimController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _pairingService = PairingService(isAutoMode: widget.isAutoMode);

    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _stepAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressAnimController,
        curve: Curves.easeInOut,
      ),
    );

    // Listen to pairing steps
    _stepSubscription = _pairingService.stepStream.listen((step) {
      setState(() {
        _currentStep = step;
      });

      // Animate progress
      final progress = step.stepNumber / step.totalSteps;
      _progressAnimController.animateTo(
        progress,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );

      // Handle step completion
      if (step.isComplete) {
        Future.delayed(const Duration(seconds: 2), () {
          widget.onComplete();
        });
      }

      // Handle auto-detect failure - switch to manual
      if (widget.isAutoMode && step.isFailed) {
        _handleAutoDetectFailure(step);
      }
    });

    // Start pairing
    Future.delayed(const Duration(milliseconds: 500), () {
      _pairingService.startPairing();
    });
  }

  void _handleAutoDetectFailure(PairingStep step) {
    // Show option to switch to manual mode
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.gray900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.cyan.withOpacity(0.3)),
        ),
        title: Text(
          'Auto-detect failed',
          style: TextStyle(color: AppTheme.white),
        ),
        content: Text(
          step.error ?? 'Failed to automatically pair. Would you like to try manual mode?',
          style: TextStyle(color: AppTheme.gray500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.gray500)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _switchToManualMode();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cyan,
            ),
            child: Text('Try Manual Mode'),
          ),
        ],
      ),
    );
  }

  void _switchToManualMode() {
    setState(() {
      _pairingService.dispose();
      _pairingService = PairingService(isAutoMode: false);
      _currentStep = PairingStep.initial();
    });

    _stepSubscription?.cancel();
    _stepSubscription = _pairingService.stepStream.listen((step) {
      setState(() {
        _currentStep = step;
      });

      final progress = step.stepNumber / step.totalSteps;
      _progressAnimController.animateTo(
        progress,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );

      if (step.isComplete) {
        Future.delayed(const Duration(seconds: 2), () {
          widget.onComplete();
        });
      }
    });

    _pairingService.startPairing();
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _pairingService.dispose();
    _progressAnimController.dispose();
    _stepAnimController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Animated background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 2.0,
                        colors: [
                          AppTheme.cyan.withOpacity(0.1 * _progressAnimation.value),
                          AppTheme.purple.withOpacity(0.05 * _progressAnimation.value),
                          AppTheme.black,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Main content
            Column(
              children: [
                // Progress header
                _buildProgressHeader(),

                // Step content
                Expanded(
                  child: _buildStepContent(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.gray800,
              ),
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progressAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.cyan, AppTheme.purple],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep.stepNumber} of ${_currentStep.totalSteps}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.gray500,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${(_progressAnimation.value * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    if (_currentStep.isComplete) {
      return _buildCompletionScreen();
    }

    if (_currentStep.type == PairingStepType.manualScan &&
        _currentStep.isWaitingForUser) {
      return _buildManualScanUI();
    }

    if (_currentStep.type == PairingStepType.manualCredentials &&
        _currentStep.isWaitingForUser) {
      return _buildManualCredentialsUI();
    }

    if (_currentStep.type == PairingStepType.hotspotEnable &&
        _currentStep.isWaitingForUser) {
      return _buildHotspotEnableUI();
    }

    // Default step view
    return PairingStepWidget(step: _currentStep);
  }

  Widget _buildCompletionScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Success animation
          AnimatedCheckIcon(size: 120),

          const SizedBox(height: 32),

          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [AppTheme.cyan, AppTheme.purple],
            ).createShader(bounds),
            child: Text(
              'Pairing Complete!',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppTheme.white,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Your SAGE Glass is ready to use',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.gray500,
            ),
          ),

          const SizedBox(height: 48),

          // Launching dashboard indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppTheme.cyan),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Launching dashboard...',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.gray500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualScanUI() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentStep.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.white,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _currentStep.description,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.gray500,
            ),
          ),

          const SizedBox(height: 32),

          // Scan button
          if (!_isScanning)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startManualScan,
                icon: Icon(Icons.search_rounded, color: AppTheme.white),
                label: Text(
                  'SCAN FOR DEVICES',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cyan,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          if (_isScanning)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.gray900,
                borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(width: 16),
                  Text(
                    'Scanning for devices...',
                    style: TextStyle(color: AppTheme.white),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Device list
          Expanded(
            child: ListView.builder(
              itemCount: _scannedDevices.length,
              itemBuilder: (context, index) {
                final device = _scannedDevices[index];
                return _buildDeviceItem(device);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(BluetoothDeviceInfo device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.cyan.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.cyan.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.bluetooth_rounded,
            color: AppTheme.cyan,
          ),
        ),
        title: Text(
          device.name,
          style: TextStyle(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Signal: ${_getSignalText(device.signalStrength)}',
          style: TextStyle(color: AppTheme.gray500),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: AppTheme.cyan,
          size: 16,
        ),
        onTap: () => _selectDevice(device),
      ),
    );
  }

  String _getSignalText(int strength) {
    if (strength >= 4) return 'Excellent';
    if (strength >= 3) return 'Good';
    if (strength >= 2) return 'Fair';
    return 'Weak';
  }

  void _startManualScan() async {
    setState(() {
      _isScanning = true;
      _scannedDevices.clear();
    });

    await for (final devices in BluetoothService.scanForDevices()) {
      setState(() {
        _scannedDevices = devices;
      });
    }

    setState(() {
      _isScanning = false;
    });
  }

  void _selectDevice(BluetoothDeviceInfo device) {
    _pairingService.setSelectedDevice(device.id, device.name);
  }

  Widget _buildManualCredentialsUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentStep.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.white,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _currentStep.description,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.gray500,
            ),
          ),

          const SizedBox(height: 32),

          // SSID field
          _buildTextField(
            controller: _ssidController,
            label: 'WiFi Hotspot Name (SSID)',
            hint: 'e.g., MyPhone-Hotspot',
            icon: Icons.wifi_rounded,
          ),

          const SizedBox(height: 20),

          // Password field
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Enter hotspot password',
            icon: Icons.lock_rounded,
            obscureText: !_passwordVisible,
            suffixIcon: IconButton(
              icon: Icon(
                _passwordVisible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: AppTheme.gray500,
              ),
              onPressed: () {
                setState(() {
                  _passwordVisible = !_passwordVisible;
                });
              },
            ),
          ),

          const SizedBox(height: 32),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.cyan.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.cyan,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Enter your phone\'s WiFi hotspot credentials',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitCredentials,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cyan,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'CONTINUE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppTheme.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.gray500,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(color: AppTheme.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.gray500),
            prefixIcon: Icon(icon, color: AppTheme.cyan),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppTheme.gray900,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.gray700),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.gray700),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.cyan, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  void _submitCredentials() {
    if (_ssidController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: AppTheme.purple,
        ),
      );
      return;
    }

    _pairingService.setHotspotCredentials(
      _ssidController.text,
      _passwordController.text,
    );
  }

  Widget _buildHotspotEnableUI() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_tethering_rounded,
            size: 80,
            color: AppTheme.cyan,
          ),

          const SizedBox(height: 32),

          Text(
            'Enable WiFi Hotspot',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.white,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Text(
            'Please enable your phone\'s WiFi hotspot with the credentials you just entered',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.gray500,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 48),

          // Instructions
          _buildInstructionStep(
            1,
            'Open your phone settings',
          ),
          _buildInstructionStep(
            2,
            'Go to "Mobile Hotspot" or "Tethering"',
          ),
          _buildInstructionStep(
            3,
            'Enable WiFi Hotspot',
          ),
          _buildInstructionStep(
            4,
            'Return to this app and confirm',
          ),

          const SizedBox(height: 48),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _pairingService.confirmHotspotEnabled();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cyan,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'HOTSPOT IS ENABLED',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppTheme.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cyan.withOpacity(0.2),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: AppTheme.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
