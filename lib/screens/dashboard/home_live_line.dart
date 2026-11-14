import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/theme_context.dart';
import 'home_live_event.dart';

export 'home_live_event.dart';

/// HUB3 (2): the live line under the Today card's amount: a small dot
/// (solid while the data connection is live; a muted ring and "Offline"
/// when it is not), then the latest event on one muted line, ending in an
/// ellipsis. Always one line high, with or without an event, so the card
/// never changes size. A new event (another id than the one shown) slides
/// up and fades in with a soft highlight that then fades away; the first
/// one does not, and nothing moves under reduced motion. With the amounts
/// hidden the amount is UI3's four soft dots. A tap runs [onTap] when there
/// is an event.
class HomeLiveLine extends StatefulWidget {
  final HomeLiveEvent? event;
  final bool online;
  final bool amountsHidden;

  /// Whether the role may see the amount of a sale or a payment (both roles
  /// see sales and collections on Home today).
  final bool showAmounts;
  final DateTime Function() now;
  final VoidCallback? onTap;

  const HomeLiveLine({
    super.key,
    required this.event,
    required this.online,
    required this.amountsHidden,
    required this.showAmounts,
    required this.now,
    this.onTap,
  });

  @override
  State<HomeLiveLine> createState() => _HomeLiveLineState();
}

class _HomeLiveLineState extends State<HomeLiveLine> with SingleTickerProviderStateMixin {
  late final AnimationController _arrive = AnimationController(
    vsync: this,
    duration: AppMotion.liveLineArrive,
    value: 1,
  );
  late final Animation<double> _in = CurvedAnimation(
    parent: _arrive,
    curve: const Interval(0, HomeLiveMetrics.slideShare, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _glow = ReverseAnimation(CurvedAnimation(parent: _arrive, curve: Curves.easeIn));

  @override
  void didUpdateWidget(HomeLiveLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.event?.id;
    final now = widget.event?.id;
    if (before != null && now != null && before != now) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _arrive.value = 1;
      } else {
        _arrive.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _arrive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final style = TextStyle(fontSize: PhoneHomeMetrics.label, color: colors.onBrandSurfaceMuted);
    final painter = TextPainter(
      text: TextSpan(text: l10n.home_liveOffline, style: DefaultTextStyle.of(context).style.merge(style)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final lineHeight = painter.height;
    painter.dispose();

    final event = widget.event;
    Widget? text;
    if (event != null) {
      final locale = Localizations.localeOf(context).toLanguageTag();
      final hide = widget.amountsHidden && widget.showAmounts && event.amount != null;
      final line = homeLiveText(
        l10n,
        event,
        now: widget.now(),
        locale: locale,
        showAmount: widget.showAmounts,
        amountMark: hide ? homeLiveAmountMark : null,
      );
      final parts = line.split(homeLiveAmountMark);
      text = Text.rich(
        TextSpan(
          children: [
            if (!widget.online) TextSpan(text: l10n.home_liveOfflineLead(parts.first)) else TextSpan(text: parts.first),
            if (parts.length > 1) ...[
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _HiddenDots(
                  key: const ValueKey('home-live-hidden-amount'),
                  color: style.color!,
                  size: lineHeight,
                ),
              ),
              TextSpan(text: parts.sublist(1).join()),
            ],
          ],
        ),
        key: const ValueKey('home-live-text'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    } else if (!widget.online) {
      text = Text(l10n.home_liveOffline, key: const ValueKey('home-live-text'), maxLines: 1, style: style);
    }

    final dot =
        widget.online
            ? Container(
              key: const ValueKey('home-live-dot'),
              width: HomeLiveMetrics.dot,
              height: HomeLiveMetrics.dot,
              decoration: BoxDecoration(shape: BoxShape.circle, color: colors.onBrandSurface),
            )
            : Container(
              key: const ValueKey('home-live-ring'),
              width: HomeLiveMetrics.dot,
              height: HomeLiveMetrics.dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.onBrandSurfaceMuted, width: HomeLiveMetrics.ringWidth),
              ),
            );

    // Read out as text inside the card's button (All details); the tap is a
    // shortcut for the finger only (one line is no 48 px target), the
    // activity log stays reachable from the profile menu.
    return Semantics(
      container: true,
      child: GestureDetector(
        key: const ValueKey('home-live-line'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: event == null ? null : widget.onTap,
        child: SizedBox(
          height: lineHeight,
          child:
              event == null && widget.online
                  ? const SizedBox.expand()
                  : Row(
                    children: [
                      ExcludeSemantics(child: dot),
                      const SizedBox(width: HomeLiveMetrics.dotGap),
                      Expanded(
                        child: ClipRect(
                          child: AnimatedBuilder(
                            animation: _arrive,
                            builder: (context, child) {
                              final glowing = _arrive.isAnimating;
                              return Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  if (glowing)
                                    Positioned.fill(
                                      key: const ValueKey('home-live-highlight'),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: colors.onBrandSurface.withValues(
                                            alpha: HomeLiveMetrics.highlightAlpha * _glow.value,
                                          ),
                                          borderRadius: BorderRadius.circular(lineHeight / 2),
                                        ),
                                      ),
                                    ),
                                  FadeTransition(
                                    key: const ValueKey('home-live-arrive'),
                                    opacity: _in,
                                    child: Transform.translate(
                                      offset: Offset(0, lineHeight * HomeLiveMetrics.slide * (1 - _in.value)),
                                      child: child,
                                    ),
                                  ),
                                ],
                              );
                            },
                            child: text ?? const SizedBox.shrink(),
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

/// UI3's four soft blurred dots, in a line of text [size] high.
class _HiddenDots extends StatelessWidget {
  final Color color;
  final double size;

  const _HiddenDots({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    final dot = size * PhoneHomeMetrics.maskDot;
    return Semantics(
      label: context.l10n.home_amountHidden,
      excludeSemantics: true,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: PhoneHomeMetrics.maskBlurSmall, sigmaY: PhoneHomeMetrics.maskBlurSmall),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < PhoneHomeMetrics.maskDots; i++) ...[
              if (i > 0) SizedBox(width: dot * PhoneHomeMetrics.maskDotGap),
              SizedBox.square(
                dimension: dot,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: PhoneHomeMetrics.maskAlpha),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// HUB3 (2): the live line fed by an activity stream the dashboard already
/// holds (Recent Activity's; [online] from that listener's metadata). It
/// opens nothing of its own.
class HomeLiveFeed extends StatelessWidget {
  final Stream<HomeLiveEvent?>? events;
  final ValueListenable<bool> online;
  final bool amountsHidden;
  final bool showAmounts;
  final DateTime Function() now;
  final VoidCallback? onTap;

  const HomeLiveFeed({
    super.key,
    required this.events,
    required this.online,
    required this.amountsHidden,
    required this.showAmounts,
    required this.now,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: online,
    builder:
        (context, isOnline, _) => StreamBuilder<HomeLiveEvent?>(
          stream: events,
          builder:
              (context, snapshot) => HomeLiveLine(
                event: snapshot.data,
                online: isOnline,
                amountsHidden: amountsHidden,
                showAmounts: showAmounts,
                now: now,
                onTap: onTap,
              ),
        ),
  );
}
