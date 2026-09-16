import 'package:flutter/material.dart';

/// LION BRO — bright professional brokerage design system.
/// Visual direction: cool white surfaces, royal/navy blue structure and restrained
/// electric-cyan motion accents. Crimson is reserved for SELL/risk/error states.
class KbColors {
  static const bgTop = Color(0xFFF8FBFF);
  static const bgMid = Color(0xFFF4F8FC);
  static const bgBottom = Color(0xFFEDF4FA);
  static const glass = Color(0xF7FFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const cardSoft = Color(0xFFF1F7FC);
  static const cardStrong = Color(0xFFFFFFFF);
  static const silverGlass = Color(0xFFEAF2F8);
  static const border = Color(0xFFD7E3ED);
  static const borderStrong = Color(0xFFBACCDD);

  static const royal = Color(0xFF173B8E);
  static const royalBright = Color(0xFF2556C7);
  static const navy = Color(0xFF0B1E46);
  static const cyan = Color(0xFF12B7D6);
  static const cyan2 = Color(0xFF67D9EA);

  // Risk / order-side semantics stay distinct from the general UI accent.
  static const crimson = Color(0xFFD7263D);
  static const crimsonBright = Color(0xFFEE4057);
  static const emerald = Color(0xFF0A9A73);
  static const blueGreen = Color(0xFF087FA8);
  static const coral = Color(0xFFD7263D);
  static const magenta = Color(0xFF9E3E9D);
  static const amber = Color(0xFF9C6900);

  static const obsidian = Color(0xFF111827);
  static const obsidianSoft = Color(0xFF263247);
  static const text = Color(0xFF101828);
  static const textSecondary = Color(0xFF344054);
  static const textMuted = Color(0xFF667085);
  static const textFaint = Color(0xFF98A2B3);
  static const notice = Color(0xFFF0F8FF);
  static const shadow = Color(0x140B1E46);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgMid, bgBottom],
  );

  static const brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [royal, royalBright, cyan],
  );
}

class KingBroTheme {
  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: KbColors.royal,
      brightness: Brightness.light,
      surface: KbColors.card,
    ).copyWith(
      primary: KbColors.royal,
      secondary: KbColors.cyan,
      tertiary: KbColors.navy,
      surface: KbColors.card,
      error: KbColors.crimson,
      onPrimary: Colors.white,
      onSecondary: KbColors.navy,
      onSurface: KbColors.text,
    );

    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: KbColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: KbColors.bgMid,
      canvasColor: KbColors.bgMid,
      splashColor: KbColors.cyan.withValues(alpha: 0.08),
      highlightColor: KbColors.royal.withValues(alpha: 0.04),
      dividerColor: KbColors.border,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.compact,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: KbColors.text, height: 1.25, fontSize: 14),
        bodyMedium: TextStyle(
            color: KbColors.textSecondary, height: 1.25, fontSize: 13),
        bodySmall:
            TextStyle(color: KbColors.textMuted, height: 1.2, fontSize: 11),
        titleLarge: TextStyle(
            color: KbColors.text,
            fontWeight: FontWeight.w800,
            letterSpacing: -.3),
        titleMedium: TextStyle(
            color: KbColors.text,
            fontWeight: FontWeight.w800,
            letterSpacing: -.15),
        headlineSmall: TextStyle(
            color: KbColors.navy,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4),
        headlineMedium: TextStyle(
            color: KbColors.navy,
            fontWeight: FontWeight.w800,
            letterSpacing: -.55),
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
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: KbColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        labelStyle: const TextStyle(
            color: KbColors.textSecondary, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: KbColors.textMuted),
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KbColors.cyan, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: KbColors.cyan.withValues(alpha: .12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? KbColors.royal : KbColors.textMuted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 10,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
              color: selected ? KbColors.royal : KbColors.textMuted, size: 22);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KbColors.royal,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KbColors.royal,
          side: const BorderSide(color: KbColors.borderStrong),
          minimumSize: const Size(0, 46),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
