import 'package:flutter/material.dart';

// Dark mode (2026-11-12): the theme is brightness-aware. AppColors keeps
// the SAME member names in both modes; members whose value differs between
// light and dark are static getters that resolve live from the current
// brightness (Settings choice, or the phone's setting when 'system').
// Members identical in both modes stay `static const`.
//   - `AppColors.white` is PURE WHITE in both modes: it is the foreground
//     colour (text/icons on Alert buttons, badges, photos). Surfaces that
//     were white in light mode use the new `AppColors.surface` instead.
//   - Maps stay as they are in dark mode (light tiles); only UI chrome
//     follows the theme. Nothing in this file touches map configuration.
// The mode lives in AppTheme.modeNotifier (ValueNotifier<ThemeMode>),
// fed from Settings ('system'/'light'/'dark', persisted by
// SettingsService) and observed by WhereLogApp, which also observes
// platform-brightness changes so 'system' follows the phone live.

class AppColors {
  // Resolved brightness: the Settings choice, or the phone's setting.
  static Brightness get _brightness {
    final mode = AppTheme.modeNotifier.value;
    if (mode == ThemeMode.dark) return Brightness.dark;
    if (mode == ThemeMode.light) return Brightness.light;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  static bool get isDark => _brightness == Brightness.dark;

  // --- Surfaces (warm character kept in both modes) ---
  static Color get scaffold => isDark ? const Color(0xFF1E1B18) : const Color(0xFFF5F3EE);
  static Color get scaffoldDark => isDark ? const Color(0xFF322D28) : const Color(0xFFEDE8DF);
  static Color get card => isDark ? const Color(0xFF26221E) : const Color(0xFFFAF6F0);
  static Color get cardSelected => isDark ? const Color(0xFF22303F) : const Color(0xFFE8F0FF);
  static Color get banner => isDark ? const Color(0xFF26221E) : const Color(0xFFE8E0D5);
  // The paper surface: pure white in light mode, dark warm grey in dark
  // mode. This is what white container/box/input surfaces use; see `white`.
  static Color get surface => isDark ? const Color(0xFF2E2A26) : const Color(0xFFFFFFFF);
  // Pure white in BOTH modes: foreground only (text/icons on Alert buttons,
  // badges, photos, switch thumbs). Never a surface.
  static const white = Colors.white;
  // Single source of truth for all borders
  static Color get border => isDark ? const Color(0x33FFFFFF) : const Color(0x61000000);
  // A stronger border for the main page's selected tab: the standard
  // 20% white border is too faint to read in dark mode (2026-11-13).
  static Color get borderStrong => isDark ? const Color(0x80FFFFFF) : const Color(0x61000000);
  static Color get textPrimary => isDark ? const Color(0xFFF2EEE6) : const Color(0xFF1A1A1A);
  static Color get textSecondary => isDark ? const Color(0xFFB8B0A4) : const Color(0xFF444444);
  static Color get textDisabled => isDark ? const Color(0xFF8A8378) : const Color(0xFF6B6B6B);
  static const buttonBg = Color(0xFF6A6A6A);
  static Color get buttonBgDisabled => isDark ? const Color(0xFF3A3633) : const Color(0xFFB0B0B0);
  // One red for the whole app: Alert. Darker than pure red for readability
  // in light mode; a lighter red of the same hue in dark mode so Alert text
  // stays readable on dark surfaces. Still one red, no second red.
  static Color get alert => isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828);
  // Alert at low opacity, for pale alert backgrounds only (same hue, not a second red).
  static Color get alertTint => isDark ? const Color(0xFF3D1E1E) : const Color(0xFFFFEBEE);
  static Color get success => isDark ? const Color(0xFF66BB6A) : const Color(0xFF43A047);
  // Generic notice icon (POI showCenterNotice, also used for errors) - kept at its
  // current green so its look does not change in this pass; change here when directed.
  static Color get notice => isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50);
  static Color get mapAccent => isDark ? const Color(0xFF64B5F6) : const Color(0xFF2196F3);
  // The wordmark blue: 'Where' in the AppHeader logo (AppText.logoWhere).
  // Storage wears it in the Location Options trees, and the POI card
  // distance display uses it (review round, 2026-11-10).
  static const logoBlue = Color(0xFF1E90FF);
  static Color get warningBackground => isDark ? const Color(0xFF4A3220) : const Color(0xFFFFE0B2);
  static Color get warningText => isDark ? const Color(0xFFFB8C00) : const Color(0xFFE65100);
  static Color get infoBrown => isDark ? const Color(0xFFA1887F) : const Color(0xFF5D4037);
  static Color get disabledSurface => isDark ? const Color(0xFF211D1A) : const Color(0xFFE0E0E0);
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
  // Borders resolve live like the colours do (AppColors.border is a getter),
  // so these are getters, not consts.
  static BorderSide get side => BorderSide(color: AppColors.border, width: 1.0);
  static BorderSide get sideStrong => BorderSide(color: AppColors.borderStrong, width: 1.0);
  static BorderSide get sideLight => BorderSide(color: AppColors.border, width: 1.0); // same, but semantic
  // For selection pills - selected vs unselected
  static BorderSide get sideSelected => BorderSide(color: AppColors.buttonBg, width: 1.8);
  static BorderSide get sideUnselected => BorderSide(color: AppColors.border, width: 1.0);
  static BorderRadius get radiusCircular => BorderRadius.circular(radius);
  static RoundedRectangleBorder get cardShape => RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: side);
  static RoundedRectangleBorder get buttonShape => RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button), side: BorderSide.none);
  static OutlineInputBorder get inputBorder => OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: side);
  static OutlineInputBorder get inputBorderFocused => OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide(color: AppColors.textPrimary, width: 1));
}

