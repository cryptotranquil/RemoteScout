import 'package:flutter/material.dart';

import '../theme/scout_theme.dart';

export '../theme/scout_theme.dart';

/// ---------------------------------------------------------------------------
/// JobRadar component kit.
///
/// One visual language everywhere: pure surfaces, hairline boundaries, near
/// square badges and 8dp cards. Nothing here draws a shadow.
/// ---------------------------------------------------------------------------

/// App bar used by every tab: brand mark, screen name, sync stamp and the
/// account avatar. Detail screens pass [onBack] instead of the sync stamp.
class ScoutAppHeader extends StatelessWidget {
  const ScoutAppHeader({
    super.key,
    this.title = 'JobRadar',
    this.subtitle,
    this.onBack,
    this.actions = const <Widget>[],
    this.avatarName,
    this.showStatusDot = true,
    this.onAvatarTap,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final String? avatarName;
  final bool showStatusDot;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ScoutSpace.lg),
        child: Row(
          children: [
            if (onBack != null) ...[
              ScoutIconButton(
                icon: Icons.arrow_back,
                onPressed: onBack,
                tooltip: 'Back',
                size: 40,
                ghost: true,
              ),
              const SizedBox(width: ScoutSpace.xs),
            ],
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.brandFill,
                borderRadius: BorderRadius.circular(ScoutRadius.md),
              ),
              child: Icon(Icons.radar, size: 18, color: colors.onBrand),
            ),
            const SizedBox(width: ScoutSpace.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall,
                    ),
                ],
              ),
            ),
            ...actions,
            if (avatarName != null) ...[
              if (showStatusDot) ...[
                const SizedBox(width: ScoutSpace.sm),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: ScoutSpace.sm),
              if (onAvatarTap == null)
                ScoutAvatar(name: avatarName!, size: 32)
              else
                GestureDetector(
                  onTap: onAvatarTap,
                  child: ScoutAvatar(name: avatarName!, size: 32),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

void showFeedRefreshFeedback(
  BuildContext context, {
  required bool isLive,
  required int fetched,
  required int inserted,
  required int duplicatesDiscarded,
  required int storedJobs,
  required int visibleJobs,
  required List<String> errors,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final message = !isLive
      ? 'Job sources were not contacted.'
      : storedJobs > visibleJobs
          ? 'Supabase has $storedJobs jobs, but this app can read only '
              '$visibleJobs. Check the sign-in and read policy.'
          : errors.isNotEmpty
              ? 'Refresh found $fetched eligible jobs and added '
                  '$inserted, with ${errors.length} issue'
                  '${errors.length == 1 ? '' : 's'}.'
              : fetched == 0
                  ? 'Supabase returned 0 eligible jobs.'
                  : inserted == 0
                      ? 'Checked $fetched eligible jobs; none were new.'
                      : 'Added $inserted new jobs from $fetched eligible listings.';
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: errors.isEmpty
          ? null
          : SnackBarAction(
              label: 'Details',
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Refresh details'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (isLive)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Fetched $fetched; inserted $inserted; '
                                'discarded as duplicates $duplicatesDiscarded; '
                                'stored in Supabase $storedJobs; '
                                'visible to app $visibleJobs.',
                              ),
                            ),
                          for (final error in errors)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(error),
                            ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
    ),
  );
}

/// Monogram avatar — deterministic, offline, no remote images required.
class ScoutAvatar extends StatelessWidget {
  const ScoutAvatar({
    super.key,
    required this.name,
    this.size = 32,
    this.squared = false,
    this.tone,
  });

  final String name;
  final double size;
  final bool squared;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final fill = tone ?? colors.primaryFixed;
    final ink = tone == null ? colors.onPrimaryFixed : colors.onBrand;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: squared ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: squared ? BorderRadius.circular(ScoutRadius.md) : null,
      ),
      child: Text(
        scoutInitials(name),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: ink,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

/// Company tile used on job and application cards.
class ScoutMonogram extends StatelessWidget {
  const ScoutMonogram({
    super.key,
    required this.label,
    this.size = 32,
    this.tone,
    this.fill,
  });

  final String label;
  final double size;
  final Color? tone;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill ?? colors.surfaceContainer,
        borderRadius:
            BorderRadius.circular(size >= 32 ? ScoutRadius.md : ScoutRadius.sm),
      ),
      child: Text(
        scoutInitials(label),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tone ?? colors.primary,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Flat card. Set [border] for standalone cards on the canvas; leave it off
/// for lists where surface contrast is enough.
class ScoutCard extends StatelessWidget {
  const ScoutCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ScoutSpace.md),
    this.margin,
    this.radius = ScoutRadius.md,
    this.inset = false,
    this.onTap,
    this.onLongPress,
    this.border = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final bool inset;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool border;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final decoration = BoxDecoration(
      color: color ?? (inset ? colors.surfaceLow : colors.card),
      borderRadius: BorderRadius.circular(radius),
      border: border ? Border.all(color: colors.outlineVariant) : null,
    );
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: child,
    );
    if (onTap == null && onLongPress == null) return content;
    return Padding(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ),
      ),
    );
  }
}

