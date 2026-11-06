import 'package:flutter/material.dart';

import '../../app/vokey_splash.dart';

/// Design tokens from docs/UI_SPEC.md, deepened toward the neon reference board.
class VokeyTokens {
  static const background = Color(0xFF080B1F);
  static const surface = Color(0xFF10163A);
  static const card = Color(0xFF141C42);
  static const cardBorder = Color(0xFF243063);
  static const cyan = VokeyColors.cyan;
  static const violet = VokeyColors.violet;
  static const magenta = VokeyColors.magenta;
  static const text = Color(0xFFF4F7FF);
  static const muted = Color(0xFF9BA9BE);
  static const success = Color(0xFF38D99A);
  static const warning = Color(0xFFFFBE55);
  static const error = Color(0xFFFF657A);
  static const radius = 20.0;
}

class VokeyTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: VokeyTokens.cyan,
      secondary: VokeyTokens.violet,
      tertiary: VokeyTokens.magenta,
      surface: VokeyTokens.surface,
      error: VokeyTokens.error,
      onPrimary: Color(0xFF06111D),
      onSurface: VokeyTokens.text,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: VokeyTokens.background,
    );
    WidgetStateProperty<Color?> selected(Color on, Color off) =>
        WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? on : off,
        );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: VokeyTokens.text,
        displayColor: VokeyTokens.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: VokeyTokens.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: VokeyTokens.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: VokeyTokens.text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: VokeyTokens.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VokeyTokens.radius),
          side: const BorderSide(color: VokeyTokens.cardBorder),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: VokeyTokens.cyan,
        textColor: VokeyTokens.text,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: selected(Colors.white, VokeyTokens.muted),
        trackColor: selected(VokeyTokens.success, VokeyTokens.cardBorder),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: selected(VokeyTokens.success, Colors.transparent),
        checkColor: WidgetStateProperty.all(const Color(0xFF06111D)),
        side: const BorderSide(color: VokeyTokens.muted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: selected(VokeyTokens.success, VokeyTokens.muted),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: VokeyTokens.cyan,
        inactiveTrackColor: VokeyTokens.cardBorder,
        thumbColor: Colors.white,
        overlayColor: Color(0x3326D9E8),
        trackHeight: 5,
        valueIndicatorColor: VokeyTokens.violet,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: VokeyTokens.card,
        selectedColor: VokeyTokens.violet,
        side: const BorderSide(color: VokeyTokens.cardBorder),
        labelStyle: const TextStyle(color: VokeyTokens.text),
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: VokeyTokens.surface,
        indicatorColor: VokeyTokens.violet.withValues(alpha: .22),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected)
                ? VokeyTokens.text
                : VokeyTokens.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? VokeyTokens.cyan
                : VokeyTokens.muted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VokeyTokens.cyan,
          foregroundColor: const Color(0xFF06111D),
          minimumSize: const Size.fromHeight(50),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VokeyTokens.text,
          side: const BorderSide(color: VokeyTokens.cardBorder),
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: VokeyTokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: VokeyTokens.card,
        contentTextStyle: TextStyle(color: VokeyTokens.text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VokeyTokens.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      dividerTheme: const DividerThemeData(color: VokeyTokens.cardBorder),
    );
  }
}
