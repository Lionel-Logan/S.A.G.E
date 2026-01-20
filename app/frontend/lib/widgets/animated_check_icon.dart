import 'package:flutter/material.dart';
import '../theme/app-theme.dart';

/// Animated check/success icon with particle effects
class AnimatedCheckIcon extends StatefulWidget {
  final double size;
  final Color color;

  const AnimatedCheckIcon({
    super.key,
    this.size = 80,
    this.color = AppTheme.green,
  });

  @override
  State<AnimatedCheckIcon> createState() => _AnimatedCheckIconState();
}

class _AnimatedCheckIconState extends State<AnimatedCheckIcon>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _checkController;
  late AnimationController _rotationController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // Scale animation for the circle
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    // Check mark draw animation
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: Curves.easeOut,
      ),
    );

    // Rotation animation
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animations in sequence
    _scaleController.forward().then((_) {
      _checkController.forward();
      _rotationController.forward();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _checkController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _scaleAnimation,
        _checkAnimation,
        _rotationAnimation,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 0.1,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    widget.color,
                    widget.color.withOpacity(0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _CheckMarkPainter(
                  progress: _checkAnimation.value,
                  color: AppTheme.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for animated check mark
class _CheckMarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckMarkPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Check mark points
    final p1 = Offset(size.width * 0.25, size.height * 0.5);
    final p2 = Offset(size.width * 0.45, size.height * 0.7);
    final p3 = Offset(size.width * 0.75, size.height * 0.3);

    if (progress < 0.5) {
      // Draw first part of check
      final t = progress * 2;
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
    } else {
      // Draw complete first part
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);

      // Draw second part
      final t = (progress - 0.5) * 2;
      path.lineTo(
        p2.dx + (p3.dx - p2.dx) * t,
        p2.dy + (p3.dy - p2.dy) * t,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckMarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
