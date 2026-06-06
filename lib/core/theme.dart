import 'package:flutter/material.dart';

class SagaTheme {
  // Color institucional Verde Falabella
  static const Color primaryGreen = Color(0xFF64A70B); 
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color alertRed = Color(0xFFD32F2F);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      // 💡 CORRECCIÓN AQUÍ: Cambiado CardTheme por CardThemeData
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 2,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}