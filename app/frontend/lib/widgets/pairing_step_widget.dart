import 'package:flutter/material.dart';
import '../theme/app-theme.dart';
import '../models/pairing_step.dart';

/// Widget to display current pairing step with animations
class PairingStepWidget extends StatefulWidget {
  final PairingStep step;

  const PairingStepWidget({
    super.key,
    required this.step,
  });

  @override
  State<PairingStepWidget> createState() => _PairingStepWidgetState();
}

class _PairingStepWidgetState extends State<PairingStepWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _animController.forward();
  }

  @override
  void didUpdateWidget(PairingStepWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.type != widget.step.type) {
      _animController.reset();
      _animController.forward();
    }
  }

  void _setupAnimations() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status icon
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildStatusIcon(),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  widget.step.title,
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
                  widget.step.description,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.gray500,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Status indicator
                if (widget.step.status == StepStatus.inProgress)
                  _buildProgressIndicator(),

                if (widget.step.status == StepStatus.failed)
                  _buildErrorMessage(),

                // Additional data
                if (widget.step.data != null && widget.step.data!.isNotEmpty)
                  _buildDataDisplay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    switch (widget.step.status) {
      case StepStatus.pending:
        icon = Icons.pending_outlined;
        color = AppTheme.gray500;
        break;
      case StepStatus.inProgress:
        icon = _getStepIcon();
        color = AppTheme.cyan;
        break;
      case StepStatus.completed:
        icon = Icons.check_circle_rounded;
        color = AppTheme.green;
        break;
      case StepStatus.failed:
        icon = Icons.error_rounded;
        color = AppTheme.purple;
        break;
      case StepStatus.waitingForUser:
        icon = Icons.touch_app_rounded;
        color = AppTheme.yellow;
        break;
    }

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.2),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 60,
        color: color,
      ),
    );
  }

  IconData _getStepIcon() {
    switch (widget.step.type) {
      case PairingStepType.bluetoothPermission:
        return Icons.security_rounded;
      case PairingStepType.bluetoothCheck:
        return Icons.bluetooth_searching_rounded;
      case PairingStepType.scanning:
      case PairingStepType.manualScan:
        return Icons.radar_rounded;
      case PairingStepType.bluetoothConnect:
        return Icons.bluetooth_connected_rounded;
      case PairingStepType.hotspotDetection:
        return Icons.wifi_find_rounded;
      case PairingStepType.credentialTransfer:
        return Icons.send_rounded;
      case PairingStepType.hotspotEnable:
        return Icons.wifi_tethering_rounded;
      case PairingStepType.glassConnection:
        return Icons.sync_rounded;
      case PairingStepType.verification:
        return Icons.verified_rounded;
      default:
        return Icons.blur_on_rounded;
    }
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(AppTheme.cyan),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Please wait...',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.gray500,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.purple.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppTheme.purple,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.step.error ?? 'An error occurred',
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

  Widget _buildDataDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cyan.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.cyan.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: widget.step.data!.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${entry.key}:',
                  style: TextStyle(
                    color: AppTheme.gray500,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${entry.value}',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
