import 'package:flutter/material.dart';
import '../theme/app-theme.dart';

class MicrophoneSettingsScreen extends StatefulWidget {
  final Function(String) onNavigate;
  final String currentRoute;

  const MicrophoneSettingsScreen({
    super.key,
    required this.onNavigate,
    required this.currentRoute,
  });

  @override
  State<MicrophoneSettingsScreen> createState() => _MicrophoneSettingsScreenState();
}

class _MicrophoneSettingsScreenState extends State<MicrophoneSettingsScreen> 
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  
  // Microphone Settings
  double _inputVolume = 1.0;
  String _audioInput = 'Default';
  bool _noiseReduction = true;
  double _sensitivity = 0.8;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = false;

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
    
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Microphone Settings',
          style: TextStyle(
            color: AppTheme.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isLoading ? _buildLoadingView() : _buildContent(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyan),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        // General Section
        _buildSectionHeader('GENERAL', 'Microphone information and settings'),
        const SizedBox(height: 16),
        _buildGeneralSettings(),
        
        const SizedBox(height: 40),
        
        // Audio Section
        _buildSectionHeader('AUDIO', 'Input configuration'),
        const SizedBox(height: 16),
        _buildAudioSettings(),
        
        const SizedBox(height: 40),
        
        // Advanced Section
        _buildSectionHeader('ADVANCED', 'Audio processing settings'),
        const SizedBox(height: 16),
        _buildAdvancedSettings(),
        
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.cyan,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.gray500,
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Device', 'USB Microphone'),
          const SizedBox(height: 12),
          _buildInfoRow('Status', 'Connected'),
          const SizedBox(height: 12),
          _buildInfoRow('Sample Rate', '48 kHz'),
          const SizedBox(height: 12),
          _buildInfoRow('Channels', 'Mono'),
        ],
      ),
    );
  }

  Widget _buildAudioSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSliderSetting(
            icon: Icons.volume_up_outlined,
            label: 'Input Volume',
            value: _inputVolume,
            unit: '%',
            min: 0.0,
            max: 1.0,
            divisions: 10,
            displayValue: '${(_inputVolume * 100).toStringAsFixed(0)}%',
            onChanged: (value) {
              setState(() => _inputVolume = value);
            },
            color: AppTheme.cyan,
          ),
          
          const SizedBox(height: 24),
          Divider(color: AppTheme.gray800, height: 1),
          const SizedBox(height: 24),
          
          _buildDropdownSetting(
            icon: Icons.devices_outlined,
            label: 'Audio Input',
            value: _audioInput,
            options: ['Default', 'USB Microphone', 'Built-in Mic'],
            onChanged: (value) {
              setState(() => _audioInput = value);
            },
            color: AppTheme.cyan,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToggleSetting(
            icon: Icons.mic_off_outlined,
            label: 'Noise Reduction',
            value: _noiseReduction,
            onChanged: (value) {
              setState(() => _noiseReduction = value);
            },
            color: AppTheme.cyan,
          ),
          
          const SizedBox(height: 24),
          Divider(color: AppTheme.gray800, height: 1),
          const SizedBox(height: 24),
          
          _buildSliderSetting(
            icon: Icons.tune_outlined,
            label: 'Sensitivity',
            value: _sensitivity,
            unit: '',
            min: 0.0,
            max: 1.0,
            divisions: 10,
            displayValue: _sensitivity.toStringAsFixed(2),
            onChanged: (value) {
              setState(() => _sensitivity = value);
            },
            color: AppTheme.cyan,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.gray500,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSliderSetting({
    required IconData icon,
    required String label,
    required double value,
    required String unit,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required Function(double) onChanged,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.white,
                ),
              ),
            ),
            Text(
              displayValue,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: 8,
              elevation: 4,
            ),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: color,
            inactiveColor: AppTheme.gray800,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownSetting({
    required IconData icon,
    required String label,
    required String value,
    required List<String> options,
    required Function(String) onChanged,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.white,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.gray800,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: DropdownButton<String>(
            value: value,
            items: options
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: TextStyle(color: AppTheme.white)),
                    ))
                .toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
            dropdownColor: AppTheme.gray900,
            underline: Container(),
            icon: Icon(Icons.arrow_drop_down, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleSetting({
    required IconData icon,
    required String label,
    required bool value,
    required Function(bool) onChanged,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.white,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
          inactiveThumbColor: AppTheme.gray700,
          inactiveTrackColor: AppTheme.gray800,
        ),
      ],
    );
  }
}
