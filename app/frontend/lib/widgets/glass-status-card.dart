import 'package:flutter/material.dart';
import '../models/glass-status.dart';
import '../theme/app-theme.dart';

class GlassStatusCard extends StatefulWidget {
  final GlassStatus status;
  final VoidCallback? onToggle;

  const GlassStatusCard({
    super.key,
    required this.status,
    this.onToggle,
  });

  @override
  State<GlassStatusCard> createState() => _GlassStatusCardState();
}

class _GlassStatusCardState extends State<GlassStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Glass Visual with pulsing glow
          _GlassVisual(
            status: widget.status,
            glowAnimation: _glowAnimation,
          ),
          const SizedBox(height: 24),
          
          // Status Text with smooth fade
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Column(
              key: ValueKey(widget.status.statusText),
              children: [
                Text(
                  widget.status.statusText,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.status.statusDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.gray500,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Demo Toggle Button
          if (widget.onToggle != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: widget.onToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gray800,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                elevation: 0,
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
  final Animation<double> glowAnimation;

  const _GlassVisual({
    required this.status,
    required this.glowAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final color = status.isConnected ? AppTheme.cyan : Colors.red;
    
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Animated Glow Effect
            Container(
              width: 200,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(glowAnimation.value),
                    blurRadius: 50,
                    spreadRadius: 15,
                  ),
                ],
              ),
            ),
            
            // Glass Frame
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    status.isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    key: ValueKey(status.isConnected),
                    size: 48,
                    color: color,
                  ),
                ),
              ),
            ),
            
            // Status Indicator Dot
            Positioned(
              top: 0,
              right: 20,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: status.isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.black, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: (status.isConnected ? Colors.green : Colors.red)
                          .withOpacity(0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}