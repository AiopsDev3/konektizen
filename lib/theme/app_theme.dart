import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Bold Green, Yellow, Orange Color Scheme
  static const Color primary = Color(0xFF1B5E20); // Deep Forest Green
  static const Color primaryLight = Color(0xFF4C8C4A); // Mid Green
  static const Color primaryContainer = Color(0xFFE8F5E9); // Light Green
  static const Color secondary = Color(0xFFE65100); // Bold Safety Orange
  static const Color accent = Color(0xFFE65100); // Alias for Orange
  static const Color tertiary = Color(0xFFFFD600); // Vibrant Yellow
  static const Color tertiaryContainer = Color(0xFFFFFDE7); // Very Light Yellow for backgrounds
  
  static const Color background = Color(0xFFF8F9FA); // Very Light Gray
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFB71C1C);
  static const Color info = Color(0xFF0277BD); // Deep Blue for info

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFFFD600);
  static const Color alert = Color(0xFFE65100);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        tertiary: tertiary,
        tertiaryContainer: tertiaryContainer,
        onTertiary: Colors.black,
        background: background,
        surface: surface,
        onSurface: Color(0xFF212121), // Darkest Gray for readability
        error: error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(color: const Color(0xFF212121), fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.inter(color: const Color(0xFF212121), fontWeight: FontWeight.bold),
        bodyLarge: GoogleFonts.inter(color: const Color(0xFF212121)),
        bodyMedium: GoogleFonts.inter(color: const Color(0xFF424242)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      // tabBarTheme removed to fix build - applied locally
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: secondary, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF424242)),
        contentPadding: const EdgeInsets.all(16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: tertiary.withOpacity(0.3),
        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF212121)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
