import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_timeouts.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// UX8b (owner): the subscription banner on PC and tablet floats over the top
/// of the shell's content; it takes no layout space, so every page lays out
/// exactly as with no banner. (UX7 had it in the layout, under the top bar,
/// which pushed every page down.)
///
/// Where it sits: in the free middle of the current page's header (between
/// the end of the title's text and the start of the header actions, as the
/// header reports them through [ShellHeaderSpan]), centred on the content
/// when it fits there, else centred in the free gap. When the full pill does
/// not fit, a compact chip (icon, Renew, Close; the full sentence in a
/// tooltip). When even the chip does not fit, the chip under the header, over
/// the top sliver of the page. A page with no header (Home): centred at the
/// top.
///
/// Close, or [AppTimeouts.shellBannerIdle] without a hover or a tap, fades it
/// out (no fade under reduced motion) and calls [ShellBannerSpec.onDismissed];
/// the caller decides when it comes back.
class ShellBannerSpec {
  const ShellBannerSpec({
    required this.identity,
    required this.message,
    required this.icon,
    required this.accent,
    required this.fill,
    required this.onDismissed,
    this.actionLabel,
    this.onAction,
    this.note,
  });

  /// What is told (the status): a new one restarts the idle timer.
  final Object identity;
  final String message;
  final IconData icon;

  /// The icon, the action and the border.
  final Color accent;
  final Color fill;

  /// Renew / View plans (admins); null for an assistant, who gets [note].
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? note;

  /// Closed, or faded out after the idle time.
  final VoidCallback onDismissed;
}

/// Where the current page's header has its title text and its actions, in
/// the content area's coordinates. Each [PageHeader] inside the shell
/// registers its keys; the host measures the current route's after a frame.
class ShellHeaderSpan extends ChangeNotifier {
  final _headers = <ShellHeaderKeys>[];

  void register(ShellHeaderKeys keys) {
    if (_headers.contains(keys)) return;
    _headers.add(keys);
    _notifyLater();
  }

  void unregister(ShellHeaderKeys keys) {
    if (_headers.remove(keys)) _notifyLater();
  }

  /// A header's title changed: measure again.
  void touch() => _notifyLater();

  var _pending = false;
  void _notifyLater() {
    if (_pending) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      // The shell may have gone meanwhile (its headers unregister as it goes).
      if (!_disposed) notifyListeners();
    });
  }

  var _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// The current route's header, if one is on screen.
  ShellHeaderKeys? get current {
    for (final h in _headers.reversed) {
      final context = h.title.currentContext;
      if (context == null || !context.mounted) continue;
      if (ModalRoute.of(context)?.isCurrent ?? true) return h;
    }
    return null;
  }
}

/// A page header's two measuring points: its title text, and the title's
/// slot (whose right edge is where the actions start).
class ShellHeaderKeys {
  final title = GlobalKey(debugLabel: 'shell-header-title');
  final slot = GlobalKey(debugLabel: 'shell-header-slot');
}

/// Gives the pages inside the shell its [ShellHeaderSpan].
class ShellHeaderScope extends InheritedWidget {
  const ShellHeaderScope({super.key, required this.span, required super.child});

  final ShellHeaderSpan span;

  static ShellHeaderSpan? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellHeaderScope>()?.span;

  @override
  bool updateShouldNotify(ShellHeaderScope oldWidget) => span != oldWidget.span;
}

/// The free middle of a header: [left] and [right] in the content area, and
/// the header's [bottom]. None: no header (all the width is free).
typedef HeaderGap = ({double left, double right, double bottom});

/// Where the banner goes and in which form.
typedef BannerPlacement = ({double left, double top, bool compact});

