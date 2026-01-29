import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'theme/app-theme.dart';
import 'screens/dashboard-screen.dart';
import 'screens/settings_screen.dart';
import 'screens/pairing_welcome_screen.dart';
import 'screens/pairing_flow_screen.dart';
import 'screens/bluetooth_enable_screen.dart';
import 'screens/object_detection_settings_screen.dart';
import 'screens/camera_settings_screen.dart';
import 'services/storage_service.dart';
import 'services/bluetooth_audio_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start network monitoring for Pi auto-discovery
  BluetoothAudioService.startNetworkMonitoring();
  
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
  bool _bluetoothOn = false;
  StreamSubscription? _bluetoothSubscription;

  @override
  void initState() {
    super.initState();
    _checkPairingStatus();
    _listenToBluetoothState();
  }

  @override
  void dispose() {
    _bluetoothSubscription?.cancel();
    super.dispose();
  }

  void _listenToBluetoothState() {
    _bluetoothSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          _bluetoothOn = state == BluetoothAdapterState.on;
        });
      }
    });
  }

  Future<void> _checkPairingStatus() async {
    // Check if device is already paired
    final isPaired = await StorageService.isPaired();
    
    // Check Bluetooth state
    try {
      final isOn = await FlutterBluePlus.isOn;
      setState(() {
        _bluetoothOn = isOn;
      });
    } catch (e) {
      print('Error checking Bluetooth: $e');
    }
    
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

    // Check Bluetooth first
    if (!_bluetoothOn) {
      return BluetoothEnableScreen(
        onBluetoothEnabled: () {
          setState(() {
            _bluetoothOn = true;
          });
        },
      );
    }

    if (_isPaired) {
      // Already paired - go to main app (with Bluetooth check)
      return const MainNavigator();
    } else {
      // Not paired - show pairing flow
      return const PairingNavigator();
    }
  }
}

// Welcome screen then manual pairing
class PairingNavigator extends StatefulWidget {
  const PairingNavigator({super.key});

  @override
  State<PairingNavigator> createState() => _PairingNavigatorState();
}

class _PairingNavigatorState extends State<PairingNavigator> {
  bool _showWelcome = true;

  void _startPairing() {
    setState(() {
      _showWelcome = false;
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
    if (_showWelcome) {
      return PairingWelcomeScreen(onContinue: _startPairing);
    } else {
      // Go directly to manual pairing (skip mode selection)
      return PairingFlowScreen(
        isAutoMode: false,  // Manual pairing only
        onComplete: _completePairing,
      );
    }
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  String _currentRoute = 'home';
  bool _bluetoothOn = true;
  StreamSubscription? _bluetoothSubscription;
  
  // Keep screen alive
  @override
  bool get wantKeepAlive => true;
  
  // PageStorage to preserve scroll positions and state
  final PageStorageBucket _bucket = PageStorageBucket();

  @override
  void initState() {
    super.initState();
    _listenToBluetoothState();
    _loadSavedRoute();
    // Add observer to detect app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _bluetoothSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Save current route when app goes to background
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveCurrentRoute();
    }
  }
  
  Future<void> _saveCurrentRoute() async {
    await StorageService.saveLastRoute(_currentRoute);
  }
  
  Future<void> _loadSavedRoute() async {
    final savedRoute = await StorageService.getLastRoute();
    if (savedRoute != null && savedRoute != _currentRoute) {
      setState(() {
        _currentRoute = savedRoute;
      });
    }
  }

  void _listenToBluetoothState() {
    _bluetoothSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          _bluetoothOn = state == BluetoothAdapterState.on;
        });
      }
    });
  }

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
      case 'object_detection_settings':
        return ObjectDetectionSettingsScreen(
          key: const PageStorageKey('object_detection_settings'),
          onNavigate: _handleNavigation,
          currentRoute: _currentRoute,
        );
      case 'camera_settings':
        return CameraSettingsScreen(
          key: const PageStorageKey('camera_settings'),
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
    
    // Show Bluetooth enable screen if Bluetooth is turned off
    if (!_bluetoothOn) {
      return BluetoothEnableScreen(
        onBluetoothEnabled: () {
          setState(() {
            _bluetoothOn = true;
          });
        },
      );
    }
    
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