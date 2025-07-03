import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // App Colors
  static const Color primaryBlue = Color(0xFF0C8AF2);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF1A1A1A);
  
  // Light Theme - iOS Style
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF007AFF), // iOS Blue
        brightness: Brightness.light,
      ).copyWith(
        surface: Colors.white,
        background: Colors.white,
        primary: const Color(0xFF007AFF),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: null,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false, // iOS style left alignment
        titleTextStyle: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      textTheme: GoogleFonts.manropeTextTheme(),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
      ),
    );
  }
  
  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: null, // Use system default
        backgroundColor: backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: GoogleFonts.manropeTextTheme(
        ThemeData.dark().textTheme,
      ),
    );
  }
}