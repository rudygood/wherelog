import 'package:flutter/material.dart';

class AppColors {
  static const scaffold = Color(0xFFF5F3EE);
  static const scaffoldDark = Color(0xFFEDE8DF);
  static const card = Color(0xFFFAF6F0);
  static const cardSelected = Color(0xFFE8F0FF);
  static const banner = Color(0xFFE8E0D5);
  static const white = Colors.white;
  // Single source of truth for all borders
  static const border = Color(0x61000000);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF444444);
  static const textDisabled = Color(0xFF6B6B6B);
  static const buttonBg = Color(0xFF6A6A6A);
  static const buttonBgDisabled = Color(0xFFB0B0B0);
  // One red for the whole app: Alert. Darker than pure red for readability.
  static const alert = Color(0xFFC62828);
  // Alert at low opacity, for pale alert backgrounds only (same hue, not a second red).
  static const alertTint = Color(0xFFFFEBEE);
  static const success = Color(0xFF43A047);
  // Generic notice icon (POI showCenterNotice, also used for errors) - kept at its
  // current green so its look does not change in this pass; change here when directed.
  static const notice = Color(0xFF4CAF50);
  static const mapAccent = Color(0xFF2196F3);
  static const warningBackground = Color(0xFFFFE0B2);
  static const warningText = Color(0xFFE65100);
  static const infoBrown = Color(0xFF5D4037);
  static const disabledSurface = Color(0xFFE0E0E0);
  // White at 70% - disabled text on a button, and text over a dark photo overlay.
  static const whiteDim = Color(0xB3FFFFFF);
  // Opacity blacks: shadows and barriers only, never text.
  static const shadowSoft = Color(0x2E000000);
  static const shadow = Color(0x42000000);
  static const shadowMedium = Color(0x61000000);
  static const barrier = Color(0x8A000000);
}

class AppRadius {
  static const button = 10.0;
  static const card = 10.0; // unified with button - user preference
  static const sheet = 16.0;
  static const tabIndicator = 12.0;
  static const input = 10.0; // unified with button
}

class AppSize {
  static const double fieldHeight = 36.0;
  static const double buttonHeight = 36.0;
  static const double fieldHeightMulti = 76.0; // 3 lines visible
  static const EdgeInsets fieldPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 8);
  static const EdgeInsets fieldPaddingMulti = EdgeInsets.symmetric(horizontal: 12, vertical: 10);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 0);
  static const EdgeInsets buttonPaddingSmall = EdgeInsets.symmetric(horizontal: 12, vertical: 0);
  static const Size buttonMinSize = Size(0, 36);
  static const Size buttonMinSizeIcon = Size(36, 36);
  static const Size iconButtonMinSize = Size(36, 36);
}

class AppBorder {
  static const double width = 1.0;
  static const double radius = 10.0;
  static const BorderSide side = BorderSide(color: AppColors.border, width: 1.0);
  static const BorderSide sideLight = BorderSide(color: AppColors.border, width: 1.0); // same, but semantic
  // For selection pills - selected vs unselected
  static const BorderSide sideSelected = BorderSide(color: AppColors.buttonBg, width: 1.8);
  static const BorderSide sideUnselected = BorderSide(color: AppColors.border, width: 1.0);
  static BorderRadius get radiusCircular => BorderRadius.circular(radius);
  static RoundedRectangleBorder get cardShape => RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: side);
  static RoundedRectangleBorder get buttonShape => RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button), side: BorderSide.none);
  static OutlineInputBorder get inputBorder => OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: side);
  static OutlineInputBorder get inputBorderFocused => OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide(color: AppColors.textPrimary, width: 1));
}

class AppDivider {
  static const horizontal = Divider(height: 28, thickness: 0.8, color: AppColors.border);
  static const horizontalTight = Divider(height: 16, thickness: 0.8, color: AppColors.border);
}

