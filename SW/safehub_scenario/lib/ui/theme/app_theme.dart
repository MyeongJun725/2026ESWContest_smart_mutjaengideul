import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF7F5F2);
  static const surface = Colors.white;

  static const primary = Color(0xFF8D2345);
  static const primaryStrong = Color(0xFF842039);
  static const primaryLight = Color(0xFFFAF0F2);
  static const primarySoft = Color(0xFFF1DDE2);
  static const header = Color(0xFFF6F5F3);

  static const textPrimary = Color(0xFF242629);
  static const textSecondary = Color(0xFF625E5A);
  static const textMuted = Color(0xFF777B82);
  static const border = Color(0xFFE5DFD8);

  static const success = Color(0xFF258765);
  static const successLight = Color(0xFFE9F7F1);
  static const warning = Color(0xFFC48218);
  static const warningLight = Color(0xFFFFF5DF);
  static const danger = Color(0xFFD64C4C);
  static const dangerLight = Color(0xFFFFEEEE);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'Pretendard',
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
    );
  }
}
