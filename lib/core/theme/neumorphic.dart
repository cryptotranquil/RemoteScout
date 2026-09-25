import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'luna_colors.dart';

export 'luna_colors.dart';

/// Core neomorphic (Soft UI) component kit — see 04_UIUX_Design.md §2.
///
/// Signature interaction: buttons invert from *raised* to *inset* on press
/// (~120ms) instead of changing color. Depth effects are kept restrained on
/// small elements and reserved for cards, buttons and primary inputs.
class NeuCard extends StatefulWidget {
  const NeuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.radius = 22,
    this.inset = false,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final bool inset;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<NeuCard> createState() => _NeuCardState();
}

class _NeuCardState extends State<NeuCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final inset = widget.inset || _pressed;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOut,
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: palette.base,
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: inset
            ? palette.inset(blur: 10, distance: 4)
            : palette.raised(blur: 14, distance: 6),
      ),
      child: widget.child,
    );
    if (widget.onTap == null && widget.onLongPress == null) return card;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: card,
    );
  }
}

/// Pill-shaped soft button. Pressed state inverts to an inset shadow.
/// Minimum tap target is 44dp regardless of the visual footprint.
class NeuButton extends StatefulWidget {
  const NeuButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    this.radius = 30,
    this.filled = false,
    this.expand = true,
    this.insetStyle = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Primary action style: luna-500 surface with light text.
  final bool filled;

  /// Stretch to the available width (full-width CTAs).
  final bool expand;

  /// Render with inset shadows even when idle (toggles, selected states).
  final bool insetStyle;

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final enabled = widget.onPressed != null;
    final surface = widget.filled
        ? (palette.isDark ? Luna.luna700 : Luna.luna500)
        : palette.base;
    final content = widget.filled
        ? (palette.isDark ? Luna.luna100 : Luna.luna100)
        : palette.textPrimary;

    List<BoxShadow> shadows() {
      if (!enabled) return [];
      // Press inverts raised↔inset; [insetStyle] starts already pressed in.
      final down = _pressed != widget.insetStyle;
      if (widget.filled) {
        return down
            ? palette.insetTinted(surface, blur: 10, distance: 4)
            : palette.raisedTinted(surface, blur: 14, distance: 6);
      }
      return down
          ? palette.inset(blur: 10, distance: 4)
          : palette.raised(blur: 14, distance: 6);
    }

    final button = GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minHeight: 48),
        padding: widget.padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? surface : palette.base,
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: shadows(),
        ),
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: enabled ? content : palette.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
          child: widget.child,
        ),
      ),
    );
    return widget.expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Circular soft icon button (Save / Reject / Report …).
