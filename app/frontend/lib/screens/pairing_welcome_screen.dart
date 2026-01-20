import 'package:flutter/material.dart';
import '../theme/app-theme.dart';

/// Welcome screen for first-time pairing
class PairingWelcomeScreen extends StatefulWidget {
  final VoidCallback onContinue;

  const PairingWelcomeScreen({
    super.key,
    required this.onContinue,
  });

  @override
  State<PairingWelcomeScreen> createState() => _PairingWelcomeScreenState();
}

class _PairingWelcomeScreenState extends State<PairingWelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Animated background gradient
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topRight,
                        radius: 1.5,
                        colors: [
                          AppTheme.cyan.withOpacity(0.15 * _fadeAnimation.value),
                          AppTheme.purple.withOpacity(0.1 * _fadeAnimation.value),
                          AppTheme.black,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  // Logo/Icon
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.cyan,
                              AppTheme.purple,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.cyan.withOpacity(0.5),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.blur_on_rounded,
                          size: 60,
                          color: AppTheme.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Welcome text
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            'Welcome to',
                            style: TextStyle(
                              fontSize: 24,
                              color: AppTheme.gray500,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [AppTheme.cyan, AppTheme.purple],
                            ).createShader(bounds),
                            child: Text(
                              'S.A.G.E',
                              style: TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.white,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Smart Augmented Glass Experience',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.gray500,
                              letterSpacing: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 64),

                  // Description
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.cyan.withOpacity(0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildFeatureItem(
                            Icons.bluetooth_rounded,
                            'Pair with your SAGE Glass',
                          ),
                          const SizedBox(height: 16),
                          _buildFeatureItem(
                            Icons.wifi_rounded,
                            'Connect via WiFi Hotspot',
                          ),
                          const SizedBox(height: 16),
                          _buildFeatureItem(
                            Icons.rocket_launch_rounded,
                            'Experience the future',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Continue button
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildContinueButton(),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.cyan.withOpacity(0.2),
          ),
          child: Icon(
            icon,
            color: AppTheme.cyan,
            size: 20,
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
    );
  }

  Widget _buildContinueButton() {
    return GestureDetector(
      onTap: widget.onContinue,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.cyan, AppTheme.purple],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.cyan.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'PAIR DEVICE',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.white,
            ),
          ],
        ),
      ),
    );
  }
}
