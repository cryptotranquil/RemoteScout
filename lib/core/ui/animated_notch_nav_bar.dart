import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedNotchNavBarItem {
  const AnimatedNotchNavBarItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class AnimatedNotchNavBar extends StatefulWidget {
  const AnimatedNotchNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.accentColor,
    required this.backgroundColor,
    required this.inactiveColor,
  })  : assert(items.length > 0),
        assert(currentIndex >= 0 && currentIndex < items.length);

  static const double notchWidth = 68;
  static const double notchDepth = 30;
  static const double bubbleSize = 54;
  static const Duration animationDuration = Duration(milliseconds: 650);

  final List<AnimatedNotchNavBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color accentColor;
  final Color backgroundColor;
  final Color inactiveColor;

  @override
  State<AnimatedNotchNavBar> createState() => _AnimatedNotchNavBarState();
}

class _AnimatedNotchNavBarState extends State<AnimatedNotchNavBar>
    with SingleTickerProviderStateMixin {
  static const double _barHeight = 82;
  static const double _restingBubbleCenterY = 13;
  static const double _liftedBubbleCenterY = -26;

  late final AnimationController _controller;
  late int _settledIndex;
  late int _fromIndex;
  int? _targetIndex;

  double _layoutWidth = 0;
  double _startXFraction = 0;
  double _startY = _restingBubbleCenterY;
  double _startDepth = AnimatedNotchNavBar.notchDepth;
  double _startScaleX = 1;
  double _startScaleY = 1;
  double _startIconOpacity = 1;

  bool get _isAnimating => _targetIndex != null;

  @override
  void initState() {
    super.initState();
    _settledIndex = widget.currentIndex;
    _fromIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: AnimatedNotchNavBar.animationDuration,
    )..addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant AnimatedNotchNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _retarget(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _settledIndex = _targetIndex ?? widget.currentIndex;
      _fromIndex = _settledIndex;
      _targetIndex = null;
    }
  }

  void _retarget(int index) {
    if (index < 0 || index >= widget.items.length) return;

    final current = _motionAt(_controller.value, _layoutWidth);
    _startIconOpacity = _bubbleOpacityAt(_controller.value);
    _fromIndex = _bubbleIconIndexAt(_controller.value);
    _startXFraction = _layoutWidth == 0
        ? (index + 0.5) / widget.items.length
        : current.x / _layoutWidth;
    _startY = current.y;
    _startDepth = current.depth;
    _startScaleX = current.scaleX;
    _startScaleY = current.scaleY;
    _settledIndex = index;
    _targetIndex = index;
    _controller.forward(from: 0);
  }

  void _handleTap(int index) {
    HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  int _bubbleIconIndexAt(double progress) {
    if (!_isAnimating || progress >= 0.7) {
      return _targetIndex ?? _settledIndex;
    }
    return _fromIndex;
  }

  _NavMotion _motionAt(double progress, double width) {
    if (!_isAnimating) {
      final center = width * (_settledIndex + 0.5) / widget.items.length;
      return _NavMotion(
        x: center,
        y: _restingBubbleCenterY,
        depth: AnimatedNotchNavBar.notchDepth,
        scaleX: 1,
        scaleY: 1,
      );
    }

    final destination = width *
        ((_targetIndex ?? widget.currentIndex) + 0.5) /
        widget.items.length;
    final start = width * _startXFraction;

    if (progress < 0.3) {
      final phase = Curves.easeOutCubic.transform(progress / 0.3);
      return _NavMotion(
        x: start,
        y: _lerp(_startY, _liftedBubbleCenterY, phase),
        depth: _lerp(_startDepth, 0, phase),
        scaleX: _lerp(_startScaleX, 1, phase),
        scaleY: _lerp(_startScaleY, 1, phase),
      );
    }

    if (progress < 0.7) {
      final phase = Curves.easeInOutCubic.transform((progress - 0.3) / 0.4);
      final arc = math.sin(math.pi * phase) * 14;
      return _NavMotion(
        x: _lerp(start, destination, phase),
        y: _liftedBubbleCenterY - arc,
        depth: 0,
        scaleX: 1 + math.sin(math.pi * phase) * 0.1,
        scaleY: 1 - math.sin(math.pi * phase) * 0.1,
      );
    }

    final phase = (progress - 0.7) / 0.3;
    final settle = Curves.easeOutCubic.transform(phase);
    final depth =
        Curves.easeOutBack.transform(phase).clamp(0.0, 1.12).toDouble();
    return _NavMotion(
      x: destination,
      y: _lerp(_liftedBubbleCenterY, _restingBubbleCenterY, settle),
      depth: AnimatedNotchNavBar.notchDepth * depth,
      scaleX: _lerp(1, 1, settle),
      scaleY: _lerp(1, 1, settle),
    );
  }

  double _labelSelectionFor(int index, double progress) {
    if (!_isAnimating) return index == _settledIndex ? 1 : 0;

    var amount = 0.0;
    if (index == _fromIndex && progress < 0.3) {
      amount = 1 - Curves.easeOutCubic.transform(progress / 0.3);
    }
    if (index == _targetIndex && progress > 0.7) {
      amount = Curves.easeOutCubic.transform((progress - 0.7) / 0.3);
    }
    return amount;
  }

  double _incomingIconOpacity(double progress) {
    if (!_isAnimating || progress <= 0.7) return 0;
    return Curves.easeOutCubic.transform((progress - 0.7) / 0.3);
  }

  double _outgoingIconOpacity(double progress) {
    if (!_isAnimating || progress >= 0.3) return 0;
    return _startIconOpacity *
        (1 - Curves.easeOutCubic.transform(progress / 0.3));
  }

  double _bubbleOpacityAt(double progress) {
    if (!_isAnimating) return 1;
    if (progress < 0.3) return _outgoingIconOpacity(progress);
    if (progress < 0.7) return 0;
    return _incomingIconOpacity(progress);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelMedium;
    return DecoratedBox(
      decoration: BoxDecoration(color: widget.backgroundColor),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _barHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _layoutWidth = constraints.maxWidth;
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = _controller.value;
                  final motion = _motionAt(progress, constraints.maxWidth);
                  final incomingOpacity = _incomingIconOpacity(progress);
                  final outgoingOpacity = _outgoingIconOpacity(progress);
                  final incomingIndex = _targetIndex ?? _settledIndex;
                  final outgoingIndex = _fromIndex;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _NotchPainter(
                              color: widget.backgroundColor,
                              borderColor: widget.inactiveColor.withAlpha(55),
                              centerX: motion.x,
                              notchWidth: AnimatedNotchNavBar.notchWidth,
                              depth: motion.depth,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Row(
                          children: [
                            for (var index = 0;
                                index < widget.items.length;
                                index++)
                              Expanded(
                                child: _buildItem(
                                  context,
                                  index,
                                  progress,
                                  textStyle,
                                  incomingIndex,
                                  incomingOpacity,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: motion.x - AnimatedNotchNavBar.bubbleSize / 2,
                        top: motion.y - AnimatedNotchNavBar.bubbleSize / 2,
                        width: AnimatedNotchNavBar.bubbleSize,
                        height: AnimatedNotchNavBar.bubbleSize,
                        child: Transform.scale(
                          scaleX: motion.scaleX,
                          scaleY: motion.scaleY,
                          child: _buildBubbleIcon(
                            incomingIndex,
                            outgoingIndex,
                            incomingOpacity,
                            outgoingOpacity,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    int index,
    double progress,
    TextStyle? textStyle,
    int incomingIndex,
    double incomingOpacity,
  ) {
    final item = widget.items[index];
    final selectedAmount = _labelSelectionFor(index, progress);
    final labelColor = Color.lerp(
      widget.inactiveColor,
      widget.accentColor,
      selectedAmount,
    );
    final iconOpacity = _isAnimating
        ? index == incomingIndex
            ? 1 - incomingOpacity
            : 1.0
        : index == _settledIndex
            ? 0.0
            : 1.0;

    return Semantics(
      button: true,
      selected: index == widget.currentIndex,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(index),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: iconOpacity,
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: widget.inactiveColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle?.copyWith(
                    fontSize: 11,
                    color: labelColor,
                    fontWeight: selectedAmount > 0.5
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleIcon(
    int incomingIndex,
    int outgoingIndex,
    double incomingOpacity,
    double outgoingOpacity,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.accentColor,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (outgoingOpacity > 0 && outgoingIndex != incomingIndex)
              Opacity(
                opacity: outgoingOpacity,
                child: Icon(
                  widget.items[outgoingIndex].icon,
                  size: 23,
                  color: Colors.white,
                ),
              ),
            if (incomingOpacity > 0 || outgoingIndex == incomingIndex)
              Opacity(
                opacity: outgoingIndex == incomingIndex ? 1 : incomingOpacity,
                child: Icon(
                  widget.items[incomingIndex].icon,
                  size: 23,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _lerp(double begin, double end, double amount) =>
      begin + (end - begin) * amount;
}

class _NavMotion {
  const _NavMotion({
    required this.x,
    required this.y,
    required this.depth,
    required this.scaleX,
    required this.scaleY,
  });

  final double x;
  final double y;
  final double depth;
  final double scaleX;
  final double scaleY;
}

class _NotchPainter extends CustomPainter {
  const _NotchPainter({
    required this.color,
    required this.borderColor,
    required this.centerX,
    required this.notchWidth,
    required this.depth,
  });

  final Color color;
  final Color borderColor;
  final double centerX;
  final double notchWidth;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final halfWidth = notchWidth / 2;
    final left = (centerX - halfWidth).clamp(0.0, size.width).toDouble();
    final right = (centerX + halfWidth).clamp(0.0, size.width).toDouble();
    final curveWidth = math.max(1.0, right - left).toDouble();
    final shoulder = curveWidth * 0.34;
    final notchDepth =
        depth.clamp(0.0, AnimatedNotchNavBar.notchDepth * 1.12).toDouble();

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(left, 0)
      ..cubicTo(
        left + shoulder,
        0,
        centerX - shoulder,
        notchDepth,
        centerX,
        notchDepth,
      )
      ..cubicTo(
        centerX + shoulder,
        notchDepth,
        right - shoulder,
        0,
        right,
        0,
      )
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawShadow(path, const Color(0x16000000), 4, true);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(left, 0)
        ..cubicTo(
          left + shoulder,
          0,
          centerX - shoulder,
          notchDepth,
          centerX,
          notchDepth,
        )
        ..cubicTo(
          centerX + shoulder,
          notchDepth,
          right - shoulder,
          0,
          right,
          0,
        )
        ..lineTo(size.width, 0),
      Paint()
        ..color = borderColor
        ..strokeWidth = 0.6
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _NotchPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.centerX != centerX ||
      oldDelegate.notchWidth != notchWidth ||
      oldDelegate.depth != depth;
}
