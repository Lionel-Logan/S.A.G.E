import 'package:flutter/material.dart';
import '../theme/app-theme.dart';
import '../services/network_service.dart';
import '../services/bluetooth_service.dart';
import '../services/storage_service.dart';
import '../models/paired_device.dart';
import 'dart:async';

class NetworkSettingsScreen extends StatefulWidget {
  const NetworkSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NetworkSettingsScreen> createState() => _NetworkSettingsScreenState();
}

class _NetworkSettingsScreenState extends State<NetworkSettingsScreen> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isScanning = false;
  String? _statusMessage;
  bool _isSuccess = false;
  PairedDevice? _pairedDevice;
  WiFiCredentials? _savedWiFi;
  List<Map<String, dynamic>> _availableNetworks = [];
  String? _selectedSSID;
  bool _isConfiguring = false;  // Lock to prevent concurrent configuration attempts
  DateTime? _lastConnectionTime;  // Track last successful connection
  String? _currentNetwork;  // Current connected network
  Timer? _networkPollTimer;  // Timer for polling current network

  @override
  void initState() {
    super.initState();
    _loadData();
    _startNetworkPolling();
  }

  void _startNetworkPolling() {
    // Poll current network every 3 seconds for more responsive updates
    _networkPollTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      _pollCurrentNetwork();
    });
    // Initial poll
    _pollCurrentNetwork();
  }

  Future<void> _pollCurrentNetwork() async {
    if (_pairedDevice == null) return;
    
    try {
      // Try to connect first if needed
      await BluetoothService.connectToDevice(_pairedDevice!.id);
      
      // Read the status
      final statusData = await BluetoothService.readConnectionStatus(_pairedDevice!.id);
      
      if (statusData != null && mounted) {
        final network = statusData['network'] as String?;
        // Only update if network has changed to avoid unnecessary rebuilds
        if (network != _currentNetwork) {
          setState(() {
            _currentNetwork = network;
          });
        }
      } else if (mounted) {
        // If we can't read status, clear the current network after a delay
        // (don't clear immediately to avoid flashing)
        Future.delayed(Duration(seconds: 6), () {
          if (mounted && _currentNetwork != null) {
            setState(() {
              _currentNetwork = null;
            });
          }
        });
      }
    } catch (e) {
      // Log error but don't clear network immediately
      print('Network polling error: $e');
    }
  }

  Future<void> _loadData() async {
    final device = await StorageService.getPairedDevice();
    final wifi = await StorageService.getWiFiCredentials();
    
    setState(() {
      _pairedDevice = device;
      _savedWiFi = wifi;
      if (wifi != null) {
        _passwordController.text = wifi.password;
      }
    });
    
    // Auto-scan networks on load
    if (_pairedDevice != null) {
      _scanNetworks();
    }
  }

  Future<void> _scanNetworks() async {
    if (_pairedDevice == null) return;
    
    setState(() {
      _isScanning = true;
      _statusMessage = null;
    });

    try {
      final networks = await BluetoothService.scanWiFiNetworks(_pairedDevice!.id);
      setState(() {
        _availableNetworks = networks;
        _isScanning = false;
        if (networks.isEmpty) {
          _statusMessage = 'No networks found. Try scanning again.';
        }
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Failed to scan networks: $e';
      });
    }
  }

  Color _getSignalColor(int signal) {
    if (signal >= 75) return Colors.green;
    if (signal >= 50) return Colors.orange;
    return Colors.red;
  }

  Future<void> _configureNetwork() async {
    // Check 30-second cooldown
    if (_lastConnectionTime != null) {
      final timeSinceLastConnection = DateTime.now().difference(_lastConnectionTime!);
      if (timeSinceLastConnection.inSeconds < 30) {
        final remaining = 30 - timeSinceLastConnection.inSeconds;
        setState(() {
          _statusMessage = 'Please wait $remaining seconds before switching networks again';
          _isSuccess = false;
        });
        return;
      }
    }
    
    // Prevent concurrent configuration attempts
    if (_isConfiguring) {
      print('NetworkSettingsScreen: Configuration already in progress, ignoring duplicate call');
      return;
    }
    
    if (_pairedDevice == null) {
      setState(() {
        _statusMessage = 'No device paired. Please pair a device first.';
        _isSuccess = false;
      });
      return;
    }

    if (_selectedSSID == null || _selectedSSID!.isEmpty) {
      setState(() {
        _statusMessage = 'Please select a WiFi network';
        _isSuccess = false;
      });
      return;
    }

    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter the WiFi password';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _isConfiguring = true;  // Set lock
    });

    try {
      // Show connection dialog (it will handle the WiFi configuration)
      _showConnectionDialog(context, _selectedSSID!);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
        _isSuccess = false;
        _isConfiguring = false;  // Release lock on error
      });
    }
  }

  void _showConnectionDialog(BuildContext context, String ssid) {
    StreamSubscription? subscription;
    bool streamComplete = false;
    bool streamStarted = false;  // Flag to prevent multiple stream creations

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        String statusText = 'Connecting to $ssid...';
        bool isComplete = false;
        bool isSuccess = false;

        return StatefulBuilder(
          builder: (context, setState) {
            // Only create stream once using the flag
            if (!streamStarted && subscription == null && !streamComplete) {
              streamStarted = true;  // Set flag immediately
              
              final stream = NetworkService.configureWiFi(
                deviceId: _pairedDevice!.id,
                ssid: ssid,
                password: _passwordController.text.trim(),
              );

              subscription = stream.listen(
                (status) {
                  if (!streamComplete) {
                    setState(() {
                      statusText = status.message;
                      isComplete = status.status != ConnectionStatus.connecting;
                      isSuccess = status.status == ConnectionStatus.connected;
                    });

                    if (isComplete) {
                      // Update last connection time on success
                      if (isSuccess) {
                        _lastConnectionTime = DateTime.now();
                      }
                      Future.delayed(const Duration(seconds: 2), () {
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                          this.setState(() {
                            _isLoading = false;
                            _statusMessage = status.message;
                            _isSuccess = isSuccess;
                            _isConfiguring = false;  // Release lock when complete
                          });
                        }
                      });
                    }
                  }
                },
                onDone: () {
                  streamComplete = true;
                  if (!isComplete && dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                    this.setState(() {
                      _isConfiguring = false;  // Release lock when stream completes
                      _isLoading = false;
                      _statusMessage = 'Connection attempt completed';
                      _isSuccess = false;
                    });
                  }
                },
                onError: (error) {
                  streamComplete = true;
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                    this.setState(() {
                      _isLoading = false;
                      _statusMessage = 'Error: $error';
                      _isSuccess = false;
                    });
                  }
                },
              );
            }

            return AlertDialog(
              backgroundColor: AppTheme.gray800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Network Configuration',
                style: TextStyle(color: AppTheme.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isComplete)
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyan),
                    ),
                  if (isComplete)
                    Icon(
                      isSuccess ? Icons.check_circle : Icons.error,
                      color: isSuccess ? Colors.green : Colors.red,
                      size: 48,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    statusText,
                    style: TextStyle(color: AppTheme.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      subscription?.cancel();
    });
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
            color: AppTheme.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
            fillColor: AppTheme.gray800,
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

  @override
  Widget build(BuildContext context) {
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
          'WiFi',
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
                'Configure WiFi Network',
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a WiFi network and connect your S.A.G.E',
                style: TextStyle(
                  color: AppTheme.gray500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              
              // Important network requirement message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cyan.withOpacity(0.3), width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.cyan,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'IMPORTANT',
                            style: TextStyle(
                              color: AppTheme.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Both your phone and S.A.G.E must be connected to the same WiFi network for proper functionality.',
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
              
              if (_currentNetwork != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.wifi, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Currently connected: $_currentNetwork',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),

              // Scan networks button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isScanning ? null : _scanNetworks,
                  icon: _isScanning
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyan),
                          ),
                        )
                      : Icon(Icons.refresh, color: AppTheme.cyan),
                  label: Text(
                    _isScanning ? 'SCANNING...' : 'SCAN NETWORKS',
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
              const SizedBox(height: 20),

              // Available networks list
              if (_availableNetworks.isNotEmpty) ...[
                Text(
                  'Available Networks',
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
                    itemCount: _availableNetworks.length,
                    separatorBuilder: (context, index) => Divider(
                      color: AppTheme.gray700,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final network = _availableNetworks[index];
                      final ssid = network['ssid'] as String;
                      final signal = network['signal'] as int;
                      final secured = network['secured'] as bool;
                      final isSelected = _selectedSSID == ssid;

                      return ListTile(
                        onTap: () {
                          setState(() {
                            _selectedSSID = ssid;
                          });
                        },
                        selected: isSelected,
                        selectedTileColor: AppTheme.cyan.withOpacity(0.1),
                        leading: Icon(
                          Icons.wifi,
                          color: isSelected ? AppTheme.cyan : _getSignalColor(signal),
                        ),
                        title: Text(
                          ssid,
                          style: TextStyle(
                            color: AppTheme.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          secured ? 'Secured' : 'Open',
                          style: TextStyle(
                            color: AppTheme.gray500,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$signal%',
                              style: TextStyle(
                                color: _getSignalColor(signal),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (secured)
                              Icon(Icons.lock, color: AppTheme.gray500, size: 16),
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(Icons.check_circle, color: AppTheme.cyan, size: 20),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Password field
              _buildTextField(
                controller: _passwordController,
                label: 'WiFi Password',
                hint: 'Enter password for selected network',
                icon: Icons.lock,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: AppTheme.gray500,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: 32),

              // Configure button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || _selectedSSID == null || _isConfiguring) ? null : _configureNetwork,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyan,
                    foregroundColor: AppTheme.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: AppTheme.gray700,
                  ),
                  child: Text(
                    _selectedSSID != null ? 'CONNECT TO $_selectedSSID' : 'SELECT A NETWORK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),

              // Status message
              if (_statusMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isSuccess 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSuccess 
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle : Icons.error,
                        color: _isSuccess ? Colors.green : Colors.red,
                        size: 24,
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _networkPollTimer?.cancel();
    super.dispose();
  }
}
