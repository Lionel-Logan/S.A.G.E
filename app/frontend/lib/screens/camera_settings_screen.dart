import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app-theme.dart';
import '../widgets/sidebar.dart';
import '../services/bluetooth_audio_service.dart';
import '../services/api_service.dart';

class CameraSettingsScreen extends StatefulWidget {
  final Function(String) onNavigate;
  final String currentRoute;

  const CameraSettingsScreen({
    super.key,
    required this.onNavigate,
    required this.currentRoute,
  });

  @override
  State<CameraSettingsScreen> createState() => _CameraSettingsScreenState();
}

class _CameraSettingsScreenState extends State<CameraSettingsScreen> 
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  
  // Camera General Info
  final String _cameraType = 'Pi Camera OV5647';
  final String _cameraMaxQuality = '5 MP';
  
  // Photo Settings (from API)
  String _photoResolution = '1920x1080';
  double _shutterSpeed = 0.0; // 0 = auto
  int _iso = 0; // 0 = auto
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _sharpness = 1.0;
  
  // Video Settings (from API)
  int _maxDuration = 120;
  int _lastVideosStored = 5;
  
  // Resolution presets
  final List<String> _resolutionPresets = [
    '640x480',    // 480p
    '1280x720',   // 720p
    '1920x1080',  // 1080p
    '2592x1944',  // 5MP
  ];
  
  // Stream preview
  String? _streamUrl;
  bool _isStreaming = false;
  StreamSubscription<Uint8List>? _streamSubscription;
  Uint8List? _currentFrame;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = true;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    
    // Clear cached Pi server URL to trigger fresh discovery
    BluetoothAudioService.clearCache();
    
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
    _autoSaveTimer?.cancel();
    _streamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      // Get camera configuration from Pi server
      final piServerUrl = await BluetoothAudioService.getPiServerUrl();
      final response = await http.get(
        Uri.parse('$piServerUrl/camera/config'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final config = json.decode(response.body);
        setState(() {
          // Parse resolution string like "1920x1080"
          final resolution = config['photo_resolution'] ?? '1920x1080';
          _photoResolution = resolution is List ? '${resolution[0]}x${resolution[1]}' : resolution;
          
          _shutterSpeed = (config['photo_shutter_speed'] ?? 0.0).toDouble();
          _iso = config['photo_iso'] ?? 0;
          _brightness = (config['photo_brightness'] ?? 0.0).toDouble();
          _contrast = (config['photo_contrast'] ?? 1.0).toDouble();
          _sharpness = (config['photo_sharpness'] ?? 1.0).toDouble();
          _maxDuration = config['video_max_duration'] ?? 120;
          _lastVideosStored = config['last_videos_stored'] ?? 5;
          _isLoading = false;
        });
        
        // Initialize stream URL
        _streamUrl = '$piServerUrl/camera/stream';
      }
    } catch (e) {
      print('Error loading camera settings: $e');
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load camera settings. Using defaults.');
    }
  }

  Future<void> _saveSettings() async {
    try {
      // Parse resolution string to list [width, height]
      final parts = _photoResolution.split('x');
      final width = int.parse(parts[0]);
      final height = int.parse(parts[1]);
      
      final config = {
        'photo_resolution': [width, height],
        'photo_shutter_speed': _shutterSpeed,
        'photo_iso': _iso,
        'photo_brightness': _brightness,
        'photo_contrast': _contrast,
        'photo_sharpness': _sharpness,
        'video_max_duration': _maxDuration,
        'last_videos_stored': _lastVideosStored,
      };
      
      final piServerUrl = await BluetoothAudioService.getPiServerUrl();
      final response = await http.put(
        Uri.parse('$piServerUrl/camera/config'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(config),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode != 200) {
        _showError('Failed to save camera settings.');
      }
    } catch (e) {
      print('Error saving camera settings: $e');
      _showError('Failed to save camera settings.');
    }
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveSettings();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
      ),
    );
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
          'Camera Settings',
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
        _buildSectionHeader('GENERAL', 'Hardware information'),
        const SizedBox(height: 16),
        _buildGeneralSettings(),
        
        const SizedBox(height: 40),
        
        // Photo Section
        _buildSectionHeader('PHOTO', 'Capture settings with live preview'),
        const SizedBox(height: 16),
        _buildPhotoSettings(),
        
        const SizedBox(height: 40),
        
        // Video Section
        _buildSectionHeader('VIDEO', 'Recording configuration'),
        const SizedBox(height: 16),
        _buildVideoSettings(),
        
        const SizedBox(height: 40),
        
        // Reset button
        _buildResetButton(),
        
        const SizedBox(height: 24),
      ],
    );
  }
  
  Widget _buildResetButton() {
    return Center(
      child: OutlinedButton.icon(
        onPressed: _resetToDefaults,
        icon: Icon(Icons.refresh, color: Colors.red),
        label: Text(
          'Reset to Defaults',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
    );
  }
  
  Future<void> _resetToDefaults() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.gray900,
        title: Text(
          'Reset to Defaults?',
          style: TextStyle(color: AppTheme.white),
        ),
        content: Text(
          'This will reset all camera settings to their default values.',
          style: TextStyle(color: AppTheme.gray500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.gray500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final result = await ApiService.resetCameraSettings();
      
      if (result['success'] == true) {
        // Reload settings from server
        await _loadSettings();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Camera settings reset to defaults'),
              backgroundColor: AppTheme.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to reset settings: $e');
      }
    }
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
        children: [
          _buildInfoRow('Camera Type', _cameraType, Icons.camera_outlined),
          const SizedBox(height: 16),
          Divider(color: AppTheme.gray800, height: 1),
          const SizedBox(height: 16),
          _buildInfoRow('Max Quality', _cameraMaxQuality, Icons.high_quality_outlined),
          const SizedBox(height: 16),
          Divider(color: AppTheme.gray800, height: 1),
          const SizedBox(height: 16),
          _buildResolutionPresets(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.cyan, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.gray500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.white,
          ),
        ),
      ],
    );
  }

  Widget _buildResolutionPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.aspect_ratio_outlined, color: AppTheme.cyan, size: 20),
            const SizedBox(width: 12),
            Text(
              'Resolution Presets',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _resolutionPresets.map((resolution) {
            final isSelected = _photoResolution == resolution;
            String label;
            switch (resolution) {
              case '640x480':
                label = '480p';
                break;
              case '1280x720':
                label = '720p';
                break;
              case '1920x1080':
                label = '1080p';
                break;
              case '2592x1944':
                label = '5MP';
                break;
              default:
                label = resolution;
            }
            
            return GestureDetector(
              onTap: () {
                setState(() => _photoResolution = resolution);
                _scheduleAutoSave();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.cyan.withOpacity(0.1) : AppTheme.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppTheme.cyan : AppTheme.gray800,
                    width: 2,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.cyan : AppTheme.gray500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPhotoSettings() {
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
          // Live Preview
          _buildLivePreview(),
          
          const SizedBox(height: 24),
          Divider(color: AppTheme.gray800, height: 1),
          const SizedBox(height: 24),
          
          // Shutter Speed
          _buildSliderSetting(
            icon: Icons.shutter_speed_outlined,
            label: 'Shutter Speed',
            value: _shutterSpeed,
            unit: ' ms',
            min: 0.0,
            max: 1000.0,
            divisions: 20,
            displayValue: _shutterSpeed == 0.0 ? 'Auto' : '${_shutterSpeed.toInt()} ms',
            onChanged: (value) {
              setState(() => _shutterSpeed = value);
              _scheduleAutoSave();
            },
            color: AppTheme.cyan,
          ),
          
          const SizedBox(height: 24),
          Divider(color: AppTheme.gray800, height: 1),
          const SizedBox(height: 24),
          
          // ISO
          _buildSliderSetting(
            icon: Icons.iso_outlined,
            label: 'ISO',
            value: _iso.toDouble(),
            unit: '',
            min: 0,
            max: 1600,
            divisions: 16,
            displayValue: _iso == 0 ? 'Auto' : _iso.toString(),
            onChanged: (value) {
              setState(() => _iso = value.toInt());
              _scheduleAutoSave();
            },
            color: AppTheme.cyan,
          ),
          
          const SizedBox(height: 24),
          Divider(color: AppTheme.gray800, height: 1),
          const SizedBox(height: 24),
          
          // Brightness
          _buildSliderSetting(
            icon: Icons.brightness_6_outlined,
            label: 'Brightness',
            value: _brightness,
            unit: '',
            min: -1.0,
            max: 1.0,
            divisions: 20,
            displayValue: _brightness.toStringAsFixed(2),
            onChanged: (value) {
              setState(() => _brightness = value);
              _scheduleAutoSave();
            },
            color: AppTheme.cyan,
          ),
          
          const SizedBox(height: 24),
          Divider(color: AppTheme.gray800, height: 1),
          const SizedBox(height: 24),
          
          // Contrast
          _buildSliderSetting(
            icon: Icons.contrast_outlined,
            label: 'Contrast',
            value: _contrast,
            unit: '',
            min: 0.0,
            max: 2.0,
            divisions: 20,
            displayValue: _contrast.toStringAsFixed(2),
            onChanged: (value) {
              setState(() => _contrast = value);
              _scheduleAutoSave();
            },
            color: AppTheme.cyan,
          ),
          
          const SizedBox(height: 24),
          Divider(color: AppTheme.gray800, height: 1),
          const SizedBox(height: 24),
          
          // Sharpness
          _buildSliderSetting(
            icon: Icons.auto_fix_high_outlined,
            label: 'Sharpness',
            value: _sharpness,
            unit: '',
            min: 0.0,
            max: 2.0,
            divisions: 20,
            displayValue: _sharpness.toStringAsFixed(2),
            onChanged: (value) {
              setState(() => _sharpness = value);
              _scheduleAutoSave();
            },
            color: AppTheme.cyan,
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.visibility_outlined, color: AppTheme.cyan, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Live Preview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.white,
                ),
              ),
            ),
            // Toggle streaming
            GestureDetector(
              onTap: () {
                setState(() => _isStreaming = !_isStreaming);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isStreaming 
                      ? AppTheme.cyan.withOpacity(0.1) 
                      : AppTheme.gray800,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isStreaming ? AppTheme.cyan : AppTheme.gray700,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isStreaming ? Icons.videocam : Icons.videocam_off,
                      color: _isStreaming ? AppTheme.cyan : AppTheme.gray500,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isStreaming ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isStreaming ? AppTheme.cyan : AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Preview container
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _isStreaming && _streamUrl != null
                ? _MjpegStreamWidget(
                    streamUrl: _streamUrl!,
                    onError: () {
                      if (mounted) {
                        setState(() => _isStreaming = false);
                        _showError('Failed to load camera stream');
                      }
                    },
                  )
                : Container(
                    color: AppTheme.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off,
                            color: AppTheme.gray500,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Camera stream stopped',
                            style: TextStyle(
                              color: AppTheme.gray500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Info text
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
                  'Toggle ON to see real-time camera feed. Adjust settings and see changes instantly.',
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
    );
  }

  Widget _buildVideoSettings() {
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
          // Max Duration
          _buildSliderSetting(
            icon: Icons.timer_outlined,
            label: 'Max Duration',
            value: _maxDuration.toDouble(),
            unit: ' s',
            min: 10,
            max: 300,
            divisions: 29,
            onChanged: (value) {
              setState(() => _maxDuration = value.toInt());
              _scheduleAutoSave();
            },
            color: AppTheme.cyan,
          ),
          
          const SizedBox(height: 24),
          Divider(color: AppTheme.gray800, height: 1),
          const SizedBox(height: 24),
          
          // Last Videos Stored
          _buildSliderSetting(
            icon: Icons.video_library_outlined,
            label: 'Videos Stored',
            value: _lastVideosStored.toDouble(),
            unit: ' videos',
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (value) {
              setState(() => _lastVideosStored = value.toInt());
              _scheduleAutoSave();
            },
            color: AppTheme.cyan,
          ),
        ],
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
}

/// Custom widget to display MJPEG stream from Pi Camera
class _MjpegStreamWidget extends StatefulWidget {
  final String streamUrl;
  final VoidCallback onError;

  const _MjpegStreamWidget({
    required this.streamUrl,
    required this.onError,
  });

  @override
  State<_MjpegStreamWidget> createState() => _MjpegStreamWidgetState();
}

class _MjpegStreamWidgetState extends State<_MjpegStreamWidget> {
  Uint8List? _currentFrame;
  bool _isLoading = true;
  bool _hasError = false;
  http.Client? _client;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _startStream() async {
    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.streamUrl));
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception('Stream returned ${response.statusCode}');
      }

      // MJPEG boundary parsing
      List<int> buffer = [];
      const boundary = [0xFF, 0xD8]; // JPEG start marker
      bool inJpeg = false;

      _subscription = response.stream.listen(
        (chunk) {
          for (var byte in chunk) {
            buffer.add(byte);

            // Look for JPEG start marker
            if (buffer.length >= 2) {
              if (buffer[buffer.length - 2] == 0xFF && buffer[buffer.length - 1] == 0xD8) {
                if (inJpeg && buffer.length > 2) {
                  // We found a new JPEG start, so previous frame is complete
                  final frameData = Uint8List.fromList(buffer.sublist(0, buffer.length - 2));
                  if (mounted) {
                    setState(() {
                      _currentFrame = frameData;
                      _isLoading = false;
                      _hasError = false;
                    });
                  }
                  buffer = [0xFF, 0xD8]; // Start new buffer with current marker
                } else {
                  inJpeg = true;
                }
              }
            }

            // Prevent buffer from growing too large
            if (buffer.length > 5 * 1024 * 1024) {
              buffer.clear();
              inJpeg = false;
            }
          }
        },
        onError: (error) {
          print('MJPEG stream error: $error');
          if (mounted) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
            widget.onError();
          }
        },
        onDone: () {
          print('MJPEG stream ended');
          if (mounted) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      print('Failed to start MJPEG stream: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        widget.onError();
      }
    }
  }

  void _stopStream() {
    _subscription?.cancel();
    _client?.close();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: AppTheme.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: AppTheme.gray500,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load stream',
                style: TextStyle(
                  color: AppTheme.gray500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading || _currentFrame == null) {
      return Container(
        color: AppTheme.black,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyan),
          ),
        ),
      );
    }

    return Image.memory(
      _currentFrame!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
  }
}
