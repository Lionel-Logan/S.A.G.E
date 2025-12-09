import 'package:flutter/material.dart';
import '../theme/app-theme.dart';

class SettingCategoryHeader extends StatefulWidget {
  final String title;
  final String? description;
  final int index;

  const SettingCategoryHeader({
    super.key,
    required this.title,
    this.description,
    required this.index,
  });

  @override
  State<SettingCategoryHeader> createState() => _SettingCategoryHeaderState();
}

class _SettingCategoryHeaderState extends State<SettingCategoryHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _hasAnimated = false; // Track if animation has played

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    // Animate only once when first built
    if (!_hasAnimated) {
      Future.delayed(Duration(milliseconds: widget.index * 80), () {
        if (mounted && !_hasAnimated) {
          _controller.forward();
          _hasAnimated = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If already animated, skip animation and show directly
    if (_hasAnimated && _controller.isCompleted) {
      return _buildContent();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: AppTheme.white,
            ),
          ),
          if (widget.description != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}