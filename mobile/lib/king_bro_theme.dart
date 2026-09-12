import 'package:flutter/material.dart';

/// LION BRO — professional brokerage design system.
/// Bright, high-contrast, data-first. No neon/candy gradients.
class KbColors {
  static const bgTop = Color(0xFFF4F6F8);
  static const bgMid = Color(0xFFF7F8FA);
  static const bgBottom = Color(0xFFF1F3F5);
  static const glass = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const cardSoft = Color(0xFFF7F8FA);
  static const cardStrong = Color(0xFFFFFFFF);
  static const silverGlass = Color(0xFFF2F4F7);
  static const border = Color(0xFFE3E6EA);
  static const borderStrong = Color(0xFFCDD2D8);

  // Keep the alias so existing source compiles, but map it to the brand red.
  static const cyan = Color(0xFFB11226);
  static const cyan2 = Color(0xFFD21F3C);
  static const crimson = Color(0xFFB11226);
  static const crimsonBright = Color(0xFFD21F3C);
  static const obsidian = Color(0xFF101216);
  static const obsidianSoft = Color(0xFF1B1E24);

  static const emerald = Color(0xFF138A5B);
  static const blueGreen = Color(0xFF246B8F);
  static const coral = Color(0xFFCE2438);
  static const magenta = Color(0xFFB11226);
  static const amber = Color(0xFF9A6500);

  static const text = Color(0xFF121417);
  static const textSecondary = Color(0xFF3B4048);
  static const textMuted = Color(0xFF6C727C);
  static const textFaint = Color(0xFF9DA3AD);
  static const notice = Color(0xFFFFF7F2);
  static const shadow = Color(0x12000000);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgMid, bgBottom],
  );
}

class KingBroTheme {
  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: KbColors.crimson,
      brightness: Brightness.light,
      surface: KbColors.card,
    ).copyWith(
      primary: KbColors.crimson,
      secondary: KbColors.crimsonBright,
      tertiary: KbColors.obsidian,
      surface: KbColors.card,
      error: KbColors.coral,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: KbColors.text,
    );

    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: KbColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: KbColors.bgMid,
      canvasColor: KbColors.bgMid,
      splashColor: KbColors.crimson.withValues(alpha: 0.05),
      highlightColor: KbColors.crimson.withValues(alpha: 0.03),
      dividerColor: KbColors.border,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.compact,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: KbColors.text, height: 1.25, fontSize: 14),
        bodyMedium: TextStyle(color: KbColors.textSecondary, height: 1.25, fontSize: 13),
        bodySmall: TextStyle(color: KbColors.textMuted, height: 1.2, fontSize: 11),
        titleLarge: TextStyle(color: KbColors.text, fontWeight: FontWeight.w800, letterSpacing: -.3),
        titleMedium: TextStyle(color: KbColors.text, fontWeight: FontWeight.w800, letterSpacing: -.15),
        headlineSmall: TextStyle(color: KbColors.text, fontWeight: FontWeight.w800, letterSpacing: -.4),
        headlineMedium: TextStyle(color: KbColors.text, fontWeight: FontWeight.w800, letterSpacing: -.55),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: KbColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: KbColors.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: KbColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: KbColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        labelStyle: const TextStyle(color: KbColors.textSecondary, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: KbColors.textMuted),
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: KbColors.crimson, width: 1.3),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: KbColors.crimson.withValues(alpha: .08),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? KbColors.crimson : KbColors.textMuted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 10,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? KbColors.crimson : KbColors.textMuted, size: 22);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KbColors.crimson,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KbColors.crimson,
          side: const BorderSide(color: KbColors.borderStrong),
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
