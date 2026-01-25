import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import '../theme/app-theme.dart';

/// Screen prompting user to enable Bluetooth
class BluetoothEnableScreen extends StatefulWidget {
  final VoidCallback onBluetoothEnabled;

  const BluetoothEnableScreen({
    super.key,
    required this.onBluetoothEnabled,
  });

  @override
  State<BluetoothEnableScreen> createState() => _BluetoothEnableScreenState();
}

class _BluetoothEnableScreenState extends State<BluetoothEnableScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _bluetoothStateSubscription;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Listen for Bluetooth state changes
    _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        widget.onBluetoothEnabled();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bluetoothStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkBluetoothState() async {
    setState(() {
      _isChecking = true;
    });

    try {
      final isOn = await FlutterBluePlus.isOn;
      if (isOn) {
        widget.onBluetoothEnabled();
      } else {
        // Show message that Bluetooth is still off
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Bluetooth is still turned off. Please enable it.'),
              backgroundColor: AppTheme.purple,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking Bluetooth state: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Animated Bluetooth icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.cyan.withOpacity(0.2),
                    border: Border.all(
                      color: AppTheme.cyan,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyan.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.bluetooth_disabled,
                    size: 60,
                    color: AppTheme.cyan,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Title
              Text(
                'Bluetooth Required',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.white,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'S.A.G.E requires Bluetooth to communicate with your smart glasses.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.gray500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Instructions card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.gray900,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.gray800),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.cyan,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'How to enable Bluetooth:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionStep('1', 'Swipe down from the top of your screen'),
                    const SizedBox(height: 12),
                    _buildInstructionStep('2', 'Tap the Bluetooth icon to turn it ON'),
                    const SizedBox(height: 12),
                    _buildInstructionStep('3', 'Return to this app'),
                  ],
                ),
              ),

              const Spacer(),

              // Retry button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkBluetoothState,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyan,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                    shadowColor: AppTheme.cyan.withOpacity(0.5),
                  ),
                  child: _isChecking
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                          ),
                        )
                      : Text(
                          'I\'VE ENABLED BLUETOOTH',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.black,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.cyan.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.cyan, width: 1.5),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.cyan,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.gray500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