/// The placement rule (UX8b), on its own so tests can check it.
BannerPlacement placeShellBanner({
  required double areaWidth,
  required double fullWidth,
  required double chipWidth,
  HeaderGap? header,
}) {
  final center = areaWidth / 2;
  const h = ShellBannerMetrics.height;
  if (header == null) {
    final fits = fullWidth <= areaWidth - 2 * ShellBannerMetrics.sideGap;
    final w = fits ? fullWidth : chipWidth;
    return (left: center - w / 2, top: ShellBannerMetrics.belowHeaderGap, compact: !fits);
  }
  final from = header.left + ShellBannerMetrics.sideGap;
  final to = header.right - ShellBannerMetrics.sideGap;
  final top = (header.bottom - h) / 2;
  double? fit(double w) {
    if (w > to - from) return null;
    // Centred on the content when the gap allows it, else in the gap.
    final x = center - w / 2;
    if (x >= from && x + w <= to) return x;
    return from + (to - from - w) / 2;
  }

  final full = fit(fullWidth);
  if (full != null) return (left: full, top: top, compact: false);
  final chip = fit(chipWidth);
  if (chip != null) return (left: chip, top: top, compact: true);
  return (left: center - chipWidth / 2, top: header.bottom + ShellBannerMetrics.belowHeaderGap, compact: true);
}

/// The banner over the content area (a child of the content's Stack).
class ShellBannerHost extends StatefulWidget {
  const ShellBannerHost({super.key, required this.spec, required this.span, required this.areaKey});

  final ShellBannerSpec? spec;
  final ShellHeaderSpan span;

  /// The content area's box: the coordinates the header is measured in.
  final GlobalKey areaKey;

  @override
  State<ShellBannerHost> createState() => _ShellBannerHostState();
}

class _ShellBannerHostState extends State<ShellBannerHost> {
  HeaderGap? _gap;
  Timer? _idle;
  bool _fading = false;
  Object? _shownFor;

  @override
  void initState() {
    super.initState();
    widget.span.addListener(_measureSoon);
    _restart();
  }

  @override
  void didUpdateWidget(ShellBannerHost old) {
    super.didUpdateWidget(old);
    if (old.span != widget.span) {
      old.span.removeListener(_measureSoon);
      widget.span.addListener(_measureSoon);
    }
    if (widget.spec?.identity != _shownFor) _restart();
  }

  @override
  void dispose() {
    widget.span.removeListener(_measureSoon);
    _idle?.cancel();
    super.dispose();
  }

  /// A new status (or none): visible again, the idle time from now.
  void _restart() {
    _shownFor = widget.spec?.identity;
    _fading = false;
    _idle?.cancel();
    if (widget.spec != null) _idle = Timer(AppTimeouts.shellBannerIdle, _dismiss);
  }

  /// A hover or a tap: the idle time starts again.
  void _interacted() {
    if (_fading || widget.spec == null) return;
    _idle?.cancel();
    _idle = Timer(AppTimeouts.shellBannerIdle, _dismiss);
  }

  void _dismiss() {
    _idle?.cancel();
    final spec = widget.spec;
    if (spec == null || _fading || !mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      spec.onDismissed();
      return;
    }
    setState(() => _fading = true);
  }

  void _measureSoon() {
    if (mounted) setState(() {});
  }

  /// The current header's free middle, in the content area.
  HeaderGap? _measure() {
    final area = widget.areaKey.currentContext?.findRenderObject() as RenderBox?;
    final keys = widget.span.current;
    final title = keys?.title.currentContext?.findRenderObject() as RenderBox?;
    final slot = keys?.slot.currentContext?.findRenderObject() as RenderBox?;
    if (area == null || title == null || slot == null || !title.attached || !slot.attached) return null;
    if (!title.hasSize || !slot.hasSize) return null;
    final titleAt = title.localToGlobal(Offset.zero, ancestor: area);
    final slotAt = slot.localToGlobal(Offset.zero, ancestor: area);
    final headerBox = slot.size.height;
    return (
      left: titleAt.dx + title.size.width,
      right: slotAt.dx + slot.size.width,
      bottom: slotAt.dy + headerBox,
    );
  }

