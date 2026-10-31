import 'package:flutter/material.dart';

/// Fixed brand values for the RemoteScout "crisp flat" identity.
///
/// Prefer [ScoutColors.of] inside widgets: it resolves the active brightness.
/// These constants exist for places without a [BuildContext] (chart painters,
/// static decoration) and for the light theme's canonical values.
abstract final class Scout {
  static const Color primary = Color(0xFF005454);
  static const Color primaryContainer = Color(0xFF0D6E6E);
  static const Color primaryFixed = Color(0xFFA0F0F0);
  static const Color secondary = Color(0xFF006780);
  static const Color tertiary = Color(0xFF3E4C60);
  static const Color error = Color(0xFFBA1A1A);
  static const Color canvas = Color(0xFFF9F9FF);
  static const Color ink = Color(0xFF141B2B);
}

/// Corner radii used across the app. Geometry is deliberately restrained:
/// badges are near-square, cards are 8, panels are 12.
abstract final class ScoutRadius {
  static const double badge = 3;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double pill = 999;
}

/// 4-point spacing scale (the design uses a 4/8/12/16/24 rhythm).
abstract final class ScoutSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Surface, ink and semantic tones for one brightness.
///
/// Elevation is conveyed by surface contrast and hairline borders only — the
/// system has no drop shadows, gradients or blurs.
@immutable
class ScoutColors extends ThemeExtension<ScoutColors> {
  const ScoutColors({
    required this.brightness,
    required this.surface,
    required this.card,
    required this.surfaceLow,
    required this.surfaceContainer,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.onSurface,
    required this.muted,
    required this.outline,
    required this.outlineVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.primaryFixed,
    required this.onPrimaryFixed,
    required this.secondary,
    required this.secondaryFixed,
    required this.onSecondaryFixed,
    required this.tertiary,
    required this.tertiaryFixed,
    required this.error,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.track,
    required this.onBrand,
  });

  final Brightness brightness;

  /// Screen canvas.
  final Color surface;

  /// Interactive cards, sheets and the app bar.
  final Color card;

  /// Tinted support surface (panel interiors, inset rows).
  final Color surfaceLow;

  /// Tinted chip / idle control surface.
  final Color surfaceContainer;

  /// Stronger tint (toggles, secondary buttons).
  final Color surfaceHigh;

  /// Strongest tint (selected rows).
  final Color surfaceHighest;

  final Color onSurface;
  final Color muted;
  final Color outline;
  final Color outlineVariant;

  /// Deep teal — primary actions, active tabs, prices.
  final Color primary;
  final Color onPrimary;

  /// Slightly lighter teal for secondary calls to action.
  final Color primaryContainer;

  /// Pale teal fill (match badges, selected markers).
  final Color primaryFixed;
  final Color onPrimaryFixed;

  final Color secondary;
  final Color secondaryFixed;
  final Color onSecondaryFixed;

  final Color tertiary;
  final Color tertiaryFixed;

  final Color error;
  final Color errorContainer;
  final Color onErrorContainer;

  /// Slider / progress track.
  final Color track;

  /// Ink used on top of [primary] / [error] fills.
  final Color onBrand;

  bool get isDark => brightness == Brightness.dark;

