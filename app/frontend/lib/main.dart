import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app-theme.dart';
import 'screens/dashboard-screen.dart';
import 'screens/settings_screen.dart';

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
      home: const MainNavigator(),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  String _currentRoute = 'home';

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
          key: const ValueKey('dashboard'),
          onNavigate: _handleNavigation,
          currentRoute: _currentRoute,
        );
      case 'settings':
        return SettingsScreen(
          key: const ValueKey('settings'),
          onNavigate: _handleNavigation,
          currentRoute: _currentRoute,
        );
      case 'account':
        // For now, navigate to settings when account is tapped
        return SettingsScreen(
          key: const ValueKey('settings'),
          onNavigate: _handleNavigation,
          currentRoute: 'settings',
        );
      default:
        return DashboardScreen(
          key: const ValueKey('dashboard'),
          onNavigate: _handleNavigation,
          currentRoute: _currentRoute,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
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
    );
  }
}