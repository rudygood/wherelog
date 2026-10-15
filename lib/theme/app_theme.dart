import 'package:flutter/material.dart';

class AppColors {
  static const scaffold = Color(0xFFF5F3EE);
  static const scaffoldDark = Color(0xFFEDE8DF);
  static const card = Color(0xFFFAF6F0);
  static const cardSelected = Color(0xFFE8F0FF);
  static const banner = Color(0xFFE8E0D5);
  static const white = Colors.white;
  static const border = Color(0x1A000000);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF444444);
  static const textDisabled = Color(0xFF6B6B6B);
  static const buttonBg = Color(0xFF6A6A6A); // requested
  static const buttonBgDisabled = Color(0xFFB0B0B0);
}

class AppRadius {
  static const button = 10.0;
  static const card = 16.0;
  static const sheet = 16.0;
  static const tabIndicator = 12.0;
  static const input = 24.0;
}

class AppText {
  static String upper(String s) => s.toUpperCase();
  static const tabSelected = TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.1, color: AppColors.textPrimary);
  static const tabUnselected = TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.1, color: AppColors.textSecondary);
  static const countBar = TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary);
  static const cardTitle = TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary);
  static const cardLocation = TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary);
  static const cardMeta = TextStyle(fontSize: 11, color: AppColors.textSecondary);
  static const cardMetaSmall = TextStyle(fontSize: 10, color: AppColors.textSecondary);
  static const dialogTitle = TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary, letterSpacing: 0.3);
  static const dialogSection = TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textSecondary, letterSpacing: 0.6);
  static const dialogItem = TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary);
  static const dialogItemBold = TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary);
  static const buttonPrimary = TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.3);
  static const buttonSmall = TextStyle(fontWeight: FontWeight.w600, fontSize: 12);
  static const logoWhere = TextStyle(color: Color(0xFF1E90FF), fontWeight: FontWeight.w900, fontSize: 22);
  static const logoLog = TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w900, fontSize: 22);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      scaffoldBackgroundColor: AppColors.scaffold,
      fontFamily: 'Inter',
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.buttonBg,
        surface: AppColors.scaffold,
        onPrimary: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.scaffold,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppText.tabSelected,
        unselectedLabelStyle: AppText.tabUnselected,
        indicator: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.tabIndicator),
            topRight: Radius.circular(AppRadius.tabIndicator),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
          side: BorderSide(color: AppColors.border, width: 0.5),
        ),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return AppColors.buttonBgDisabled;
            return AppColors.buttonBg; // 6A6A6A
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return Colors.white70;
            return Colors.white;
          }),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button))),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
          textStyle: WidgetStateProperty.all(AppText.buttonPrimary),
          elevation: WidgetStateProperty.all(0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: AppText.buttonSmall,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input)),
      ),
    );
  }
}
