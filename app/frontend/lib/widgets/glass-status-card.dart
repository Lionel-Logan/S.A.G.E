import 'package:flutter/material.dart';
import '../models/glass-status.dart';
import '../theme/app-theme.dart';

class GlassStatusCard extends StatelessWidget {
  final GlassStatus status;
  final VoidCallback? onToggle; // For demo purposes

  const GlassStatusCard({
    super.key,
    required this.status,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [AppTheme.gray900, AppTheme.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.gray800, width: 1),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Glass Visual
          _GlassVisual(status: status),
          const SizedBox(height: 24),
          
          // Status Text
          Text(
            status.statusText,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status.statusDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.gray500,
              letterSpacing: 1.5,
            ),
          ),
          
          // Demo Toggle Button (remove in production)
          if (onToggle != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gray800,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'TOGGLE STATUS',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlassVisual extends StatelessWidget {
  final GlassStatus status;

  const _GlassVisual({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.isConnected ? AppTheme.cyan : Colors.red;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow Effect
        Container(
          width: 200,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
        ),
        
        // Glass Frame
        Container(
          width: 192,
          height: 128,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: AppTheme.gray700, width: 4),
            gradient: LinearGradient(
              colors: [AppTheme.gray800, AppTheme.gray900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(
              status.isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              size: 48,
              color: color,
            ),
          ),
        ),
        
        // Status Indicator Dot
        Positioned(
          top: 0,
          right: 20,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: status.isConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.black, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}