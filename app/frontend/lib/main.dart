import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app-theme.dart';
import 'screens/dashboard-screen.dart';
import 'screens/settings_screen.dart';
import 'screens/pairing_welcome_screen.dart';
import 'screens/pairing_mode_selection_screen.dart';
import 'screens/pairing_flow_screen.dart';
import 'services/storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(const SAGEApp());
}

class SAGEApp extends StatelessWidget {
  const SAGEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'S.A.G.E',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AppInitializer(),
      // Prevent route from being discarded on app resume
      navigatorObservers: [RoutePreserver()],
    );
  }
}

/// Route observer to preserve navigation state
class RoutePreserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
  }
}

/// Initializer to check pairing status and route accordingly
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _isPaired = false;

  @override
  void initState() {
    super.initState();
    _checkPairingStatus();
  }

  Future<void> _checkPairingStatus() async {
    // Check if device is already paired
    final isPaired = await StorageService.isPaired();
    
    setState(() {
      _isPaired = isPaired;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Show splash/loading screen
      return Scaffold(
        backgroundColor: AppTheme.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppTheme.cyan),
          ),
        ),
      );
    }

    if (_isPaired) {
      // Already paired - go to main app
      return const MainNavigator();
    } else {
      // Not paired - show pairing flow
      return const PairingNavigator();
    }
  }
}

/// Navigator for pairing flow
class PairingNavigator extends StatefulWidget {
  const PairingNavigator({super.key});

  @override
  State<PairingNavigator> createState() => _PairingNavigatorState();
}

class _PairingNavigatorState extends State<PairingNavigator> {
  int _currentStep = 0;
  bool _isAutoMode = true;

  void _goToModeSelection() {
    setState(() {
      _currentStep = 1;
    });
  }

  void _startPairing(bool isAutoMode) {
    setState(() {
      _isAutoMode = isAutoMode;
      _currentStep = 2;
    });
  }

  void _completePairing() {
    // Navigate to main app
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MainNavigator(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return PairingWelcomeScreen(onContinue: _goToModeSelection);
      case 1:
        return PairingModeSelectionScreen(onModeSelected: _startPairing);
      case 2:
        return PairingFlowScreen(
          isAutoMode: _isAutoMode,
          onComplete: _completePairing,
        );
      default:
        return PairingWelcomeScreen(onContinue: _goToModeSelection);
    }
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> with AutomaticKeepAliveClientMixin {
  String _currentRoute = 'home';
  
  // Keep screen alive
  @override
  bool get wantKeepAlive => true;
  
  // PageStorage to preserve scroll positions and state
  final PageStorageBucket _bucket = PageStorageBucket();

  void _handleNavigation(String route) {
    print('Navigation requested to: $route'); // Debug print
    if (route != _currentRoute) {
      setState(() {
        _currentRoute = route;
      });
      print('Navigation complete. Current route: $_currentRoute'); // Debug print
    }
  }

  Widget _getCurrentScreen() {
    print('Building screen for route: $_currentRoute'); // Debug print
    
    switch (_currentRoute) {
      case 'home':
        return DashboardScreen(
          key: const PageStorageKey('dashboard'),
          onNavigate: _handleNavigation,
          currentRoute: _currentRoute,
        );
      case 'settings':
        return SettingsScreen(
          key: const PageStorageKey('settings'),
          onNavigate: _handleNavigation,
          currentRoute: _currentRoute,
        );
      case 'account':
        // For now, navigate to settings when account is tapped
        return SettingsScreen(
          key: const PageStorageKey('settings'),
          onNavigate: _handleNavigation,
          currentRoute: 'settings',
        );
      default:
        return DashboardScreen(
          key: const PageStorageKey('dashboard'),
          onNavigate: _handleNavigation,
          currentRoute: _currentRoute,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return PageStorage(
      bucket: _bucket,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (child, animation) {
          // Fade transition
          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
            ),
          );
          
          // Slide transition
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
            ),
          );
          
          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          );
        },
        child: _getCurrentScreen(),
      ),
    );
  }
}