import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app-theme.dart';

/// Helper widget to guide users through Android 12+ permission flow
class Android12PermissionHelper {
  
  /// Show educational dialog before requesting permissions
  static Future<bool> showPermissionRationale(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.gray900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.cyan.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.bluetooth, color: AppTheme.cyan),
            const SizedBox(width: 12),
            Text(
              'Bluetooth Permissions',
              style: TextStyle(color: AppTheme.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SAGE needs Bluetooth permissions to:',
              style: TextStyle(
                color: AppTheme.gray500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            _buildPermissionItem(
              Icons.search,
              'Scan for your S.A.G.E device',
            ),
            _buildPermissionItem(
              Icons.link,
              'Connect and communicate with Glass',
            ),
            _buildPermissionItem(
              Icons.location_on,
              'Locate nearby Bluetooth devices',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.cyan.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.cyan,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Required for Android 12+',
                      style: TextStyle(
                        color: AppTheme.cyan,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.gray500),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cyan,
              foregroundColor: AppTheme.black,
            ),
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    ) ?? false;
  }

  static Widget _buildPermissionItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.cyan.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppTheme.cyan),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show dialog when permissions are denied
  static Future<void> showPermissionDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.gray900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.purple.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.purple),
            const SizedBox(width: 12),
            Text(
              'Permissions Required',
              style: TextStyle(color: AppTheme.white),
            ),
          ],
        ),
        content: Text(
          'SAGE cannot connect to your Glass without Bluetooth permissions. '
          'Please grant permissions in the next dialog to continue.',
          style: TextStyle(
            color: AppTheme.gray500,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.gray500),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.purple,
              foregroundColor: AppTheme.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Show dialog for permanently denied permissions
  static Future<void> showPermanentlyDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.gray900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.purple.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.block, color: AppTheme.purple),
            const SizedBox(width: 12),
            Text(
              'Permissions Blocked',
              style: TextStyle(color: AppTheme.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bluetooth permissions have been permanently denied. '
              'To use SAGE, you must enable them in Settings.',
              style: TextStyle(
                color: AppTheme.gray500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.gray800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Steps to enable:',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Open Settings\n'
                    '2. Go to Apps → SAGE\n'
                    '3. Tap Permissions\n'
                    '4. Enable "Nearby devices" and "Location"',
                    style: TextStyle(
                      color: AppTheme.gray500,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.gray500),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cyan,
              foregroundColor: AppTheme.black,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Show guide for manually enabling WiFi hotspot (Android 12+ restriction)
  static Future<void> showHotspotEnableGuide(
    BuildContext context,
    String ssid,
    String password,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.gray900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.cyan.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.wifi_tethering, color: AppTheme.cyan),
            const SizedBox(width: 12),
            Text(
              'Enable WiFi Hotspot',
              style: TextStyle(color: AppTheme.white),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Android security requires you to enable WiFi hotspot manually.',
                style: TextStyle(
                  color: AppTheme.gray500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              
              // Step-by-step guide
              _buildHotspotStep('1', 'Open Settings'),
              _buildHotspotStep('2', 'Go to Network & Internet'),
              _buildHotspotStep('3', 'Tap Hotspot & tethering'),
              _buildHotspotStep('4', 'Enable WiFi hotspot'),
              
              const SizedBox(height: 20),
              
              // Credentials box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.cyan.withOpacity(0.1),
                      AppTheme.purple.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.cyan.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use these credentials:',
                      style: TextStyle(
                        color: AppTheme.cyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCredentialRow('Network name', ssid),
                    const SizedBox(height: 8),
                    _buildCredentialRow('Password', password),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.purple.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.purple,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Once enabled, return to this app',
                        style: TextStyle(
                          color: AppTheme.purple,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cyan,
              foregroundColor: AppTheme.black,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('I\'ve Enabled Hotspot'),
          ),
        ],
      ),
    );
  }

  static Widget _buildHotspotStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.cyan, AppTheme.purple],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildCredentialRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.gray500,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              color: AppTheme.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
