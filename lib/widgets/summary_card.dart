import 'package:flutter/material.dart';

/// The result of comparing a KPI's current-period value against the
/// immediately preceding equivalent period, plus the business-meaning
/// context needed to color it correctly - a rising number isn't always
/// a good outcome (rising expenses or outstanding debt is the opposite
/// of rising sales or profit), so this carries [higherIsBetter] rather
/// than SummaryCard guessing from the raw sign alone.
class KpiTrend {
  final double currentValue;
  final double previousValue;
  final bool higherIsBetter;

  /// e.g. "vs Yesterday", "vs Last Week", "vs Last Month", "vs Last Year".
  final String comparisonLabel;

  /// Formats an absolute delta the same way the card's own `value` is
  /// formatted (e.g. "Tsh 45,000" for money, "3" for a plain count) -
  /// passed in rather than guessed, since SummaryCard has no way to
  /// know which formatting a given KPI uses on its own.
  final String Function(double) formatChange;

  /// The previous-period fetch is still in flight - the trend is
  /// suppressed entirely while this is true, rather than briefly
  /// showing an incorrect comparison against a default/zero value
  /// before the real one arrives.
  final bool isLoading;

  const KpiTrend({
    required this.currentValue,
    required this.previousValue,
    required this.higherIsBetter,
    required this.comparisonLabel,
    required this.formatChange,
    this.isLoading = false,
  });

  double get absoluteChange => currentValue - previousValue;

  // Previous period had genuinely nothing to compare against - shown
  // as "New" rather than a nonsensical infinite percentage, and rather
  // than crashing on the division by zero a naive percentage
  // calculation would hit here.
  bool get isNewActivity => previousValue == 0 && currentValue != 0;

  // Both periods were exactly zero - nothing meaningfully changed,
  // shown as no indicator at all rather than a technically-true but
  // meaningless "0% change".
  bool get hasNoChange => previousValue == 0 && currentValue == 0;

  double get percent => previousValue == 0 ? 0 : (absoluteChange / previousValue) * 100;

  bool get isPositive => higherIsBetter ? absoluteChange >= 0 : absoluteChange <= 0;
}

class SummaryCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool shadow; // new parameter
  final String? subtitle; // optional small caption, e.g. a period label
  // or "as of now" - lets a card clarify what the figure means without
  // needing a second widget.
  final bool isLoading; // shows a small spinner in place of the value

  // Null (the default) shows no trend at all - existing callers
  // (transactions_screen.dart) that don't pass this keep working
  // exactly as before.
  final KpiTrend? trend;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.shadow = false, // default false
    this.subtitle,
    this.isLoading = false,
    this.trend,
  });

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    // Ramps up quickly (15% of the duration) then fades slowly (the
    // remaining 85%) - reads as a brief flash rather than a slow
    // build-up, keeping this short and unobtrusive.
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 85),
    ]).animate(_pulseController);
  }

  @override
  void didUpdateWidget(SummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only pulses on a genuine change between two already-loaded
    // states - this naturally excludes the initial "loading -> first
    // real value" transition (oldWidget.isLoading would be true
    // there), while still catching a real live update after a new
    // transaction/sale/product/client/debt is recorded elsewhere in
    // the app and this card's underlying value changes as a result.
    if (!oldWidget.isLoading && !widget.isLoading && oldWidget.value != widget.value) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glow = _glowAnimation.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: glow > 0
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.45 * glow),
                      blurRadius: 14 * glow,
                      spreadRadius: 1.5 * glow,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Card(
        elevation: widget.shadow ? 6 : 2, // uses shadow parameter
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Scale down based on the card's OWN rendered width - this way
            // it stays readable whether it's in a 2-column grid on a small
            // phone or a 4-column grid on a desktop, without the parent
            // screen needing to know anything about it.
            final isCompact = constraints.maxWidth < 160;
            final avatarRadius = isCompact ? 16.0 : 20.0;
            final titleSize = isCompact ? 11.0 : 12.0;
            final valueSize = isCompact ? 12.0 : 14.0;

        return Padding(
              padding: EdgeInsets.all(isCompact ? 8 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: widget.color.withValues(alpha: 0.2),
                    child: Icon(widget.icon, color: widget.color, size: avatarRadius),
                  ),
                  SizedBox(width: isCompact ? 8 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          textAlign: TextAlign.start,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: titleSize,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (widget.isLoading)
                          SizedBox(
                            height: valueSize + 4,
                            width: valueSize + 4,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.color,
                            ),
                          )
                        else
                          // FittedBox instead of ellipsis for the value: a
                          // truncated money figure ("Tsh 12,345,6...") could be
                          // dangerously misleading - shrinking it to fit is safer
                          // than cutting characters off.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.value,
                              textAlign: TextAlign.start,
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: valueSize,
                              ),
                            ),
                          ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            textAlign: TextAlign.start,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isCompact ? 9 : 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (!widget.isLoading &&
                            widget.trend != null &&
                            !widget.trend!.isLoading &&
                            !widget.trend!.hasNoChange) ...[
                          SizedBox(height: isCompact ? 3 : 4),
                          _TrendPill(trend: widget.trend!, compact: isCompact),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The compact, tinted pill showing a KPI's trend at a glance - just
/// the direction and percentage, with the comparison period and exact
/// absolute change available via tooltip rather than always taking up
/// card space every card would otherwise need for it.
class _TrendPill extends StatefulWidget {
  final KpiTrend trend;
  final bool compact;
  const _TrendPill({required this.trend, required this.compact});

  @override
  State<_TrendPill> createState() => _TrendPillState();
}

class _TrendPillState extends State<_TrendPill> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // A slow, gentle, continuous float - subtle enough not to be
    // distracting with several of these animating on screen at once,
    // but enough to read as "live" rather than a static icon.
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const Color _positiveColor = Color(0xFF10B981);
  static const Color _negativeColor = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final trend = widget.trend;
    final isPositive = trend.isNewActivity ? true : trend.isPositive;
    final tintColor = isPositive ? _positiveColor : _negativeColor;
    final arrowIcon = trend.isNewActivity
        ? Icons.fiber_new_rounded
        : (trend.absoluteChange >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);
    final label = trend.isNewActivity ? 'New' : '${trend.percent.abs().toStringAsFixed(1)}%';
    final fontSize = widget.compact ? 9.5 : 10.5;
    final iconSize = widget.compact ? 11.0 : 12.0;

    final changeText = trend.absoluteChange >= 0
        ? '+${trend.formatChange(trend.absoluteChange)}'
        : '-${trend.formatChange(trend.absoluteChange.abs())}';

    return Tooltip(
      message: '${trend.comparisonLabel}: $changeText',
      waitDuration: const Duration(milliseconds: 400),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: widget.compact ? 6 : 8, vertical: widget.compact ? 2 : 3),
        decoration: BoxDecoration(
          color: tintColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tintColor.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trend.isNewActivity)
              Icon(arrowIcon, color: tintColor, size: iconSize)
            else
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Floats toward the direction the arrow already
                  // points - an up arrow drifts gently upward and
                  // back, a down arrow drifts gently downward and
                  // back.
                  final direction = trend.absoluteChange >= 0 ? -1.0 : 1.0;
                  final offset = Tween<double>(begin: 0, end: 2.2 * direction).transform(_controller.value);
                  return Transform.translate(
                    offset: Offset(0, offset),
                    child: child,
                  );
                },
                child: Icon(arrowIcon, color: tintColor, size: iconSize),
              ),
            SizedBox(width: widget.compact ? 2 : 3),
            Text(
              label,
              style: TextStyle(color: tintColor, fontWeight: FontWeight.bold, fontSize: fontSize),
            ),
          ],
        ),
      ),
    );
  }
}
