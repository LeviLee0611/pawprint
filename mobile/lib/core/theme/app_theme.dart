import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFFF9A3C);
  static const primaryLight = Color(0xFFFFE0B2);
  static const primaryDark = Color(0xFFE65100);

  static const background = Color(0xFFFFFAF5);
  static const surface = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFF3E8);

  static const brown = Color(0xFF8D6E63);
  static const brownLight = Color(0xFFD7CCC8);

  static const green = Color(0xFF81C784);
  static const greenLight = Color(0xFFE8F5E9);

  static const peach = Color(0xFFFFAB91);
  static const peachLight = Color(0xFFFBE9E7);

  static const textPrimary = Color(0xFF3E2723);
  static const textSecondary = Color(0xFF8D6E63);
  static const textHint = Color(0xFFBCAAA4);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.peach,
      surface: AppColors.surface,
      background: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.brownLight,
      elevation: 8,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),
  );
}
