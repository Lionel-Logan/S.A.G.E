import 'package:flutter/material.dart';
import '../models/setting_item.dart';
import '../theme/app-theme.dart';

class SettingTile extends StatefulWidget {
  final SettingItem item;
  final int index;

  const SettingTile({
    super.key,
    required this.item,
    required this.index,
  });

  @override
  State<SettingTile> createState() => _SettingTileState();
}

class _SettingTileState extends State<SettingTile>
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
      duration: const Duration(milliseconds: 300), // Faster fade-in
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.gray900,
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.gray800,
            ),
            child: Icon(
              widget.item.icon,
              size: 24,
              color: widget.item.color, // Restored color styling
            ),
          ),
          const SizedBox(width: 16),
          
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppTheme.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.item.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: AppTheme.gray500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Control based on type
          _buildControl(),
        ],
      ),
    );
  }

  Widget _buildControl() {
    switch (widget.item.type) {
      case SettingType.toggle:
        return Switch(
          value: widget.item.value ?? false,
          onChanged: widget.item.onToggle,
          activeColor: AppTheme.cyan,
          inactiveThumbColor: AppTheme.gray700,
          inactiveTrackColor: AppTheme.gray800,
        );
      
      case SettingType.navigation:
        return IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: widget.item.onNavigate,
          color: AppTheme.gray500,
        );
      
      case SettingType.dropdown:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: AppTheme.gray800,
          ),
          child: DropdownButton<String>(
            value: widget.item.selectedValue,
            items: widget.item.options?.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(
                  option,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null && widget.item.onDropdownChanged != null) {
                widget.item.onDropdownChanged!(value);
              }
            },
            underline: const SizedBox(),
            dropdownColor: AppTheme.gray800,
            icon: const Icon(Icons.expand_more, size: 18),
            style: const TextStyle(color: AppTheme.white),
          ),
        );
      
      case SettingType.slider:
        return const SizedBox.shrink();
    }
  }
}

// Special tile for slider settings (FIXED)
class SettingSliderTile extends StatefulWidget {
  final SettingItem item;
  final int index;

  const SettingSliderTile({
    super.key,
    required this.item,
    required this.index,
  });

  @override
  State<SettingSliderTile> createState() => _SettingSliderTileState();
}

class _SettingSliderTileState extends State<SettingSliderTile>
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
      duration: const Duration(milliseconds: 300), // Faster fade-in
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.gray900,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.gray800,
                ),
                child: Icon(
                  widget.item.icon,
                  size: 24,
                  color: widget.item.color, // Restored color styling
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppTheme.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.cyan,
              inactiveTrackColor: AppTheme.gray800,
              thumbColor: AppTheme.cyan,
              overlayColor: AppTheme.cyan.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: widget.item.sliderValue ?? 0.5,
              min: widget.item.sliderMin ?? 0.0,
              max: widget.item.sliderMax ?? 1.0,
              onChanged: widget.item.onSliderChanged,
            ),
          ),
        ],
      ),
    );
  }
}