import 'package:flutter/material.dart';

class SakinaTheme {
  static ThemeData buildLightTheme(bool isArabic) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF1B6B5E),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      fontFamily: isArabic ? 'Amiri' : 'Inter',
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          fontFamily: isArabic ? 'Amiri' : 'Inter',
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Colors.black87,
          fontFamily: isArabic ? 'Amiri' : 'Inter',
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1B6B5E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  static ThemeData buildDarkTheme(bool isArabic) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF1B6B5E),
      fontFamily: isArabic ? 'Amiri' : 'Inter',
    );
  }
}
