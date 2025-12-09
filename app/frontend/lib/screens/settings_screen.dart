import 'package:flutter/material.dart';
import '../models/setting_item.dart';
import '../theme/app-theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/setting_tile.dart';
import '../widgets/setting_category_header.dart';

class SettingsScreen extends StatefulWidget {
  final Function(String) onNavigate;
  final String currentRoute;

  const SettingsScreen({
    super.key,
    required this.onNavigate,
    required this.currentRoute,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _sidebarOpen = false;
  final ScrollController _scrollController = ScrollController();
  
  // Boilerplate state management for settings
  bool _notificationsEnabled = true;
  bool _autoConnect = true;
  bool _voiceWakeEnabled = true;
  bool _hapticFeedback = true;
  String _translationLanguage = 'Spanish';
  String _hudBrightness = 'Auto';
  double _voiceSensitivity = 0.7;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<SettingCategory> get _categories => [
    SettingCategory(
      title: 'DEVICE & CONNECTION',
      description: 'Manage your SAGE glass connection and pairing',
      items: [
        SettingItem(
          title: 'Auto-Connect',
          description: 'Automatically connect to paired glass',
          icon: Icons.wifi_rounded,
          type: SettingType.toggle,
          value: _autoConnect,
          onToggle: (value) => setState(() => _autoConnect = value),
        ),
        SettingItem(
          title: 'Device Management',
          description: 'Manage paired devices and connections',
          icon: Icons.devices_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to device management'),
        ),
        SettingItem(
          title: 'Battery Optimization',
          description: 'Configure power saving settings',
          icon: Icons.battery_charging_full_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to battery settings'),
        ),
      ],
    ),
    SettingCategory(
      title: 'DISPLAY & HUD',
      description: 'Customize your heads-up display experience',
      items: [
        SettingItem(
          title: 'HUD Brightness',
          description: 'Adjust display brightness level',
          icon: Icons.brightness_6_rounded,
          type: SettingType.dropdown,
          selectedValue: _hudBrightness,
          options: ['Low', 'Medium', 'High', 'Auto'],
          onDropdownChanged: (value) => setState(() => _hudBrightness = value),
        ),
        SettingItem(
          title: 'Display Position',
          description: 'Adjust HUD text position and alignment',
          icon: Icons.crop_free_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to display position'),
        ),
        SettingItem(
          title: 'Text Size',
          description: 'Configure readable text size',
          icon: Icons.format_size_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to text size'),
        ),
      ],
    ),
    SettingCategory(
      title: 'VOICE & AUDIO',
      description: 'Voice assistant and audio settings',
      items: [
        SettingItem(
          title: 'Voice Wake Word',
          description: 'Enable "Hey Glass" wake word detection',
          icon: Icons.mic_rounded,
          type: SettingType.toggle,
          value: _voiceWakeEnabled,
          onToggle: (value) => setState(() => _voiceWakeEnabled = value),
        ),
        SettingItem(
          title: 'Voice Sensitivity',
          description: 'Adjust microphone sensitivity level',
          icon: Icons.tune_rounded,
          type: SettingType.slider,
          sliderValue: _voiceSensitivity,
          sliderMin: 0.0,
          sliderMax: 1.0,
          onSliderChanged: (value) => setState(() => _voiceSensitivity = value),
        ),
        SettingItem(
          title: 'Audio Output',
          description: 'Configure speaker and volume settings',
          icon: Icons.volume_up_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to audio settings'),
        ),
      ],
    ),
    SettingCategory(
      title: 'AI FEATURES',
      description: 'Configure AI-powered capabilities',
      items: [
        SettingItem(
          title: 'Translation Settings',
          description: 'Default translation language and preferences',
          icon: Icons.translate_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to translation settings'),
        ),
        SettingItem(
          title: 'Face Recognition',
          description: 'Manage known faces and privacy settings',
          icon: Icons.face_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to face recognition'),
        ),
        SettingItem(
          title: 'Object Detection',
          description: 'Configure detection sensitivity and filters',
          icon: Icons.remove_red_eye_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to object detection'),
        ),
        SettingItem(
          title: 'AI Model Quality',
          description: 'Balance between speed and accuracy',
          icon: Icons.psychology_rounded,
          type: SettingType.dropdown,
          selectedValue: 'Balanced',
          options: ['Fast', 'Balanced', 'Accurate'],
          onDropdownChanged: (value) => print('AI quality: $value'),
        ),
      ],
    ),
    SettingCategory(
      title: 'PRIVACY & SECURITY',
      description: 'Control your data and privacy settings',
      items: [
        SettingItem(
          title: 'Data Collection',
          description: 'Manage usage data and analytics',
          icon: Icons.analytics_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to data collection'),
        ),
        SettingItem(
          title: 'Camera Privacy',
          description: 'Control when camera can be used',
          icon: Icons.camera_alt_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to camera privacy'),
        ),
        SettingItem(
          title: 'Stored Data',
          description: 'View and manage cached data',
          icon: Icons.storage_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to stored data'),
        ),
      ],
    ),
    SettingCategory(
      title: 'NOTIFICATIONS',
      description: 'Manage alerts and notifications',
      items: [
        SettingItem(
          title: 'Enable Notifications',
          description: 'Receive alerts and updates',
          icon: Icons.notifications_rounded,
          type: SettingType.toggle,
          value: _notificationsEnabled,
          onToggle: (value) => setState(() => _notificationsEnabled = value),
        ),
        SettingItem(
          title: 'Notification Style',
          description: 'Choose how notifications appear',
          icon: Icons.style_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to notification style'),
        ),
        SettingItem(
          title: 'Haptic Feedback',
          description: 'Vibrate for important notifications',
          icon: Icons.vibration_rounded,
          type: SettingType.toggle,
          value: _hapticFeedback,
          onToggle: (value) => setState(() => _hapticFeedback = value),
        ),
      ],
    ),
    SettingCategory(
      title: 'ABOUT',
      description: 'App information and support',
      items: [
        SettingItem(
          title: 'Version',
          description: 'SAGE v1.0.0 (Build 001)',
          icon: Icons.info_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to version info'),
        ),
        SettingItem(
          title: 'Help & Support',
          description: 'Get help and contact support',
          icon: Icons.help_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to help'),
        ),
        SettingItem(
          title: 'Legal',
          description: 'Terms of service and privacy policy',
          icon: Icons.gavel_rounded,
          type: SettingType.navigation,
          onNavigate: () => print('Navigate to legal'),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    int itemIndex = 0;

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0 && !_sidebarOpen) {
            setState(() => _sidebarOpen = true);
          }
          if (details.primaryVelocity! < 0 && _sidebarOpen) {
            setState(() => _sidebarOpen = false);
          }
        },
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.black, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu_rounded),
                            onPressed: () => setState(() => _sidebarOpen = true),
                          ),
                          Text(
                            'SETTINGS',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemCount: _categories.length,
                    itemBuilder: (context, categoryIndex) {
                      final category = _categories[categoryIndex];
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Header
                          SettingCategoryHeader(
                            title: category.title,
                            description: category.description,
                            index: itemIndex++,
                          ),
                          
                          // Category Items
                          ...category.items.map((item) {
                            final currentIndex = itemIndex++;
                            
                            if (item.type == SettingType.slider) {
                              return SettingSliderTile(
                                item: item,
                                index: currentIndex,
                              );
                            }
                            
                            return SettingTile(
                              item: item,
                              index: currentIndex,
                            );
                          }).toList(),
                          
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),

            // Sidebar Overlay
            if (_sidebarOpen)
              GestureDetector(
                onTap: () => setState(() => _sidebarOpen = false),
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),

            // Sidebar
            AppSidebar(
              isOpen: _sidebarOpen,
              onClose: () => setState(() => _sidebarOpen = false),
              currentRoute: widget.currentRoute,
              onNavigate: (route) {
                widget.onNavigate(route);
                setState(() => _sidebarOpen = false);
              },
            ),
          ],
        ),
      ),
    );
  }
}