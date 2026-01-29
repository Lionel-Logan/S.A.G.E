import 'package:flutter/material.dart';
import '../models/bluetooth_audio_device.dart';
import '../theme/app-theme.dart';

class BluetoothDeviceTile extends StatelessWidget {
  final BluetoothAudioDevice device;
  final VoidCallback? onTap;
  final bool isConnected;

  const BluetoothDeviceTile({
    super.key,
    required this.device,
    required this.onTap,
    this.isConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.gray900,
        border: Border.all(
          color: isConnected 
              ? AppTheme.cyan.withOpacity(0.5)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Device icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.gray800,
                  ),
                  child: Icon(
                    _getDeviceIcon(),
                    color: isConnected ? AppTheme.cyan : AppTheme.gray500,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Device info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              device.name,
                              style: TextStyle(
                                color: AppTheme.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.cyan.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'CONNECTED',
                                style: TextStyle(
                                  color: AppTheme.cyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.mac,
                        style: TextStyle(
                          color: AppTheme.gray500,
                          fontSize: 12,
                        ),
                      ),
                      if (device.rssi != null) ...[
                        const SizedBox(height: 8),
                        _buildSignalStrength(),
                      ],
                    ],
                  ),
                ),
                
                // Arrow icon
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.gray500,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getDeviceIcon() {
    if (device.isAudio) {
      // Check device name for specific types
      final nameLower = device.name.toLowerCase();
      if (nameLower.contains('airpods') || 
          nameLower.contains('earbud') || 
          nameLower.contains('ear')) {
        return Icons.earbuds_rounded;
      } else if (nameLower.contains('speaker') || 
                 nameLower.contains('jbl') || 
                 nameLower.contains('bose')) {
        return Icons.speaker_rounded;
      } else {
        return Icons.headphones_rounded;
      }
    }
    return Icons.bluetooth_rounded;
  }

  Widget _buildSignalStrength() {
    final percent = device.signalStrengthPercent;
    final bars = (percent / 25).ceil().clamp(1, 4);
    
    Color color;
    if (percent >= 75) {
      color = Colors.green;
    } else if (percent >= 50) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Row(
      children: [
        // Signal bars
        Row(
          children: List.generate(4, (index) {
            final isActive = index < bars;
            return Container(
              width: 3,
              height: 8 + (index * 2.0),
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: isActive ? color : AppTheme.gray700,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
        const SizedBox(width: 8),
        Text(
          '${device.rssi} dBm · ${device.signalStrengthLabel}',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
