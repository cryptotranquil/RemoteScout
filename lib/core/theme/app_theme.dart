import 'package:flutter/material.dart';

import 'luna_colors.dart';
import 'neumorphic.dart';
import 'typography.dart';

/// Builds the LUNA neomorphic theme for [brightness].
ThemeData buildAppTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark ? NeuPalette.dark : NeuPalette.light;
  final textTheme = buildTextTheme(brightness);

  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Luna.luna500,
      brightness: brightness,
      primary: palette.accent,
      surface: palette.base,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: palette.base,
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.base,
      foregroundColor: palette.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleMedium,
    ),
    iconTheme: IconThemeData(color: palette.textPrimary, size: 22),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: palette.textPrimary,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: textTheme.labelSmall?.copyWith(color: palette.base),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.textPrimary,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: palette.base),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.base,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: palette.base,
      hourMinuteColor: palette.track,
      dayPeriodColor: palette.track,
      dialHandColor: palette.accent,
      dialBackgroundColor: palette.track,
      entryModeIconColor: palette.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: palette.base,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