class AppDivider {
  static Divider get horizontal => Divider(height: 28, thickness: 0.8, color: AppColors.border);
  static Divider get horizontalTight => Divider(height: 16, thickness: 0.8, color: AppColors.border);
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
    // resolveWith (not .all): the side is brightness-aware and must be
    // re-read when the mode changes, not captured once at first use.
    side: WidgetStateProperty.resolveWith((_) => AppBorder.sideUnselected),
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
    // resolveWith (not .all): the side is brightness-aware and must be
    // re-read when the mode changes, not captured once at first use.
    shape: WidgetStateProperty.resolveWith((_) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.sideUnselected)),
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
    // resolveWith (not .all): the foreground and side are brightness-aware
    // and must be re-read when the mode changes, not captured once.
    foregroundColor: WidgetStateProperty.resolveWith((_) => AppColors.textPrimary),
    shape: WidgetStateProperty.resolveWith((_) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.side)),
    side: WidgetStateProperty.resolveWith((_) => AppBorder.side),
    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
    minimumSize: WidgetStateProperty.all(const Size(0, 32)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    elevation: WidgetStateProperty.all(0),
  );
}

class AppText {
  static String upper(String s) => s.toUpperCase();
  // Styles resolve live like the colours do (they read AppColors getters),
  // so these are getters, not consts.
  static TextStyle get tabSelected => TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.1, color: AppColors.textPrimary);
  static TextStyle get tabUnselected => TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.1, color: AppColors.textSecondary);
  static TextStyle get countBar => TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary);
  static TextStyle get cardTitle => TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary);
  static TextStyle get cardLocation => TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary);
  static TextStyle get dialogTitle => TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary, letterSpacing: 0.3);
  static TextStyle get dialogSection => TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textSecondary, letterSpacing: 0.6);
  static TextStyle get dialogItem => TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary);
  static TextStyle get dialogItemBold => TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary);
  static TextStyle get dialogTitleAlert => TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.alert);
  static TextStyle get dialog => TextStyle(fontWeight: FontWeight.w400, fontSize: 12, color: AppColors.textSecondary);
  static TextStyle get dialogAlert => TextStyle(fontWeight: FontWeight.w400, fontSize: 12, color: AppColors.alert);
  static TextStyle get dialogDistance => TextStyle(fontWeight: FontWeight.w400, fontSize: 12, color: AppColors.logoBlue);
  static TextStyle get dialogNotice => TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary);
  static TextStyle get photoCaption => TextStyle(color: AppColors.whiteDim, fontSize: 11, fontWeight: FontWeight.w600);
  static TextStyle get menuTileTitle => TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary);
  static TextStyle get menuTileTitleAlert => TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.alert);
  static TextStyle get buttonPrimary => TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.3);
  static TextStyle get buttonSmall => TextStyle(fontWeight: FontWeight.w600, fontSize: 11);
  static TextStyle get buttonSmallAlert => TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.alert);
  static TextStyle get input => TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary);
  static TextStyle get inputHint => TextStyle(fontWeight: FontWeight.w400, fontSize: 12, color: AppColors.textDisabled);
  static TextStyle get inputMulti => TextStyle(fontWeight: FontWeight.w400, fontSize: 13, color: AppColors.textPrimary);
  static TextStyle get logoWhere => TextStyle(color: AppColors.logoBlue, fontWeight: FontWeight.w900, fontSize: 22);
  static TextStyle get logoLogAlert => TextStyle(color: AppColors.alert, fontWeight: FontWeight.w900, fontSize: 22);
}

