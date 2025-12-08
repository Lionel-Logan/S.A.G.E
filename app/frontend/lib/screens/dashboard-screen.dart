import 'package:flutter/material.dart';
import '../models/glass-status.dart';
import '../theme/app-theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/glass-status-card.dart';
import '../widgets/quick-access-card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _sidebarOpen = false;
  late GlassStatus _glassStatus;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _glassStatus = GlassStatus(
      status: ConnectionStatus.connected,
      batteryLevel: 85,
    );
    
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
      color: AppTheme.cyan,
      onTap: () => print('Translation tapped'),
    ),
    QuickAccessItem(
      icon: Icons.face_rounded,
      label: 'Face Recognition',
      color: AppTheme.purple,
      onTap: () => print('Face Recognition tapped'),
    ),
    QuickAccessItem(
      icon: Icons.remove_red_eye_rounded,
      label: 'Object Detection',
      color: AppTheme.yellow,
      onTap: () => print('Object Detection tapped'),
    ),
    QuickAccessItem(
      icon: Icons.mic_rounded,
      label: 'Voice Assistant',
      color: AppTheme.green,
      onTap: () => print('Voice Assistant tapped'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Calculate opacity based on scroll
    final heroOpacity = (1 - (_scrollOffset / 300)).clamp(0.0, 1.0);
    final contentOpacity = (_scrollOffset / 200).clamp(0.0, 1.0);

    return Scaffold(
      body: Stack(
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    const SizedBox(height: 16),
                    
                    // Hero Section - Glass Status
                    AnimatedOpacity(
                      opacity: heroOpacity,
                      duration: const Duration(milliseconds: 300),
                      child: GlassStatusCard(
                        status: _glassStatus,
                        onToggle: _toggleGlassStatus,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Quick Access Section
                    AnimatedOpacity(
                      opacity: contentOpacity,
                      duration: const Duration(milliseconds: 500),
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
                          QuickAccessGrid(items: _quickAccessItems),
                        ],
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
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          
          // Sidebar
          AppSidebar(
            isOpen: _sidebarOpen,
            onClose: () => setState(() => _sidebarOpen = false),
            onNavigate: (route) {
              print('Navigate to: $route');
              setState(() => _sidebarOpen = false);
            },
          ),
        ],
      ),
    );
  }
}