  double _textWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    // Measured after this frame: the header is laid out by then.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final gap = _measure();
      if (gap != _gap) setState(() => _gap = gap);
    });
    if (spec == null) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, constraints) {
      final colors = context.colors;
      final messageStyle = TextStyle(color: colors.textPrimary, fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold);
      final actionStyle = TextStyle(
          color: spec.accent, fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.bold, decoration: TextDecoration.underline);
      final noteStyle = TextStyle(color: colors.textMuted, fontSize: AppFontSize.f11_5, fontStyle: FontStyle.italic);
      const pad = AppSpacing.s14;
      const iconGap = AppSpacing.s6;
      final action = spec.actionLabel == null ? 0.0 : _textWidth(spec.actionLabel!, actionStyle) + 2 * AppSpacing.s8;
      final note = spec.note == null ? 0.0 : AppSpacing.s8 + _textWidth(spec.note!, noteStyle);
      final chipWidth = pad + AppIconSize.i16 + iconGap + action + ShellBannerMetrics.height;
      final fullWidth = (chipWidth + _textWidth(spec.message, messageStyle) + AppSpacing.s8 + note)
          .clamp(0.0, ShellBannerMetrics.maxWidth);
      final placed = placeShellBanner(
        areaWidth: constraints.maxWidth,
        fullWidth: fullWidth,
        chipWidth: chipWidth,
        header: _gap,
      );
      final pill = _Pill(
        spec: spec,
        compact: placed.compact,
        messageStyle: messageStyle,
        actionStyle: actionStyle,
        noteStyle: noteStyle,
        onClose: _dismiss,
      );
      final faded = AnimatedOpacity(
        opacity: _fading ? 0 : 1,
        duration: AppMotion.slow,
        onEnd: () {
          if (_fading) spec.onDismissed();
        },
        child: pill,
      );
      return Stack(
        children: [
          Positioned(
            left: placed.left,
            top: placed.top,
            width: placed.compact ? chipWidth : fullWidth,
            height: ShellBannerMetrics.height,
            child: MouseRegion(
              onEnter: (_) => _interacted(),
              onHover: (_) => _interacted(),
              child: Listener(onPointerDown: (_) => _interacted(), child: faded),
            ),
          ),
        ],
      );
    });
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.spec,
    required this.compact,
    required this.messageStyle,
    required this.actionStyle,
    required this.noteStyle,
    required this.onClose,
  });

  final ShellBannerSpec spec;
  final bool compact;
  final TextStyle messageStyle;
  final TextStyle actionStyle;
  final TextStyle noteStyle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final row = Row(
      children: [
        Icon(spec.icon, color: spec.accent, size: AppIconSize.i16),
        const SizedBox(width: AppSpacing.s6),
        if (!compact) ...[
          Expanded(child: Text(spec.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: messageStyle)),
          if (spec.note != null) ...[
            const SizedBox(width: AppSpacing.s8),
            Text(spec.note!, maxLines: 1, style: noteStyle),
          ],
        ],
        if (spec.actionLabel != null)
          InkWell(
            key: const ValueKey('shell-banner-action'),
            onTap: spec.onAction,
            borderRadius: BorderRadius.circular(AppRadius.r12),
            child: Container(
              height: ShellBannerMetrics.height,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
              child: Text(spec.actionLabel!, maxLines: 1, style: actionStyle),
            ),
          ),
        InkWell(
          key: const ValueKey('shell-banner-close'),
          onTap: onClose,
          customBorder: const CircleBorder(),
          child: Tooltip(
            message: context.l10n.common_close,
            child: SizedBox.square(
              dimension: ShellBannerMetrics.height,
              child: Icon(Icons.close, size: AppIconSize.i16, color: colors.textHint),
            ),
          ),
        ),
      ],
    );
    final pill = Container(
      key: ValueKey(compact ? 'shell-banner-chip' : 'shell-banner-full'),
      padding: const EdgeInsets.only(left: AppSpacing.s14),
      decoration: BoxDecoration(
        // Flat: the fill and a hairline border in the accent; no shadow.
        color: spec.fill,
        borderRadius: BorderRadius.circular(AppRadius.r24),
      ),
      // Painted over, not laid out: Renew and Close keep their full 44.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.r24),
        border: Border.all(color: spec.accent.withValues(alpha: AppAlpha.a40)),
      ),
      child: row,
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: compact ? spec.message : null,
      child: compact ? Tooltip(message: spec.message, child: pill) : pill,
    );
  }
}