class AppTheme {
  // The display-mode choice, fed from Settings ('system'/'light'/'dark').
  // main() loads the stored value before runApp; the Settings screen
  // updates it on tap. WhereLogApp listens to it.
  static final ValueNotifier<ThemeMode> modeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  static ThemeMode modeFromString(String v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static ThemeData light() {
    return ThemeData(
      scaffoldBackgroundColor: AppColors.scaffold,
      fontFamily: 'Inter',
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.buttonBg,
        surface: AppColors.scaffold,
        onPrimary: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.scaffold,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppText.tabSelected,
        unselectedLabelStyle: AppText.tabUnselected,
        indicator: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
            left: BorderSide(color: AppColors.border, width: 1),
            right: BorderSide(color: AppColors.border, width: 1),
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.tabIndicator),
            topRight: Radius.circular(AppRadius.tabIndicator),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppBorder.radius)),
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
          backgroundColor: AppColors.surface,
          side: AppBorder.side,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          minimumSize: AppSize.buttonMinSize,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: AppText.buttonSmall,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: AppButton.iconOnly),
      dividerTheme: DividerThemeData(color: AppColors.border, thickness: 0.8, space: 28),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        isCollapsed: false,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: AppSize.fieldPadding,
        constraints: const BoxConstraints(minHeight: AppSize.fieldHeight), // single-line 36, overridden for multi-line
        hintStyle: AppText.inputHint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: AppBorder.side),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: AppBorder.side),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: BorderSide(color: AppColors.textPrimary, width: 1)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5), width: 1)),
      ),
    );
  }

  // Dark theme: the same structure as light(), resolved through the same
  // AppColors/AppText getters (which read the current brightness), plus
  // dialog / bottom-sheet / snackbar colours so overlays are dark too.
  // Map tiles are untouched (they stay light by Rudy's ruling, 2026-11-12).
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.scaffold,
      fontFamily: 'Inter',
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: AppColors.buttonBg,
        surface: AppColors.scaffold,
        onPrimary: Colors.white,
        secondary: AppColors.logoBlue,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.scaffold,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppText.tabSelected,
        unselectedLabelStyle: AppText.tabUnselected,
        indicator: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
            left: BorderSide(color: AppColors.border, width: 1),
            right: BorderSide(color: AppColors.border, width: 1),
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.tabIndicator),
            topRight: Radius.circular(AppRadius.tabIndicator),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppBorder.radius)),
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
          backgroundColor: AppColors.surface,
          side: AppBorder.side,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          minimumSize: AppSize.buttonMinSize,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: AppText.buttonSmall,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: AppButton.iconOnly),
      dividerTheme: DividerThemeData(color: AppColors.border, thickness: 0.8, space: 28),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        isCollapsed: false,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: AppSize.fieldPadding,
        constraints: const BoxConstraints(minHeight: AppSize.fieldHeight), // single-line 36, overridden for multi-line
        hintStyle: AppText.inputHint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: AppBorder.side),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: AppBorder.side),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: BorderSide(color: AppColors.textPrimary, width: 1)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5), width: 1)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppText.dialogTitle,
        contentTextStyle: AppText.dialog,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.buttonBg,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }
}
