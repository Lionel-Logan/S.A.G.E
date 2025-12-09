import 'package:flutter/material.dart';
import '../models/glass-status.dart';
import '../theme/app-theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/glass-status-card.dart';
import '../widgets/quick-access-card.dart';

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
      status: ConnectionStatus.connected,
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
      color: AppTheme.cyan, // Restored vibrant color for Translation
      onTap: () => print('Translation tapped'),
    ),
    QuickAccessItem(
      icon: Icons.face_rounded,
      label: 'Face Recognition',
      description: 'Identify and analyze faces',
      color: AppTheme.purple, // Restored vibrant color for Face Recognition
      onTap: () => print('Face Recognition tapped'),
    ),
    QuickAccessItem(
      icon: Icons.remove_red_eye_rounded,
      label: 'Object Detection',
      description: 'Detect objects in your environment',
      color: AppTheme.yellow, // Restored vibrant color for Object Detection
      onTap: () => print('Object Detection tapped'),
    ),
    QuickAccessItem(
      icon: Icons.mic_rounded,
      label: 'Voice Assistant',
      description: 'Control with voice commands',
      color: AppTheme.green, // Restored vibrant color for Voice Assistant
      onTap: () => print('Voice Assistant tapped'),
    ),
  ];

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