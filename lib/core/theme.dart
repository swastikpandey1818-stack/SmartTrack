import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF04110C);
  static const bg2 = Color(0xFF071A12);
  static const surface = Color(0xFF0B2218);
  static const surfaceHi = Color(0xFF103021);
  static const border = Color(0xFF1B4A33);
  static const emerald = Color(0xFF22C55E);
  static const lime = Color(0xFF7CFC3C);
  static const mint = Color(0xFF34D399);
  static const cyan = Color(0xFF22D3EE);
  static const water = Color(0xFF38BDF8);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const text = Color(0xFFE8F5EC);
  static const textDim = Color(0xFF8FB5A0);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.emerald,
      secondary: AppColors.mint,
      surface: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceHi,
      error: AppColors.red,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHi,
      contentTextStyle: const TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: AppColors.emerald,
      thumbColor: AppColors.lime,
      inactiveTrackColor: AppColors.border,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.lime : AppColors.textDim),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.emerald.withValues(alpha: 0.5)
              : AppColors.border),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.emerald, width: 1.5),
      ),
    ),
  );
}
