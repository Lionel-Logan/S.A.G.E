import 'package:flutter/material.dart';

enum SettingType { toggle, dropdown, navigation, slider }

class SettingCategory {
  final String title;
  final String? description;
  final List<SettingItem> items;

  SettingCategory({
    required this.title,
    this.description,
    required this.items,
  });
}

class SettingItem {
  final String title;
  final String description;
  final IconData icon;
  final SettingType type;
  
  // For toggle settings
  final bool? value;
  final Function(bool)? onToggle;
  
  // For dropdown settings
  final String? selectedValue;
  final List<String>? options;
  final Function(String)? onDropdownChanged;
  
  // For navigation settings
  final VoidCallback? onNavigate;
  
  // For slider settings
  final double? sliderValue;
  final double? sliderMin;
  final double? sliderMax;
  final Function(double)? onSliderChanged;
  final Color color; // Added color property

  SettingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.type,
    this.value,
    this.onToggle,
    this.selectedValue,
    this.options,
    this.onDropdownChanged,
    this.onNavigate,
    this.sliderValue,
    this.sliderMin,
    this.sliderMax,
    this.onSliderChanged,
    this.color = Colors.blue, // Default color
  });
}