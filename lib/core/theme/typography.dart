import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'scout_theme.dart';

/// Manrope type ramp.
///
/// Sizes and line heights mirror the design system: 18/24 section titles,
/// 15/20 job titles, 13/18 body, 11/14 labels and 10/12 meta stamps.
TextTheme buildTextTheme(Brightness brightness) {
  final colors =
      brightness == Brightness.dark ? ScoutColors.dark : ScoutColors.light;

  TextStyle style(
    double size,
    FontWeight weight,
    double lineHeight, {
    Color? color,
    double? letterSpacing,
  }) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        height: lineHeight / size,
        color: color ?? colors.onSurface,
        letterSpacing: letterSpacing,
      );

  return TextTheme(
    displaySmall: style(30, FontWeight.w700, 38, letterSpacing: -0.4),
    headlineMedium: style(24, FontWeight.w700, 32, letterSpacing: -0.3),
    headlineSmall: style(22, FontWeight.w600, 28, letterSpacing: -0.2),
    titleLarge: style(18, FontWeight.w600, 24, letterSpacing: -0.1),
    titleMedium: style(16, FontWeight.w600, 22),
    titleSmall: style(15, FontWeight.w600, 20),
    bodyLarge: style(15, FontWeight.w400, 22),
    bodyMedium: style(13, FontWeight.w400, 18),
    bodySmall: style(12, FontWeight.w400, 16, color: colors.muted),
    labelLarge: style(13, FontWeight.w600, 16, letterSpacing: 0.1),
    labelMedium: style(11, FontWeight.w600, 14),
    labelSmall: style(10, FontWeight.w500, 12, color: colors.muted),
  );
}
