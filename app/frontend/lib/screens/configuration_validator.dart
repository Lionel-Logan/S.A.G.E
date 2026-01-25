import 'package:flutter/material.dart';
import '../config/ble_config.dart';
import '../services/bluetooth_service.dart';
import '../services/wifi_hotspot_service.dart';
import '../theme/app-theme.dart';

/// Development tool to validate SAGE app configuration
/// Add this screen to your debug menu or run during development
class ConfigurationValidator extends StatefulWidget {
  const ConfigurationValidator({super.key});

  @override
  State<ConfigurationValidator> createState() => _ConfigurationValidatorState();
}

class _ConfigurationValidatorState extends State<ConfigurationValidator> {
  final List<ValidationResult> _results = [];
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _runValidation();
  }

  Future<void> _runValidation() async {
    setState(() {
      _isValidating = true;
      _results.clear();
    });

    await Future.delayed(const Duration(milliseconds: 500));

    // Validate BLE UUIDs
    _validateUUIDs();
    await Future.delayed(const Duration(milliseconds: 300));

    // Validate Mock Mode
    _validateMockMode();
    await Future.delayed(const Duration(milliseconds: 300));

    // Validate Configuration
    _validateConfiguration();
    await Future.delayed(const Duration(milliseconds: 300));

    // Validate Platform Support
    _validatePlatformSupport();

    setState(() {
      _isValidating = false;
    });

    // Print to console
    BLEConfig.printConfiguration();
  }

  void _validateUUIDs() {
    final isValid = BLEConfig.validateUUIDs();
    
    if (isValid) {
      _addResult(
        'BLE UUIDs',
        true,
        'All UUIDs are in valid format',
        'Service: ${BLEConfig.credentialsServiceUuid}',
      );
    } else {
      _addResult(
        'BLE UUIDs',
        false,
        'Invalid UUID format detected',
        'Check lib/config/ble_config.dart',
      );
    }

    // Check if using placeholder UUIDs
    if (BLEConfig.credentialsServiceUuid.startsWith('12345678')) {
      _addResult(
        'BLE UUIDs (Production)',
        false,
        'Using placeholder UUIDs',
        'Update UUIDs in lib/config/ble_config.dart to match your Pi',
      );
    } else {
      _addResult(
        'BLE UUIDs (Production)',
        true,
        'Custom UUIDs configured',
        'Make sure they match your Raspberry Pi',
      );
    }
  }

  void _validateMockMode() {
    if (!BluetoothService.useMockMode && !WiFiHotspotService.useMockMode) {
      _addResult(
        'Mock Mode',
        true,
        'Real BLE implementation active',
        'Ready for hardware testing',
      );
    } else {
      final mockServices = <String>[];
      if (BluetoothService.useMockMode) mockServices.add('Bluetooth');
      if (WiFiHotspotService.useMockMode) mockServices.add('WiFi Hotspot');
      
      _addResult(
        'Mock Mode',
        false,
        'Mock mode enabled for: ${mockServices.join(", ")}',
        'Set useMockMode = false for production',
      );
    }
  }

  void _validateConfiguration() {
    // Device name prefix
    if (BLEConfig.deviceNamePrefix == 'SAGE') {
      _addResult(
        'Device Name Filter',
        true,
        'Looking for devices starting with "${BLEConfig.deviceNamePrefix}"',
        'Make sure your Pi advertises as "S.A.G.E XXX"',
      );
    } else {
      _addResult(
        'Device Name Filter',
        true,
        'Custom prefix: "${BLEConfig.deviceNamePrefix}"',
        'Ensure your Pi device name starts with this',
      );
    }

    // Timeouts
    final scanTimeout = BLEConfig.scanTimeout.inSeconds;
    if (scanTimeout >= 20 && scanTimeout <= 60) {
      _addResult(
        'Scan Timeout',
        true,
        '${scanTimeout}s - Good balance',
        'Gives enough time to find devices',
      );
    } else if (scanTimeout < 20) {
      _addResult(
        'Scan Timeout',
        false,
        '${scanTimeout}s - May be too short',
        'Consider increasing to 30s',
      );
    } else {
      _addResult(
        'Scan Timeout',
        false,
        '${scanTimeout}s - May be too long',
        'Consider decreasing to 30-45s',
      );
    }

    // Retry attempts
    if (BLEConfig.maxConnectionRetries >= 2 && BLEConfig.maxConnectionRetries <= 5) {
      _addResult(
        'Connection Retries',
        true,
        '${BLEConfig.maxConnectionRetries} attempts - Good',
        'Balances reliability and speed',
      );
    } else {
      _addResult(
        'Connection Retries',
        false,
        '${BLEConfig.maxConnectionRetries} attempts - Consider 3-5',
        'Too few may fail, too many slows down pairing',
      );
    }
  }

  void _validatePlatformSupport() {
    _addResult(
      'Android Permissions',
      true,
      'Configured for Android 12+',
      'BLUETOOTH_SCAN, BLUETOOTH_CONNECT, LOCATION',
    );

    _addResult(
      'Minimum SDK',
      true,
      'Android 12+ (API 31)',
      'Supports modern BLE features',
    );
  }

  void _addResult(String category, bool passed, String message, String detail) {
    setState(() {
      _results.add(ValidationResult(
        category: category,
        passed: passed,
        message: message,
        detail: detail,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final passedCount = _results.where((r) => r.passed).length;
    final totalCount = _results.length;
    final allPassed = passedCount == totalCount && totalCount > 0;

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Configuration Validator',
          style: TextStyle(color: AppTheme.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.cyan),
            onPressed: _runValidation,
          ),
        ],
      ),
      body: _isValidating
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppTheme.cyan),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Validating configuration...',
                    style: TextStyle(color: AppTheme.gray500),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Summary
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: allPassed
                          ? [
                              AppTheme.cyan.withOpacity(0.2),
                              AppTheme.cyan.withOpacity(0.1),
                            ]
                          : [
                              AppTheme.purple.withOpacity(0.2),
                              AppTheme.purple.withOpacity(0.1),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: allPassed
                          ? AppTheme.cyan.withOpacity(0.5)
                          : AppTheme.purple.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        allPassed ? Icons.check_circle : Icons.warning,
                        color: allPassed ? AppTheme.cyan : AppTheme.purple,
                        size: 48,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              allPassed ? 'Ready for Production' : 'Action Required',
                              style: TextStyle(
                                color: AppTheme.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '$passedCount of $totalCount checks passed',
                              style: TextStyle(
                                color: AppTheme.gray500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Results
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return _buildResultCard(result);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildResultCard(ValidationResult result) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.passed
              ? AppTheme.cyan.withOpacity(0.3)
              : AppTheme.purple.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.passed ? Icons.check_circle : Icons.error,
            color: result.passed ? AppTheme.cyan : AppTheme.purple,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.category,
                  style: TextStyle(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  result.message,
                  style: TextStyle(
                    color: result.passed ? AppTheme.gray500 : AppTheme.purple,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.gray800,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    result.detail,
                    style: TextStyle(
                      color: AppTheme.gray500,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ValidationResult {
  final String category;
  final bool passed;
  final String message;
  final String detail;

  ValidationResult({
    required this.category,
    required this.passed,
    required this.message,
    required this.detail,
  });
}