  static const ScoutColors light = ScoutColors(
    brightness: Brightness.light,
    surface: Color(0xFFF9F9FF),
    card: Color(0xFFFFFFFF),
    surfaceLow: Color(0xFFF1F3FF),
    surfaceContainer: Color(0xFFE9EDFF),
    surfaceHigh: Color(0xFFE1E8FD),
    surfaceHighest: Color(0xFFDCE2F7),
    onSurface: Color(0xFF141B2B),
    muted: Color(0xFF3E4948),
    outline: Color(0xFF6E7979),
    outlineVariant: Color(0xFFBEC9C8),
    primary: Color(0xFF005454),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF0D6E6E),
    primaryFixed: Color(0xFFA0F0F0),
    onPrimaryFixed: Color(0xFF004F50),
    secondary: Color(0xFF006780),
    secondaryFixed: Color(0xFFB7EAFF),
    onSecondaryFixed: Color(0xFF004E61),
    tertiary: Color(0xFF3E4C60),
    tertiaryFixed: Color(0xFFD5E3FC),
    error: Color(0xFFBA1A1A),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    track: Color(0xFFE1E8FD),
    onBrand: Color(0xFFFFFFFF),
  );

  static const ScoutColors dark = ScoutColors(
    brightness: Brightness.dark,
    surface: Color(0xFF0C0E12),
    card: Color(0xFF181A20),
    surfaceLow: Color(0xFF111317),
    surfaceContainer: Color(0xFF1E2229),
    surfaceHigh: Color(0xFF282D38),
    surfaceHighest: Color(0xFF2C3240),
    onSurface: Color(0xFFF8FAFC),
    muted: Color(0xFF94A3B8),
    outline: Color(0xFF64748B),
    outlineVariant: Color(0xFF262A34),
    primary: Color(0xFF14B8A6),
    onPrimary: Color(0xFF04201F),
    primaryContainer: Color(0xFF0D9488),
    primaryFixed: Color(0xFF0F3D3E),
    onPrimaryFixed: Color(0xFF2DD4BF),
    secondary: Color(0xFF22D3EE),
    secondaryFixed: Color(0xFF0E3A46),
    onSecondaryFixed: Color(0xFF7DD3FC),
    tertiary: Color(0xFF2DD4BF),
    tertiaryFixed: Color(0xFF1A383D),
    error: Color(0xFFF87171),
    errorContainer: Color(0xFF3A1519),
    onErrorContainer: Color(0xFFFECACA),
    track: Color(0xFF262A34),
    onBrand: Color(0xFFFFFFFF),
  );

  static ScoutColors of(BuildContext context) =>
      Theme.of(context).extension<ScoutColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  /// Solid fill for selected filter chips and primary buttons.
  Color get brandFill => isDark ? primaryContainer : primary;

  @override
  ScoutColors copyWith({
    Brightness? brightness,
    Color? surface,
    Color? card,
    Color? surfaceLow,
    Color? surfaceContainer,
    Color? surfaceHigh,
    Color? surfaceHighest,
    Color? onSurface,
    Color? muted,
    Color? outline,
    Color? outlineVariant,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? primaryFixed,
    Color? onPrimaryFixed,
    Color? secondary,
    Color? secondaryFixed,
    Color? onSecondaryFixed,
    Color? tertiary,
    Color? tertiaryFixed,
    Color? error,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? track,
    Color? onBrand,
  }) =>
      ScoutColors(
        brightness: brightness ?? this.brightness,
        surface: surface ?? this.surface,
        card: card ?? this.card,
        surfaceLow: surfaceLow ?? this.surfaceLow,
        surfaceContainer: surfaceContainer ?? this.surfaceContainer,
        surfaceHigh: surfaceHigh ?? this.surfaceHigh,
        surfaceHighest: surfaceHighest ?? this.surfaceHighest,
        onSurface: onSurface ?? this.onSurface,
        muted: muted ?? this.muted,
        outline: outline ?? this.outline,
        outlineVariant: outlineVariant ?? this.outlineVariant,
        primary: primary ?? this.primary,
        onPrimary: onPrimary ?? this.onPrimary,
        primaryContainer: primaryContainer ?? this.primaryContainer,
        primaryFixed: primaryFixed ?? this.primaryFixed,
        onPrimaryFixed: onPrimaryFixed ?? this.onPrimaryFixed,
        secondary: secondary ?? this.secondary,
        secondaryFixed: secondaryFixed ?? this.secondaryFixed,
        onSecondaryFixed: onSecondaryFixed ?? this.onSecondaryFixed,
        tertiary: tertiary ?? this.tertiary,
        tertiaryFixed: tertiaryFixed ?? this.tertiaryFixed,
        error: error ?? this.error,
        errorContainer: errorContainer ?? this.errorContainer,
        onErrorContainer: onErrorContainer ?? this.onErrorContainer,
        track: track ?? this.track,
        onBrand: onBrand ?? this.onBrand,
      );

  @override
  ScoutColors lerp(ThemeExtension<ScoutColors>? other, double t) {
    if (other is! ScoutColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return ScoutColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      surface: mix(surface, other.surface),
      card: mix(card, other.card),
      surfaceLow: mix(surfaceLow, other.surfaceLow),
      surfaceContainer: mix(surfaceContainer, other.surfaceContainer),
      surfaceHigh: mix(surfaceHigh, other.surfaceHigh),
      surfaceHighest: mix(surfaceHighest, other.surfaceHighest),
      onSurface: mix(onSurface, other.onSurface),
      muted: mix(muted, other.muted),
      outline: mix(outline, other.outline),
      outlineVariant: mix(outlineVariant, other.outlineVariant),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primaryContainer: mix(primaryContainer, other.primaryContainer),
      primaryFixed: mix(primaryFixed, other.primaryFixed),
      onPrimaryFixed: mix(onPrimaryFixed, other.onPrimaryFixed),
      secondary: mix(secondary, other.secondary),
      secondaryFixed: mix(secondaryFixed, other.secondaryFixed),
      onSecondaryFixed: mix(onSecondaryFixed, other.onSecondaryFixed),
      tertiary: mix(tertiary, other.tertiary),
      tertiaryFixed: mix(tertiaryFixed, other.tertiaryFixed),
      error: mix(error, other.error),
      errorContainer: mix(errorContainer, other.errorContainer),
      onErrorContainer: mix(onErrorContainer, other.onErrorContainer),
      track: mix(track, other.track),
      onBrand: mix(onBrand, other.onBrand),
    );
  }
}

/// Hairline used on cards, sheet edges and the bottom navigation bar.
BorderSide scoutHairline(ScoutColors colors, {double opacity = 1}) =>
    BorderSide(color: colors.outlineVariant.withValues(alpha: opacity));

/// Deterministic two-letter monogram for company tiles and avatars.
String scoutInitials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && !_initialsStopwords.contains(w.toLowerCase()))
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final word = words.first.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (word.isEmpty) return '?';
    return word.length == 1
        ? word.toUpperCase()
        : word.substring(0, 2).toUpperCase();
  }
  final first = words.first.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  final last = words.last.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  final a = first.isEmpty ? '' : first[0];
  final b = last.isEmpty ? '' : last[0];
  return '$a$b'.toUpperCase();
}

const Set<String> _initialsStopwords = {
  'the',
  'and',
  'of',
  'for',
  'inc',
  'llc',
  'ltd',
  'co',
  'gmbh',
};
