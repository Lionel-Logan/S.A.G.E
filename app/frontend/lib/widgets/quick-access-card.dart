import 'package:flutter/material.dart';
import '../theme/app-theme.dart';

class QuickAccessItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  QuickAccessItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class QuickAccessGrid extends StatelessWidget {
  final List<QuickAccessItem> items;

  const QuickAccessGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return QuickAccessCard(item: items[index]);
      },
    );
  }
}

class QuickAccessCard extends StatefulWidget {
  final QuickAccessItem item;

  const QuickAccessCard({super.key, required this.item});

  @override
  State<QuickAccessCard> createState() => _QuickAccessCardState();
}

class _QuickAccessCardState extends State<QuickAccessCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      onTap: widget.item.onTap,
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [AppTheme.gray900, AppTheme.black],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: _isHovered ? AppTheme.gray700 : AppTheme.gray800,
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.item.color.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.item.icon,
                size: 32,
                color: widget.item.color,
              ),
              const SizedBox(height: 12),
              Text(
                widget.item.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
