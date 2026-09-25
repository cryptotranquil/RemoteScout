import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'luna_colors.dart';

/// Typography: Poppins for headings, Inter for body, tabular figures
/// for match scores and salaries (04_UIUX_Design.md §3).
TextTheme buildTextTheme(Brightness brightness) {
  final color = brightness == Brightness.dark ? Luna.luna100 : Luna.luna900;
  final base = brightness == Brightness.dark
      ? GoogleFonts.interTextTheme(Typography.whiteMountainView)
      : GoogleFonts.interTextTheme(Typography.blackMountainView);

  TextStyle tabular(TextStyle? s) => s!.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  return base.copyWith(
    displaySmall: GoogleFonts.poppins(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.15,
    ),
    headlineSmall: GoogleFonts.poppins(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.2,
    ),
    titleLarge: GoogleFonts.poppins(
      fontSize: 19,
      fontWeight: FontWeight.w600,
      color: color,
    ),
    titleMedium: GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: color,
    ),
    titleSmall: tabular(base.titleSmall?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: color,
    )),
    bodyLarge: base.bodyLarge?.copyWith(color: color, height: 1.45),
    bodyMedium: base.bodyMedium?.copyWith(color: color, height: 1.45),
    bodySmall: base.bodySmall?.copyWith(
      color: brightness == Brightness.dark ? Luna.mutedDark : Luna.mutedLight,
      height: 1.4,
    ),
    labelLarge: base.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w600),
    labelMedium: tabular(base.labelMedium?.copyWith(color: color)),
    labelSmall: tabular(base.labelSmall?.copyWith(color: color)),
  );
}
