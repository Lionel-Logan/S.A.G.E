import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray900 = Color(0xFF1A1A1A);
  static const Color gray800 = Color(0xFF2A2A2A);
  static const Color gray700 = Color(0xFF3A3A3A);
  static const Color gray500 = Color(0xFF6B6B6B);
  
  // Accent Colors - Cyan-based harmonious palette
  static const Color cyan = Color(0xFF00D9FF);        // Primary cyan
  static const Color purple = Color(0xFFB24BF3);      // Soft purple (complements cyan)
  static const Color blue = Color(0xFF4D9FFF);        // Light blue (analogous)
  static const Color pink = Color(0xFFFF6BCB);        // Soft pink (harmonious)
  
  // Legacy aliases for backward compatibility
  static const Color yellow = pink;
  static const Color green = blue;

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: black,
    primaryColor: cyan,
    
    // Futuristic font
    textTheme: GoogleFonts.rajdhaniTextTheme(
      ThemeData.dark().textTheme.apply(
        bodyColor: white,
        displayColor: white,
      ),
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    
    colorScheme: const ColorScheme.dark(
      primary: cyan,
      secondary: purple,
      surface: gray900,
      background: black,
    ),
  );
}