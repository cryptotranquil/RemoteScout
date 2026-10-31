import 'package:flutter/material.dart';

import 'scout_theme.dart';
import 'typography.dart';

/// RemoteScout theme: crisp flat surfaces, hairline boundaries, no shadows.
///
/// Elevation comes from surface contrast (`surface` → `card`) and 1px
/// borders, so the whole app stays glare-free and typographically calm.
ThemeData buildAppTheme(Brightness brightness) {
  final colors =
      brightness == Brightness.dark ? ScoutColors.dark : ScoutColors.light;
  final textTheme = buildTextTheme(brightness);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: colors.primary,
    onPrimary: colors.onPrimary,
    primaryContainer: colors.primaryFixed,
    onPrimaryContainer: colors.onPrimaryFixed,
    secondary: colors.secondary,
    onSecondary: colors.onBrand,
    secondaryContainer: colors.secondaryFixed,
    onSecondaryContainer: colors.onSecondaryFixed,
    tertiary: colors.tertiary,
    onTertiary: colors.onBrand,
    error: colors.error,
    onError: colors.onBrand,
    errorContainer: colors.errorContainer,
    onErrorContainer: colors.onErrorContainer,
    surface: colors.surface,
    onSurface: colors.onSurface,
    onSurfaceVariant: colors.muted,
    outline: colors.outline,
    outlineVariant: colors.outlineVariant,
    surfaceContainerLowest: colors.card,
    surfaceContainerLow: colors.surfaceLow,
    surfaceContainer: colors.surfaceContainer,
    surfaceContainerHigh: colors.surfaceHigh,
    surfaceContainerHighest: colors.surfaceHighest,
  );

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.surface,
    canvasColor: colors.surface,
    cardColor: colors.card,
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[colors],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: colors.surfaceLow,
    dividerColor: colors.outlineVariant,
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleMedium,
    ),
    iconTheme: IconThemeData(color: colors.onSurface, size: 22),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.onSurface,
        borderRadius: BorderRadius.circular(ScoutRadius.sm),
      ),
      textStyle: textTheme.labelSmall?.copyWith(color: colors.surface),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.onSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.surface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScoutRadius.md),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScoutRadius.lg),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ScoutRadius.lg),
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.brandFill,
      inactiveTrackColor: colors.track,
      thumbColor: colors.brandFill,
      overlayColor: colors.brandFill.withValues(alpha: 0.12),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),
    checkboxTheme: CheckboxThemeData(
      side: BorderSide(color: colors.outlineVariant, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.brandFill
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(colors.onBrand),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScoutRadius.badge),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primary,
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScoutRadius.sm),
        ),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: colors.card,
      hourMinuteColor: colors.surfaceContainer,
      dayPeriodColor: colors.surfaceContainer,
      dialHandColor: colors.brandFill,
      dialBackgroundColor: colors.surfaceLow,
      entryModeIconColor: colors.onSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScoutRadius.lg),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScoutRadius.lg),
      ),
    ),
  );
}