class AppButton {
  static ButtonStyle primary = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return AppColors.buttonBgDisabled;
      return AppColors.buttonBg;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return AppColors.whiteDim;
      return Colors.white;
    }),
    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button))),
    padding: WidgetStateProperty.all(AppSize.buttonPadding),
    minimumSize: WidgetStateProperty.all(AppSize.buttonMinSize),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.3)),
    elevation: WidgetStateProperty.all(0),
  );

  static ButtonStyle primarySmall = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return AppColors.buttonBgDisabled;
      return AppColors.buttonBg;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return AppColors.whiteDim;
      return Colors.white;
    }),
    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button))),
    padding: WidgetStateProperty.all(AppSize.buttonPaddingSmall),
    minimumSize: WidgetStateProperty.all(AppSize.buttonMinSize),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
    elevation: WidgetStateProperty.all(0),
  );

  static ButtonStyle secondarySmall = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return AppColors.buttonBgDisabled.withOpacity(0.6);
      return AppColors.buttonBgDisabled;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return AppColors.whiteDim;
      return Colors.white;
    }),
    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button))),
    padding: WidgetStateProperty.all(AppSize.buttonPaddingSmall),
    minimumSize: WidgetStateProperty.all(AppSize.buttonMinSize),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
    elevation: WidgetStateProperty.all(0),
  );

  static ButtonStyle whiteSmall = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return AppColors.white.withOpacity(0.6);
      return AppColors.white;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return AppColors.textDisabled;
      return AppColors.textPrimary;
    }),
    side: WidgetStateProperty.all(AppBorder.sideUnselected),
    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button))),
    padding: WidgetStateProperty.all(AppSize.buttonPaddingSmall),
    minimumSize: WidgetStateProperty.all(AppSize.buttonMinSize),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
    elevation: WidgetStateProperty.all(0),
  );

  static ButtonStyle iconOnly = ButtonStyle(
    backgroundColor: WidgetStateProperty.all(Colors.transparent),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return AppColors.textDisabled;
      return AppColors.textSecondary;
    }),
    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button))),
    padding: WidgetStateProperty.all(EdgeInsets.zero),
    minimumSize: WidgetStateProperty.all(AppSize.iconButtonMinSize),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    elevation: WidgetStateProperty.all(0),
  );

  static ButtonStyle pillSelected = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.buttonBg;
      return AppColors.white;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.white;
      return AppColors.textPrimary;
    }),
    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.sideUnselected)),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppBorder.sideSelected;
      return AppBorder.sideUnselected;
    }),
    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 0)),
    minimumSize: WidgetStateProperty.all(const Size(0, 36)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
    elevation: WidgetStateProperty.all(0),
  );

  static ButtonStyle statusPill = ButtonStyle(
    backgroundColor: WidgetStateProperty.all(AppColors.white),
    foregroundColor: WidgetStateProperty.all(AppColors.textPrimary),
    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.side)),
    side: WidgetStateProperty.all(AppBorder.side),
    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
    minimumSize: WidgetStateProperty.all(const Size(0, 32)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    elevation: WidgetStateProperty.all(0),
  );
}

class AppText {
  static String upper(String s) => s.toUpperCase();
  static const tabSelected = TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.1, color: AppColors.textPrimary);
  static const tabUnselected = TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.1, color: AppColors.textSecondary);
  static const countBar = TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary);
  static const cardTitle = TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary);
  static const cardLocation = TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary);
  static const dialogTitle = TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary, letterSpacing: 0.3);
  static const dialogSection = TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textSecondary, letterSpacing: 0.6);
  static const dialogItem = TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary);
  static const dialogItemBold = TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary);
  static const dialogTitleAlert = TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.alert);
  static const dialog = TextStyle(fontWeight: FontWeight.w400, fontSize: 12, color: AppColors.textSecondary);
  static const dialogAlert = TextStyle(fontWeight: FontWeight.w400, fontSize: 12, color: AppColors.alert);
  static const dialogNotice = TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary);
  static const photoCaption = TextStyle(color: AppColors.whiteDim, fontSize: 11, fontWeight: FontWeight.w600);
  static const menuTileTitle = TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary);
  static const menuTileTitleAlert = TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.alert);
  static const buttonPrimary = TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.3);
  static const buttonSmall = TextStyle(fontWeight: FontWeight.w600, fontSize: 11);
  static const buttonSmallAlert = TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.alert);
  static const input = TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary);
  static const inputHint = TextStyle(fontWeight: FontWeight.w400, fontSize: 12, color: AppColors.textDisabled);
  static const inputMulti = TextStyle(fontWeight: FontWeight.w400, fontSize: 13, color: AppColors.textPrimary);
  static const logoWhere = TextStyle(color: Color(0xFF1E90FF), fontWeight: FontWeight.w900, fontSize: 22);
  static const logoLogAlert = TextStyle(color: AppColors.alert, fontWeight: FontWeight.w900, fontSize: 22);
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
          borderRadius: BorderRadius.all(Radius.circular(AppBorder.radius)),
          side: BorderSide(color: AppColors.border, width: 1.0),
        ),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: AppButton.primary),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: AppText.buttonSmall,
          minimumSize: AppSize.buttonMinSize,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.white,
          side: AppBorder.side,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          minimumSize: AppSize.buttonMinSize,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: AppText.buttonSmall,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: AppButton.iconOnly),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 0.8, space: 28),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        isCollapsed: false,
        filled: true,
        fillColor: AppColors.white,
        contentPadding: AppSize.fieldPadding,
        constraints: const BoxConstraints(minHeight: AppSize.fieldHeight), // single-line 36, overridden for multi-line
        hintStyle: AppText.inputHint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: AppBorder.side),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: AppBorder.side),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: const BorderSide(color: AppColors.textPrimary, width: 1)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5), width: 1)),
      ),
    );
  }
}
