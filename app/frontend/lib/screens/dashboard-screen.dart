import 'package:flutter/material.dart';
import '../models/glass-status.dart';
import '../theme/app-theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/glass-status-card.dart';
import '../widgets/quick-access-card.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final Function(String) onNavigate;
  final String currentRoute;

  const DashboardScreen({
    super.key,
    required this.onNavigate,
    required this.currentRoute,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  bool _sidebarOpen = false;
  late GlassStatus _glassStatus;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  
  // Animation controllers for entrance
  late AnimationController _heroAnimController;
  late AnimationController _quickAccessAnimController;
  
  late Animation<double> _heroOpacityAnim;
  late Animation<Offset> _heroSlideAnim;
  late Animation<double> _heroScaleAnim;

  @override
  void initState() {
    super.initState();
    _glassStatus = GlassStatus(
      status: ConnectionStatus.searching,
      batteryLevel: 85,
    );
    
    _scrollController.addListener(_onScroll);
    
    // Hero section entrance animation
    _heroAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _heroOpacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _heroAnimController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _heroSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _heroAnimController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    
    _heroScaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _heroAnimController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    
    // Quick access entrance animation
    _quickAccessAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    // Start animations
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _heroAnimController.forward();
        _quickAccessAnimController.forward();
      }
    });
    
    // Check Pi server connection and pairing status
    _checkPiConnection();
  }
  
  Future<void> _checkPiConnection() async {
    try {
      final identity = await ApiService.getIdentity();
      setState(() {
        _glassStatus = GlassStatus(
          status: identity['paired'] == true 
              ? ConnectionStatus.connected 
              : ConnectionStatus.disconnected,
          batteryLevel: 85,
        );
      });
      
      // If not paired, initiate pairing
      if (identity['paired'] == false) {
        await _initiatePairing();
      }
    } catch (e) {
      print('Error connecting to Pi: $e');
      setState(() {
        _glassStatus = GlassStatus(
          status: ConnectionStatus.disconnected,
          batteryLevel: 0,
        );
      });
    }
  }
  
  Future<void> _initiatePairing() async {
    try {
      // Request pairing
      await ApiService.requestPairing(
        appId: 'sage-flutter-app-001',
        appName: 'SAGE Flutter App',
      );
      
      // Auto-confirm pairing for testing
      await ApiService.confirmPairing(
        appId: 'sage-flutter-app-001',
        confirm: true,
      );
      
      // Update status
      setState(() {
        _glassStatus = GlassStatus(
          status: ConnectionStatus.connected,
          batteryLevel: 85,
        );
      });
      
      print('✅ Paired successfully!');
    } catch (e) {
      print('❌ Pairing failed: $e');
    }
  }

  void _onScroll() {
    final newOffset = _scrollController.offset;
    if ((newOffset - _scrollOffset).abs() > 1) {
      setState(() {
        _scrollOffset = newOffset;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _heroAnimController.dispose();
    _quickAccessAnimController.dispose();
    super.dispose();
  }

  void _toggleGlassStatus() {
    setState(() {
      _glassStatus = GlassStatus(
        status: _glassStatus.isConnected 
            ? ConnectionStatus.disconnected 
            : ConnectionStatus.connected,
      );
    });
  }

  List<QuickAccessItem> get _quickAccessItems => [
    QuickAccessItem(
      icon: Icons.translate_rounded,
      label: 'Translation',
      description: 'Translate text in real-time',
      color: AppTheme.cyan,
      onTap: _handleTranslation,
    ),
    QuickAccessItem(
      icon: Icons.face_rounded,
      label: 'Face Recognition',
      description: 'Identify and analyze faces',
      color: AppTheme.purple,
      onTap: _handleFaceRecognition,
    ),
    QuickAccessItem(
      icon: Icons.remove_red_eye_rounded,
      label: 'Object Detection',
      description: 'Detect objects in your environment',
      color: AppTheme.yellow,
      onTap: _handleObjectDetection,
    ),
    QuickAccessItem(
      icon: Icons.mic_rounded,
      label: 'Voice Assistant',
      description: 'Control with voice commands',
      color: AppTheme.green,
      onTap: _handleVoiceAssistant,
    ),
  ];
  
  Future<void> _handleTranslation() async {
    print('🌍 Translation started...');
    try {
      // Capture image from Pi
      final camera = await ApiService.captureCamera();
      final imageBase64 = camera['frame'];
      
      // Send to backend for translation
      final result = await ApiService.translateImage(imageBase64: imageBase64);
      
      final translated = result['translation_result']['translated_text'];
      
      // Display on Pi HUD
      await ApiService.displayHud(text: translated);
      
      print('✅ Translation: $translated');
    } catch (e) {
      print('❌ Translation failed: $e');
    }
  }
  
  Future<void> _handleFaceRecognition() async {
    print('👤 Face recognition started...');
    try {
      // Capture image from Pi
      final camera = await ApiService.captureCamera();
      final imageBase64 = camera['frame'];
      
      // Send to backend for face recognition
      final result = await ApiService.recognizeFaces(imageBase64: imageBase64);
      
      final facesDetected = result['faces_detected'];
      if (facesDetected > 0) {
        final names = (result['faces'] as List)
            .map((f) => f['person_name'])
            .join(', ');
        
        // Display on Pi HUD
        await ApiService.displayHud(text: 'Hello, $names!');
        
        print('✅ Faces detected: $names');
      } else {
        await ApiService.displayHud(text: 'No faces detected');
        print('ℹ️ No faces detected');
      }
    } catch (e) {
      print('❌ Face recognition failed: $e');
    }
  }
  
  Future<void> _handleObjectDetection() async {
    print('🔍 Object detection started...');
    try {
      // Capture image from Pi
      final camera = await ApiService.captureCamera();
      final imageBase64 = camera['frame'];
      
      // Send to backend for object detection
      final result = await ApiService.detectObjects(imageBase64: imageBase64);
      
      final objectsDetected = result['objects_detected'];
      if (objectsDetected > 0) {
        final objects = (result['objects'] as List)
            .map((o) => o['label'])
            .take(3)
            .join(', ');
        
        // Display on Pi HUD
        await ApiService.displayHud(text: 'Detected: $objects');
        
        print('✅ Objects: $objects');
      } else {
        await ApiService.displayHud(text: 'No objects detected');
        print('ℹ️ No objects detected');
      }
    } catch (e) {
      print('❌ Object detection failed: $e');
    }
  }
  
  Future<void> _handleVoiceAssistant() async {
    print('🎤 Voice assistant started...');
    try {
      // For now, use a test query
      const query = "What's the weather today?";
      
      // Send to backend
      final result = await ApiService.voiceAssistantQuery(query);
      
      final response = result['response_text'];
      
      // Display on Pi HUD
      await ApiService.displayHud(text: response);
      
      // Speak through Pi
      await ApiService.speak(response);
      
      print('✅ Response: $response');
    } catch (e) {
      print('❌ Voice assistant failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Smooth scroll-based opacity calculations
    final heroScrollOpacity = (1 - (_scrollOffset / 400)).clamp(0.0, 1.0);
    final quickAccessScrollOpacity = (0.3 + (_scrollOffset / 300) * 0.7).clamp(0.3, 1.0);
    final quickAccessTranslate = ((_scrollOffset / 300) * -20).clamp(-20.0, 0.0);

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
            // Main Content
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
                            'S.A.G.E',
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
                  child: ListView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      const SizedBox(height: 16),
                      
                      // Hero Section - Glass Status with entrance animation
                      FadeTransition(
                        opacity: _heroOpacityAnim,
                        child: SlideTransition(
                          position: _heroSlideAnim,
                          child: ScaleTransition(
                            scale: _heroScaleAnim,
                            child: Opacity(
                              opacity: heroScrollOpacity,
                              child: GlassStatusCard(
                                status: _glassStatus,
                                onToggle: _toggleGlassStatus,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Quick Access Section with smooth scroll parallax
                      Transform.translate(
                        offset: Offset(0, quickAccessTranslate),
                        child: Opacity(
                          opacity: quickAccessScrollOpacity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QUICK ACCESS',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                  color: AppTheme.gray500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              QuickAccessList(
                                items: _quickAccessItems,
                                animationController: _quickAccessAnimController,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Extra space for scroll effect
                      const SizedBox(height: 400),
                    ],
                  ),
                ),
              ],
            ),
            
            // Sidebar Overlay
            if (_sidebarOpen)
              GestureDetector(
                onTap: () => setState(() => _sidebarOpen = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
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