enum ScoutButtonVariant { primary, tonal, text, danger }

/// Flat action button. [filled] is kept for older call sites and maps to the
/// primary (or danger) variant.
class ScoutButton extends StatelessWidget {
  const ScoutButton({
    super.key,
    this.label,
    this.child,
    required this.onPressed,
    this.variant = ScoutButtonVariant.tonal,
    this.filled = false,
    this.expand = true,
    this.padding,
    this.radius = ScoutRadius.md,
    this.insetStyle = false,
    this.icon,
    this.trailingIcon,
    this.dense = false,
  });

  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final ScoutButtonVariant variant;
  final bool filled;
  final bool expand;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool insetStyle;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool dense;

  ScoutButtonVariant get _resolvedVariant {
    if (filled) {
      return variant == ScoutButtonVariant.tonal
          ? ScoutButtonVariant.primary
          : variant;
    }
    return variant;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    final enabled = onPressed != null;
    final tone = _resolvedVariant;

    Color background;
    Color foreground;
    BorderSide? border;

    switch (tone) {
      case ScoutButtonVariant.primary:
        background = colors.brandFill;
        foreground = colors.onBrand;
      case ScoutButtonVariant.danger:
        background = colors.error;
        foreground = colors.onBrand;
      case ScoutButtonVariant.text:
        background = Colors.transparent;
        foreground = colors.primary;
      case ScoutButtonVariant.tonal:
        background = insetStyle ? colors.surfaceHigh : colors.surfaceContainer;
        foreground = colors.onSurface;
        if (colors.isDark) border = BorderSide(color: colors.outlineVariant);
    }
    if (!enabled) {
      background = colors.surfaceContainer;
      foreground = colors.muted;
      border = null;
    }

    final content = DefaultTextStyle(
      style: text.labelLarge!.copyWith(color: foreground),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 16 : 18, color: foreground),
            const SizedBox(width: 6),
          ],
          if (child != null)
            Flexible(child: child!)
          else
            Flexible(
              child: Text(
                label ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 6),
            Icon(trailingIcon, size: dense ? 14 : 16, color: foreground),
          ],
        ],
      ),
    );

    final button = Material(
      color: background,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          constraints: BoxConstraints(minHeight: dense ? 32 : 44),
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: dense ? ScoutSpace.sm + 2 : ScoutSpace.md,
                vertical: dense ? ScoutSpace.xs : ScoutSpace.sm + 2,
              ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: border == null ? null : Border.fromBorderSide(border),
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Square icon button used in headers, cards and the pinned action bar.
class ScoutIconButton extends StatelessWidget {
  const ScoutIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    this.inset = false,
    this.ghost = false,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final bool inset;
  final bool ghost;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final enabled = onPressed != null;
    final background = filled
        ? colors.brandFill
        : ghost || inset
            ? Colors.transparent
            : colors.surfaceContainer;
    final foreground = filled
        ? colors.onBrand
        : enabled
            ? colors.onSurface
            : colors.outline;

    final button = Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(ScoutRadius.md),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(ScoutRadius.md),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.45, color: foreground),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Hairline text field — 44dp tall, white/card surface, sharp focus border.
class ScoutInput extends StatelessWidget {
  const ScoutInput({
    super.key,
    this.controller,
    this.hint,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.prefixIcon,
    this.enabled = true,
    this.radius = ScoutRadius.md,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? hint;
  final int maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final IconData? prefixIcon;
  final bool enabled;
  final double radius;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.only(
        left: prefixIcon == null ? ScoutSpace.md : ScoutSpace.sm,
        right: suffix == null ? ScoutSpace.md : ScoutSpace.xs,
        top: maxLines > 1 ? ScoutSpace.sm : 0,
        bottom: maxLines > 1 ? ScoutSpace.sm : 0,
      ),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: enabled ? colors.card : colors.surfaceLow,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, size: 18, color: colors.muted),
            const SizedBox(width: ScoutSpace.sm),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              minLines: minLines,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              obscureText: obscureText,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              enabled: enabled,
              autofocus: autofocus,
              cursorColor: colors.primary,
              style: text.bodyLarge!.copyWith(color: colors.onSurface),
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: text.bodyLarge!.copyWith(color: colors.outline),
              ),
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}

/// Compact teal switch (36×20) used in preference rows.
class ScoutSwitch extends StatelessWidget {
  const ScoutSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: 38,
              height: 22,
              padding: const EdgeInsets.all(3),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? colors.brandFill : colors.surfaceHigh,
                borderRadius: BorderRadius.circular(ScoutRadius.pill),
                border: Border.all(
                  color: value ? colors.brandFill : colors.outlineVariant,
                ),
              ),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: value ? colors.onBrand : colors.card,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filter / selection chip. Selected chips are solid teal, idle chips are
/// white with a hairline.
class ScoutFilterPill extends StatelessWidget {
  const ScoutFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 32 : 34),
          padding: const EdgeInsets.symmetric(
            horizontal: ScoutSpace.md,
            vertical: ScoutSpace.xs,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.brandFill : colors.card,
            borderRadius: BorderRadius.circular(ScoutRadius.md),
            border: Border.all(
              color: selected
                  ? colors.brandFill
                  : colors.isDark
                      ? colors.outlineVariant
                      : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? colors.onBrand : colors.muted,
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium!.copyWith(
                    color: selected ? colors.onBrand : colors.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum ScoutBadgeTone { solid, tonal, soft, warning, info, outline }

/// Near-square metadata badge (match %, location, status).
class ScoutBadge extends StatelessWidget {
  const ScoutBadge({
    super.key,
    required this.label,
    this.tone = ScoutBadgeTone.tonal,
    this.icon,
    this.height = 22,
  });

  final String label;
  final ScoutBadgeTone tone;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;

    Color background;
    Color foreground;
    Border? border;

    switch (tone) {
      case ScoutBadgeTone.solid:
        background = colors.brandFill;
        foreground = colors.onBrand;
      case ScoutBadgeTone.soft:
        background = colors.primaryFixed;
        foreground = colors.onPrimaryFixed;
      case ScoutBadgeTone.warning:
        background = colors.errorContainer;
        foreground = colors.onErrorContainer;
      case ScoutBadgeTone.info:
        background = colors.secondaryFixed;
        foreground = colors.onSecondaryFixed;
      case ScoutBadgeTone.outline:
        background = Colors.transparent;
        foreground = colors.muted;
        border = Border.all(color: colors.outlineVariant);
      case ScoutBadgeTone.tonal:
        background = colors.surfaceHigh;
        foreground = colors.muted;
    }

    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.symmetric(
        horizontal: ScoutSpace.sm,
        vertical: ScoutSpace.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ScoutRadius.badge),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium!.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uppercased quiet section label (11/14, tracked 0.05em).
class ScoutSectionLabel extends StatelessWidget {
  const ScoutSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final label = Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium!.copyWith(
            color: colors.muted,
            letterSpacing: 0.6,
          ),
    );
    if (trailing == null) return label;
    return Row(
      children: [Expanded(child: label), trailing!],
    );
  }
}

/// Horizontal status pills used by the application form (keeps the
/// `status-<label>` keys that the tracker tests rely on).
class ScoutStepper extends StatelessWidget {
  const ScoutStepper({
    super.key,
    required this.steps,
    required this.currentIndex,
    required this.onTap,
  });

  final List<String> steps;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: steps.length,
        separatorBuilder: (_, __) => const SizedBox(width: ScoutSpace.xs + 2),
        itemBuilder: (context, i) {
          final active = i == currentIndex;
          return Center(
            child: GestureDetector(
              key: ValueKey('status-${steps[i]}'),
              onTap: () => onTap(i),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: ScoutSpace.md),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? colors.brandFill : colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(ScoutRadius.md),
                ),
                child: Text(
                  steps[i],
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(
                        color: active ? colors.onBrand : colors.muted,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Segmented 5-step progress bar (onboarding).
class ScoutStepProgress extends StatelessWidget {
  const ScoutStepProgress({
    super.key,
    required this.total,
    required this.current,
  });

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i <= current ? colors.brandFill : colors.surfaceHighest,
                borderRadius: BorderRadius.circular(ScoutRadius.badge),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Backwards-compatible alias for the onboarding stepper.
class ScoutProgressDots extends StatelessWidget {
  const ScoutProgressDots({
    super.key,
    required this.total,
    required this.current,
  });

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) =>
      ScoutStepProgress(total: total, current: current);
}

/// Screen heading with optional subtitle and trailing action.
class ScoutScreenHeader extends StatelessWidget {
  const ScoutScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleStyle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle ?? text.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: text.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Location eligibility badge — explicit on every job row.
class ScoutLocationBadge extends StatelessWidget {
  const ScoutLocationBadge({
    super.key,
    required this.scope,
    required this.detail,
  });

  /// 'worldwide' | 'region_restricted' | 'country_restricted'
  final String scope;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final worldwide = scope == 'worldwide';
    final label = worldwide
        ? 'Worldwide'
        : scope == 'region_restricted'
            ? 'Region-restricted'
            : 'Country-restricted';
    return Tooltip(
      message: detail,
      child: ScoutBadge(
        label: label,
        tone: ScoutBadgeTone.tonal,
        icon: worldwide ? Icons.public : Icons.lock_outline,
      ),
    );
  }
}

/// Source attribution ("via Remotive") — required on every job row.
class ScoutSourceBadge extends StatelessWidget {
  const ScoutSourceBadge({super.key, required this.source});

  final String source;

  String get label {
    switch (source) {
      case 'remotive':
        return 'via Remotive';
      case 'remoteok':
        return 'via Remote OK';
      case 'himalayas':
        return 'via Himalayas';
      case 'jobicy':
        return 'via Jobicy';
      case 'arbeitnow':
        return 'via Arbeitnow';
      case 'adzuna':
        return 'via Adzuna';
      case 'jooble':
        return 'via Jooble';
      case 'themuse':
        return 'via The Muse';
      case 'findwork':
        return 'via Findwork';
      case 'weworkremotely':
        return 'via We Work Remotely';
      case 'manual':
        return 'manual entry';
      default:
        return 'via $source';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: ScoutColors.of(context).muted,
          ),
    );
  }
}

/// Skill chip — matched skills read as filled, gaps as outline.
class ScoutSkillChip extends StatelessWidget {
  const ScoutSkillChip({
    super.key,
    required this.label,
    required this.matched,
  });

  final String label;
  final bool matched;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          right: ScoutSpace.xs + 2, bottom: ScoutSpace.xs + 2),
      child: ScoutBadge(
        label: matched ? label : '?  $label',
        tone: matched ? ScoutBadgeTone.soft : ScoutBadgeTone.tonal,
      ),
    );
  }
}

/// Centered empty state (shortlist exhausted, nothing saved, …).
class ScoutEmptyState extends StatelessWidget {
  const ScoutEmptyState({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ScoutSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.surfaceLow,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: colors.muted),
              ),
              const SizedBox(height: ScoutSpace.lg),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium!.copyWith(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1px hairline divider with the system spacing around it.
class ScoutDivider extends StatelessWidget {
  const ScoutDivider({super.key, this.verticalPadding = 0});

  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child:
          Container(height: 1, color: ScoutColors.of(context).outlineVariant),
    );
  }
}

/// Section heading with a leading icon — used inside preference panels.
class ScoutSectionHeader extends StatelessWidget {
  const ScoutSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: colors.muted),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.labelLarge),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Filled tinted notice (match reasoning, source health, guarantees).
class ScoutNotice extends StatelessWidget {
  const ScoutNotice({
    super.key,
    required this.child,
    this.icon,
    this.tone = ScoutBadgeTone.tonal,
    this.padding = const EdgeInsets.all(ScoutSpace.sm + 2),
  });

  final Widget child;
  final IconData? icon;
  final ScoutBadgeTone tone;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    Color background;
    Color foreground;
    switch (tone) {
      case ScoutBadgeTone.soft:
        background =
            colors.primaryFixed.withValues(alpha: colors.isDark ? 1 : 0.5);
        foreground = colors.onPrimaryFixed;
      case ScoutBadgeTone.warning:
        background =
            colors.errorContainer.withValues(alpha: colors.isDark ? 1 : 0.45);
        foreground = colors.onErrorContainer;
      case ScoutBadgeTone.info:
        background =
            colors.secondaryFixed.withValues(alpha: colors.isDark ? 1 : 0.4);
        foreground = colors.onSecondaryFixed;
      case ScoutBadgeTone.solid:
      case ScoutBadgeTone.outline:
      case ScoutBadgeTone.tonal:
        background = colors.surfaceLow;
        foreground = colors.muted;
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ScoutRadius.sm),
        border: colors.isDark ? Border.all(color: colors.outlineVariant) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: ScoutSpace.sm),
          ],
          Expanded(
            child: DefaultTextStyle(
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: foreground),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Metadata pill row helper — keeps chips aligned and wraps cleanly.
class ScoutBadgeWrap extends StatelessWidget {
  const ScoutBadgeWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ScoutSpace.xs + 2,
      runSpacing: ScoutSpace.xs + 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// Text button styled as a quiet inline action.
class ScoutTextAction extends StatelessWidget {
  const ScoutTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(ScoutRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ScoutSpace.xs,
          vertical: ScoutSpace.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium!
                  .copyWith(color: colors.primary),
            ),
            if (icon != null) ...[
              const SizedBox(width: 2),
              Icon(icon, size: 14, color: colors.primary),
            ],
          ],
        ),
      ),
    );
  }
}
