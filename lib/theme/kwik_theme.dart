import 'package:flutter/material.dart';

/// Tungsten Graphene design tokens (PRD §2.1).
/// Single source of truth — screens never hardcode hex values.
abstract final class KwikColors {
  // dark (default)
  static const bg = Color(0xFF0F1110);
  static const surface = Color(0xFF171A18);
  static const surface2 = Color(0xFF1F2421);
  static const border = Color(0xFF2C332F);
  static const accent = Color(0xFFB8F226);
  static const accentDim = Color(0x1FB8F226);
  static const accentOn = Color(0xFF0F1110);
  static const text = Color(0xFFE8ECE9);
  static const muted = Color(0xFF98A39C);
  static const codeBg = Color(0xFF0A0C0B);
  static const danger = Color(0xFFFF5C5C);
  static const info = Color(0xFF4CC9F0);

  // daylight
  static const lBg = Color(0xFFF6F8F7);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurface2 = Color(0xFFEEF1EF);
  static const lBorder = Color(0xFFD5DDD8);
  static const lAccent = Color(0xFF658C08);
  static const lAccentOn = Color(0xFFFFFFFF);
  static const lText = Color(0xFF121513);
  static const lMuted = Color(0xFF5C6861);
  static const lDanger = Color(0xFFD9383A);
  static const lInfo = Color(0xFF0284C7);
}

abstract final class KwikRadius {
  static const card = 16.0;
  static const control = 12.0;
  static const bubble = 18.0;
  static const bubbleTail = 4.0;
  static const pill = 999.0;
}

/// Semantic accessors so widgets read well in both themes:
/// `context.kc.accent`, `context.kc.muted`, …
@immutable
class KwikPalette extends ThemeExtension<KwikPalette> {
  const KwikPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.accent,
    required this.accentDim,
    required this.accentOn,
    required this.text,
    required this.muted,
    required this.codeBg,
    required this.danger,
    required this.info,
  });

  final Color bg, surface, surface2, border, accent, accentDim, accentOn, text, muted, codeBg, danger, info;

  static const dark = KwikPalette(
    bg: KwikColors.bg,
    surface: KwikColors.surface,
    surface2: KwikColors.surface2,
    border: KwikColors.border,
    accent: KwikColors.accent,
    accentDim: KwikColors.accentDim,
    accentOn: KwikColors.accentOn,
    text: KwikColors.text,
    muted: KwikColors.muted,
    codeBg: KwikColors.codeBg,
    danger: KwikColors.danger,
    info: KwikColors.info,
  );

  static const light = KwikPalette(
    bg: KwikColors.lBg,
    surface: KwikColors.lSurface,
    surface2: KwikColors.lSurface2,
    border: KwikColors.lBorder,
    accent: KwikColors.lAccent,
    accentDim: Color(0x1A658C08),
    accentOn: KwikColors.lAccentOn,
    text: KwikColors.lText,
    muted: KwikColors.lMuted,
    codeBg: Color(0xFFF0F3F1),
    danger: KwikColors.lDanger,
    info: KwikColors.lInfo,
  );

  @override
  KwikPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? border,
    Color? accent,
    Color? accentDim,
    Color? accentOn,
    Color? text,
    Color? muted,
    Color? codeBg,
    Color? danger,
    Color? info,
  }) {
    return KwikPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accentDim: accentDim ?? this.accentDim,
      accentOn: accentOn ?? this.accentOn,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      codeBg: codeBg ?? this.codeBg,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  KwikPalette lerp(ThemeExtension<KwikPalette>? other, double t) {
    if (other is! KwikPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return KwikPalette(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      surface2: mix(surface2, other.surface2),
      border: mix(border, other.border),
      accent: mix(accent, other.accent),
      accentDim: mix(accentDim, other.accentDim),
      accentOn: mix(accentOn, other.accentOn),
      text: mix(text, other.text),
      muted: mix(muted, other.muted),
      codeBg: mix(codeBg, other.codeBg),
      danger: mix(danger, other.danger),
      info: mix(info, other.info),
    );
  }
}

extension KwikThemeContext on BuildContext {
  KwikPalette get kc => Theme.of(this).extension<KwikPalette>() ?? KwikPalette.dark;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  double get pagePad => 16.0;
}

abstract final class KwikTheme {
  static ThemeData dark() => _build(Brightness.dark, KwikPalette.dark);
  static ThemeData light() => _build(Brightness.light, KwikPalette.light);

  static ThemeData _build(Brightness brightness, KwikPalette p) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    final textTheme = base.textTheme.apply(
      bodyColor: p.text,
      displayColor: p.text,
      fontFamily: null,
    );

    return base.copyWith(
      brightness: brightness,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: brightness,
      ).copyWith(
        primary: p.accent,
        onPrimary: p.accentOn,
        secondary: p.accent,
        onSecondary: p.accentOn,
        surface: p.surface,
        onSurface: p.text,
        error: p.danger,
        onError: Colors.white,
        outline: p.border,
      ),
      textTheme: textTheme.copyWith(
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
        titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.35),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.accentDim,
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 23, color: selected ? p.accent : p.muted);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface2,
        hintStyle: TextStyle(color: p.muted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KwikRadius.control),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KwikRadius.control),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KwikRadius.control),
          borderSide: BorderSide(color: p.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KwikRadius.control),
          borderSide: BorderSide(color: p.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.accentOn,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KwikRadius.control)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accent),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surface2,
        contentTextStyle: TextStyle(color: p.text, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KwikRadius.control)),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      extensions: [p],
    );
  }
}
