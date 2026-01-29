import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app-theme.dart';
import '../widgets/sidebar.dart';

class ObjectDetectionSettingsScreen extends StatefulWidget {
  final Function(String) onNavigate;
  final String currentRoute;

  const ObjectDetectionSettingsScreen({
    super.key,
    required this.onNavigate,
    required this.currentRoute,
  });

  @override
  State<ObjectDetectionSettingsScreen> createState() => _ObjectDetectionSettingsScreenState();
}

class _ObjectDetectionSettingsScreenState extends State<ObjectDetectionSettingsScreen> 
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  
  // Camera Settings
  double _intervalSeconds = 2.0;
  int _lastPhotosStored = 10;
  
  // Model Settings (boilerplate - will implement later)
  double _confidenceThreshold = 0.5;
  String _modelEfficiency = 'Best Quality'; // 'Best Quality' or 'Best Efficiency'
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = true;

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
    
    _loadSettings();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _intervalSeconds = prefs.getDouble('od_interval_seconds') ?? 2.0;
      _lastPhotosStored = prefs.getInt('od_last_photos') ?? 10;
      _confidenceThreshold = prefs.getDouble('od_confidence_threshold') ?? 0.5;
      _modelEfficiency = prefs.getString('od_model_efficiency') ?? 'Best Quality';
      _isLoading = false;
    });
  }

  Future<void> _saveIntervalSeconds(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('od_interval_seconds', value);
    setState(() => _intervalSeconds = value);
  }

  Future<void> _saveLastPhotos(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('od_last_photos', value);
    setState(() => _lastPhotosStored = value);
  }

  Future<void> _saveConfidenceThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('od_confidence_threshold', value);
    setState(() => _confidenceThreshold = value);
  }

  Future<void> _saveModelEfficiency(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('od_model_efficiency', value);
    setState(() => _modelEfficiency = value);
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
          onPressed: () => widget.onNavigate('settings'),
        ),
        title: Text(
          'Object Detection',
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
        // Camera Section
        _buildSectionHeader('CAMERA', 'Configure capture settings'),
        const SizedBox(height: 16),
        _buildCameraSettings(),
        
        const SizedBox(height: 40),
        
        // Model Section
        _buildSectionHeader('MODEL', 'Adjust detection parameters'),
        const SizedBox(height: 16),
        _buildModelSettings(),
        
        const SizedBox(height: 40),
        
        // Developer Info
        _buildSectionHeader('DEVELOPER', 'Model information'),
        const SizedBox(height: 16),
        _buildDeveloperInfo(),
        
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

  Widget _buildCameraSettings() {
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
          // Interval Seconds
          _buildSliderSetting(
            icon: Icons.timer_outlined,
            label: 'Snapshot Interval',
            value: _intervalSeconds,
            unit: 's',
            min: 0.5,
            max: 10.0,
            divisions: 19,
            onChanged: (value) => _saveIntervalSeconds(value),
            color: AppTheme.cyan,
          ),
          
          const SizedBox(height: 24),
          Divider(color: AppTheme.gray800, height: 1),
          const SizedBox(height: 24),
          
          // Last Photos Stored
          _buildSliderSetting(
            icon: Icons.photo_library_outlined,
            label: 'Photos Stored',
            value: _lastPhotosStored.toDouble(),
            unit: ' images',
            min: 5,
            max: 50,
            divisions: 9,
            onChanged: (value) => _saveLastPhotos(value.toInt()),
            color: AppTheme.cyan,
          ),
        ],
      ),
    );
  }

  Widget _buildModelSettings() {
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
          // Confidence Threshold
          _buildSliderSetting(
            icon: Icons.analytics_outlined,
            label: 'Confidence Threshold',
            value: _confidenceThreshold,
            unit: '',
            min: 0.1,
            max: 1.0,
            divisions: 9,
            displayValue: '${(_confidenceThreshold * 100).toInt()}%',
            onChanged: (value) => _saveConfidenceThreshold(value),
            color: AppTheme.cyan,
          ),
          
          const SizedBox(height: 24),
          Divider(color: AppTheme.gray800, height: 1),
          const SizedBox(height: 24),
          
          // Model Efficiency Toggle
          Row(
            children: [
              Icon(Icons.speed_outlined, color: AppTheme.cyan, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Model Efficiency',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildEfficiencyOption(
                  'Best Quality',
                  Icons.high_quality_outlined,
                  _modelEfficiency == 'Best Quality',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEfficiencyOption(
                  'Best Efficiency',
                  Icons.flash_on_outlined,
                  _modelEfficiency == 'Best Efficiency',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cyan.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cyan.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppTheme.cyan, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Best Quality mode provides more accurate results but takes longer to process. Best Efficiency is faster but may miss some detections.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.gray500,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEfficiencyOption(String label, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () => _saveModelEfficiency(label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.cyan.withOpacity(0.1) : AppTheme.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.cyan : AppTheme.gray800,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.cyan : AppTheme.gray500,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.cyan : AppTheme.gray500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
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
    required Function(double) onChanged,
    required Color color,
    String? displayValue,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                displayValue ?? '${value.toStringAsFixed(value < 10 ? 1 : 0)}$unit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDeveloperInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.cyan.withOpacity(0.15),
            AppTheme.purple.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: AppTheme.cyan,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ananya P',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.white,
                      ),
                    ),
                    Text(
                      'ML Developer',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.cyan,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          Divider(color: AppTheme.gray800, height: 1),
          const SizedBox(height: 20),
          
          _buildInfoRow('Model', 'YOLO v11', Icons.smart_toy_outlined),
          const SizedBox(height: 12),
          _buildInfoRow('Fine Tuned', 'Yes', Icons.tune_outlined),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.cyan, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.gray500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.white,
          ),
        ),
      ],
    );
  }
}
