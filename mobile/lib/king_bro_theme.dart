import 'package:flutter/material.dart';

/// KING BRO TRADE — locked neon glass design system.
/// Branding: Powered by Raaja Bro.
class KbColors {
  static const bgTop = Color(0xFF031820);
  static const bgMid = Color(0xFF06303A);
  static const bgBottom = Color(0xFF04161D);
  static const card = Color(0xD9113440);
  static const cardSoft = Color(0xB8174650);
  static const cardStrong = Color(0xF20A2B35);
  static const border = Color(0x6638EAD9);
  static const borderStrong = Color(0xAA38EAD9);
  static const cyan = Color(0xFF2CF3E8);
  static const emerald = Color(0xFF35F08A);
  static const blueGreen = Color(0xFF20D9C7);
  static const coral = Color(0xFFFF6675);
  static const amber = Color(0xFFFFC857);
  static const text = Color(0xFFF3FFFE);
  static const textSecondary = Color(0xFFB7D9D8);
  static const textMuted = Color(0xFF7FA8A8);
  static const textFaint = Color(0xFF557777);
  static const notice = Color(0xCC173B42);
  static const shadow = Color(0x6600FFD0);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgTop, bgMid, bgBottom],
    stops: [0.0, 0.52, 1.0],
  );
}

class KingBroTheme {
  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: KbColors.emerald,
      brightness: Brightness.dark,
      surface: KbColors.card,
    ).copyWith(
      primary: KbColors.emerald,
      secondary: KbColors.cyan,
      surface: KbColors.card,
      error: KbColors.coral,
      onPrimary: KbColors.bgTop,
      onSecondary: KbColors.bgTop,
      onSurface: KbColors.text,
    );

    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: KbColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: KbColors.bgTop,
      splashColor: KbColors.emerald.withValues(alpha: 0.12),
      highlightColor: KbColors.cyan.withValues(alpha: 0.08),
      dividerColor: KbColors.border,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: KbColors.text),
        bodyMedium: TextStyle(color: KbColors.textSecondary),
        bodySmall: TextStyle(color: KbColors.textMuted),
        titleLarge: TextStyle(color: KbColors.text, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: KbColors.text, fontWeight: FontWeight.w800),
        headlineSmall: TextStyle(color: KbColors.text, fontWeight: FontWeight.w900),
        headlineMedium: TextStyle(color: KbColors.text, fontWeight: FontWeight.w900),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: KbColors.text,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: KbColors.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: KbColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: KbColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KbColors.cardSoft,
        labelStyle: const TextStyle(color: KbColors.textSecondary),
        hintStyle: const TextStyle(color: KbColors.textMuted),
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: KbColors.cyan, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: KbColors.cardStrong,
        indicatorColor: KbColors.emerald.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? KbColors.emerald : KbColors.textMuted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? KbColors.cyan : KbColors.textMuted);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: KbColors.cardSoft,
        selectedColor: KbColors.emerald.withValues(alpha: 0.18),
        side: const BorderSide(color: KbColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(color: KbColors.textSecondary, fontWeight: FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KbColors.emerald,
          foregroundColor: KbColors.bgTop,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: .3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KbColors.cyan,
          side: const BorderSide(color: KbColors.borderStrong),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: KbColors.cardStrong,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: KbColors.borderStrong),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: KbColors.cardStrong,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: KbColors.cyan,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? KbColors.emerald : KbColors.textMuted),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? KbColors.emerald.withValues(alpha: .28)
                : KbColors.cardSoft),
      ),
    );
  }
}
