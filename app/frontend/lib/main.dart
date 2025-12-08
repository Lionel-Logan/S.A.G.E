import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app-theme.dart';
import 'screens/dashboard-screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force dark mode and hide status bar for immersive experience
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
      home: const DashboardScreen(),
    );
  }
}