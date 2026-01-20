import 'package:flutter/material.dart';
import '../theme/app-theme.dart';

/// Screen for selecting pairing mode (Auto or Manual)
class PairingModeSelectionScreen extends StatefulWidget {
  final Function(bool isAutoMode) onModeSelected;

  const PairingModeSelectionScreen({
    super.key,
    required this.onModeSelected,
  });

  @override
  State<PairingModeSelectionScreen> createState() =>
      _PairingModeSelectionScreenState();
}

class _PairingModeSelectionScreenState
    extends State<PairingModeSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Pairing Mode',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Select how you\'d like to connect your SAGE Glass',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // Auto mode
                        Expanded(
                          child: _buildModeCard(
                            title: 'AUTO-DETECT',
                            subtitle: 'Recommended',
                            description:
                                'Automatically scan and connect to your SAGE Glass with minimal input',
                            icon: Icons.auto_fix_high_rounded,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.cyan.withOpacity(0.8),
                                AppTheme.cyan.withOpacity(0.4),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: () => widget.onModeSelected(true),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Manual mode
                        Expanded(
                          child: _buildModeCard(
                            title: 'MANUAL SETUP',
                            subtitle: 'For advanced users',
                            description:
                                'Step-by-step guided setup with full control over the pairing process',
                            icon: Icons.tune_rounded,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.purple.withOpacity(0.8),
                                AppTheme.purple.withOpacity(0.4),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: () => widget.onModeSelected(false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: AppTheme.white,
                ),
              ),

              const SizedBox(height: 24),

              // Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  subtitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.white,
                    letterSpacing: 1,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.white,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.white.withOpacity(0.9),
                  height: 1.5,
                ),
              ),

              const Spacer(),

              // Arrow
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
