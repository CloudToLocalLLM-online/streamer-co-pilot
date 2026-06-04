import 'package:flutter/material.dart';

final botTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: Colors.purple.shade400,
    secondary: Colors.deepPurple.shade300,
    surface: const Color(0xFF1A1A2E),
  ),
  scaffoldBackgroundColor: const Color(0xFF16213E),
  cardColor: const Color(0xFF1A1A2E),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0F3460),
    foregroundColor: Colors.white,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1A1A2E),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.purple.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
    ),
  ),
);