class NeuIconButton extends StatelessWidget {
  const NeuIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 52,
    this.inset = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final button = NeuButton(
      onPressed: onPressed,
      expand: false,
      insetStyle: inset,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: size * 0.42, color: palette.textPrimary),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Inset (concave) text field — reads as pressed into the surface.
class NeuInput extends StatelessWidget {
  const NeuInput({
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
    this.enabled = true,
    this.radius = 18,
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
  final bool enabled;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: palette.base,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: palette.inset(blur: 10, distance: 4),
      ),
      child: Row(
        children: [
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
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(color: palette.textPrimary),
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: Theme.of(context)
                    .textTheme
                    .bodyLarge!
                    .copyWith(color: palette.textSecondary),
              ),
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}

/// Soft pill track + raised thumb; on-state shifts thumb toward luna-500.
class NeuToggle extends StatelessWidget {
  const NeuToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: 72,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 60,
              height: 34,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: palette.base,
                borderRadius: BorderRadius.circular(20),
                boxShadow: palette.inset(blur: 8, distance: 3),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: value ? Luna.luna500 : palette.base,
                    shape: BoxShape.circle,
                    boxShadow: value
                        ? palette.raisedTinted(Luna.luna500, blur: 8, distance: 3)
                        : palette.raised(blur: 8, distance: 3),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft filter pill. Active pill is shown *inset* (per design spec).
class NeuPill extends StatelessWidget {
  const NeuPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: palette.base,
          borderRadius: BorderRadius.circular(22),
          boxShadow: selected
              ? palette.inset(blur: 8, distance: 3)
              : palette.raised(blur: 10, distance: 4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: selected ? palette.accent : palette.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: selected ? palette.accent : palette.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Match-score band color: low → luna-300, mid → luna-500,
/// high (≥80) → luna-500 at full saturation with a subtle glow.
Color scoreBandColor(int score) {
  if (score >= 80) return Luna.luna500;
  if (score >= 50) return Luna.luna500;
  return Luna.luna300;
}

/// Circular soft-extruded badge with the match percentage in the center.
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 56});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final band = scoreBandColor(score.clamp(0, 100));
    final high = score >= 80;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.base,
        shape: BoxShape.circle,
        boxShadow: [
          ...palette.raised(blur: 10, distance: 4),
          if (high)
            BoxShadow(
              color: fade(Luna.luna500, 0.35),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: CustomPaint(
        painter: _ScoreRingPainter(
          band: band,
          track: palette.track,
          progress: (score.clamp(0, 100)) / 100,
        ),
        child: Center(
          child: Text(
            '$score%',
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  _ScoreRingPainter({
    required this.band,
    required this.track,
    required this.progress,
  });

  final Color band;
  final Color track;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 5;
    const stroke = 4.0;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = band;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.band != band ||
      oldDelegate.track != track;
}

/// Soft-inset progress dots (onboarding stepper) in an inset track.
class NeuProgressDots extends StatelessWidget {
  const NeuProgressDots({
    super.key,
    required this.total,
    required this.current,
  });

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Container(
      height: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: palette.base,
        borderRadius: BorderRadius.circular(8),
        boxShadow: palette.inset(blur: 6, distance: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(total, (i) {
          final active = i <= current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: active ? 10 : 8,
            height: active ? 10 : 8,
            decoration: BoxDecoration(
              color: active ? Luna.luna500 : palette.base,
              shape: BoxShape.circle,
              boxShadow: active
                  ? []
                  : [BoxShadow(color: palette.shadow, blurRadius: 2)],
            ),
          );
        }),
      ),
    );
  }
}

/// Horizontal soft status stepper (application pipeline).
class NeuStepper extends StatelessWidget {
  const NeuStepper({
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
    final palette = NeuPalette.of(context);
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: steps.length,
        separatorBuilder: (_, __) => Center(
          child: Container(
            width: 10,
            height: 2,
            color: palette.track,
          ),
        ),
        itemBuilder: (context, i) {
          final done = i < currentIndex;
          final active = i == currentIndex;
          return GestureDetector(
            key: ValueKey('status-${steps[i]}'),
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.base,
                borderRadius: BorderRadius.circular(20),
                boxShadow: active
                    ? palette.inset(blur: 8, distance: 3)
                    : palette.raised(blur: 10, distance: 4),
              ),
              child: Text(
                steps[i],
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: active
                          ? palette.accent
                          : done
                              ? palette.textPrimary
                              : palette.textSecondary,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Location eligibility badge — always explicit on every job card.
class LocationBadge extends StatelessWidget {
  const LocationBadge({super.key, required this.scope, required this.detail});

  /// 'worldwide' | 'region_restricted' | 'country_restricted'
  final String scope;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final worldwide = scope == 'worldwide';
    final label = worldwide
        ? 'Worldwide'
        : scope == 'region_restricted'
            ? 'Region-restricted'
            : 'Country-restricted';
    return Tooltip(
      message: detail,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: palette.base,
          borderRadius: BorderRadius.circular(14),
          boxShadow: palette.inset(blur: 6, distance: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              worldwide ? Icons.public : Icons.lock_outline,
              size: 14,
              color: palette.accent,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Source attribution chip ("via Remotive") — required on every job card.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source});

  final String source;

  String get _label {
    switch (source) {
      case 'remotive':
        return 'via Remotive';
      case 'remoteok':
        return 'via Remote OK';
      case 'manual':
        return 'manual entry';
      default:
        return 'via $source';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Text(
      _label,
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: palette.textSecondary,
            fontWeight: FontWeight.w500,
          ),
    );
  }
}

/// Quiet section label used inside soft cards.
class NeuSectionLabel extends StatelessWidget {
  const NeuSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}
