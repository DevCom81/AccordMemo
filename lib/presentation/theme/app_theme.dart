import 'package:flutter/material.dart';

import 'app_colors.dart';

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.forest,
    onPrimary: AppColors.onForest,
    secondary: AppColors.copper,
    onSecondary: Colors.white,
    surface: AppColors.ivory,
    onSurface: AppColors.ink,
    error: Color(0xFF8A3B2B),
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ivory,
    fontFamily: 'Segoe UI',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: AppColors.ink, height: 1.4),
      bodyMedium: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 300),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.copper,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.copper.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.92),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.forest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: const BorderSide(color: AppColors.forest),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    focusColor: AppColors.focus.withValues(alpha: 0.25),
  );
}
