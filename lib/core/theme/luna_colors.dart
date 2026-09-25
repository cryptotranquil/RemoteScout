import 'package:flutter/material.dart';

/// The LUNA palette (see 04_UIUX_Design.md §1).
///
/// The whole app is monochrome-blue: weight/contrast does the signaling.
/// No greens/reds are introduced outside this family.
abstract final class Luna {
  // Core brand ramp.
  static const Color luna100 = Color(0xFFA7EBF2);
  static const Color luna300 = Color(0xFF54ACBF);
  static const Color luna500 = Color(0xFF26658C);
  static const Color luna700 = Color(0xFF023859);
  static const Color luna900 = Color(0xFF011C40);

  // Light-mode neomorphic surface set.
  static const Color baseLight = Color(0xFFEAF7F9);
  static const Color highlightLight = Color(0xFFFFFFFF);
  static const Color shadowLight = Color(0xFFB9D9DE);
  static const Color mutedLight = Color(0xFF4E748C);
  static const Color trackLight = Color(0xFFD7ECF0);

  // Dark-mode neomorphic surface set (base is luna-900).
  static const Color baseDark = luna900;
  static const Color highlightDark = Color(0xFF0B4A73); // lightened luna-700
  static const Color shadowDark = Color(0xFF000814); // near-black navy
  static const Color mutedDark = Color(0xFF86B8C8);
  static const Color trackDark = Color(0xFF022A4D);
}

/// Alpha-composited [color] (modern `Color.withValues`, no deprecated APIs).
Color fade(Color color, double opacity) => color.withValues(alpha: opacity);

int _to255(double channel) => (channel * 255).round().clamp(0, 255);

/// Per-brightness neomorphic material: a flat base surface with a lighter
/// highlight and a darker shadow of the same hue family (Soft UI).
@immutable
class NeuPalette {
  const NeuPalette({
    required this.brightness,
    required this.base,
    required this.highlight,
    required this.shadow,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentSoft,
    required this.track,
  });

  final Brightness brightness;
  final Color base;
  final Color highlight;
  final Color shadow;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color accentSoft;
  final Color track;

  bool get isDark => brightness == Brightness.dark;

  /// Raised (extruded) surface shadows: light top-left, dark bottom-right.
  List<BoxShadow> raised({double blur = 14, double distance = 6}) => [
        BoxShadow(
          color: highlight,
          offset: Offset(-distance, -distance),
          blurRadius: blur,
        ),
        BoxShadow(
          color: shadow,
          offset: Offset(distance, distance),
          blurRadius: blur,
        ),
      ];

  /// Inset (pressed-in) shadows: dark top-left, light bottom-right.
  List<BoxShadow> inset({double blur = 12, double distance = 5}) => [
        BoxShadow(
          color: shadow,
          offset: Offset(-distance, -distance),
          blurRadius: blur,
        ),
        BoxShadow(
          color: highlight,
          offset: Offset(distance, distance),
          blurRadius: blur,
        ),
      ];

  /// Raised shadows for a surface tinted with [color] (primary buttons).
  List<BoxShadow> raisedTinted(Color color, {double blur = 14, double distance = 6}) {
    final light = Color.fromRGBO(
      _to255(color.r + 0.45),
      _to255(color.g + 0.45),
      _to255(color.b + 0.45),
      1,
    );
    final dark = Color.fromRGBO(
      _to255(color.r * 0.35),
      _to255(color.g * 0.35),
      _to255(color.b * 0.35),
      1,
    );
    return [
      BoxShadow(
        color: light,
        offset: Offset(-distance, -distance),
        blurRadius: blur,
      ),
      BoxShadow(
        color: dark,
        offset: Offset(distance, distance),
        blurRadius: blur,
      ),
    ];
  }

  List<BoxShadow> insetTinted(Color color, {double blur = 12, double distance = 5}) {
    final light = Color.fromRGBO(
      _to255(color.r + 0.45),
      _to255(color.g + 0.45),
      _to255(color.b + 0.45),
      1,
    );
    final dark = Color.fromRGBO(
      _to255(color.r * 0.35),
      _to255(color.g * 0.35),
      _to255(color.b * 0.35),
      1,
    );
    return [
      BoxShadow(
        color: dark,
        offset: Offset(-distance, -distance),
        blurRadius: blur,
      ),
      BoxShadow(
        color: light,
        offset: Offset(distance, distance),
        blurRadius: blur,
      ),
    ];
  }

  static const NeuPalette light = NeuPalette(
    brightness: Brightness.light,
    base: Luna.baseLight,
    highlight: Luna.highlightLight,
    shadow: Luna.shadowLight,
    textPrimary: Luna.luna900,
    textSecondary: Luna.mutedLight,
    accent: Luna.luna500,
    accentSoft: Luna.luna300,
    track: Luna.trackLight,
  );

  static const NeuPalette dark = NeuPalette(
    brightness: Brightness.dark,
    base: Luna.baseDark,
    highlight: Luna.highlightDark,
    shadow: Luna.shadowDark,
    textPrimary: Luna.luna100,
    textSecondary: Luna.mutedDark,
    accent: Luna.luna100,
    accentSoft: Luna.luna300,
    track: Luna.trackDark,
  );

  static NeuPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
