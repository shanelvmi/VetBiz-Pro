import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

/// Builds a [HoverLink.icon]'s icon in the colour of its state.
typedef HoverLinkIconBuilder = Widget Function(Color color);

/// The one clickable text or icon of the signed-out pages (G4): the look
/// the register page's terms links and the login page's Forgot password and
/// Register links had, in one place, so a later restyle changes them all.
///
/// At rest it shows [color] (default `primary`); on mouse hover AND on
/// keyboard focus it turns `accent` and is underlined, and keyboard focus
/// also draws a ring round it. The underline (TextDecoration, or the line
/// kept under an icon) and the ring (painted outside the box) never change
/// its size, so nothing moves. Pointer cursor, Semantics link, Enter or
/// Space opens it, and at least [HoverLinkMetrics.tapTarget] high.
class HoverLink extends StatefulWidget {
  const HoverLink({
    super.key,
    required String this.label,
    required this.onTap,
    this.color,
    this.style,
    this.underlineAtRest = false,
    this.button = false,
  }) : icon = null,
       tooltip = null;

  /// An icon link (the footer's social icons): at least 48 by 48.
  const HoverLink.icon({
    super.key,
    required HoverLinkIconBuilder this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
    this.button = false,
  }) : label = null,
       style = null,
       underlineAtRest = false;

  /// For tests: the ring's painter, and the line under an icon.
  static const focusRingKey = ValueKey<String>('hover-link-focus-ring');
  static const iconUnderlineKey = ValueKey<String>('hover-link-icon-underline');

  final String? label;
  final HoverLinkIconBuilder? icon;
  final VoidCallback onTap;

  /// The resting colour; `primary` when not given.
  final Color? color;

  /// Size and weight of the label; the colour and underline are the link's.
  final TextStyle? style;

  /// A link inside a sentence (the terms line) is underlined at rest too.
  final bool underlineAtRest;

  /// Also announced as a button (it opens a dialog rather than a page).
  final bool button;

  final String? tooltip;

  @override
  State<HoverLink> createState() => _HoverLinkState();
}

class _HoverLinkState extends State<HoverLink> {
  bool _hovered = false;
  bool _focused = false;

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) {
        widget.onTap();
        return null;
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = _hovered || _focused;
    final ink = active ? colors.accent : (widget.color ?? colors.primary);

    final Widget content;
    if (widget.label != null) {
      final underlined = active || widget.underlineAtRest;
      content = Text(
        widget.label!,
        style: (widget.style ?? const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold)).copyWith(
          color: ink,
          decoration: underlined ? TextDecoration.underline : TextDecoration.none,
          decorationColor: ink,
        ),
      );
    } else {
      content = IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.icon!(ink),
            const SizedBox(height: HoverLinkMetrics.iconUnderlineGap),
            SizedBox(
              height: HoverLinkMetrics.iconUnderlineThickness,
              child: ColoredBox(key: HoverLink.iconUnderlineKey, color: active ? ink : ink.withValues(alpha: 0)),
            ),
          ],
        ),
      );
    }

    Widget link = ConstrainedBox(
      constraints: BoxConstraints(minHeight: HoverLinkMetrics.tapTarget, minWidth: widget.icon != null ? HoverLinkMetrics.tapTarget : 0),
      child: Align(
        alignment: widget.icon != null ? Alignment.center : AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: CustomPaint(
          key: HoverLink.focusRingKey,
          foregroundPainter: _focused ? _FocusRingPainter(colors.accent) : null,
          child: content,
        ),
      ),
    );
    if (widget.tooltip != null) link = Tooltip(message: widget.tooltip, excludeFromSemantics: true, child: link);

    // One node: the label, the link flag, tap and focus together.
    return MergeSemantics(
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        actions: _actions,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Semantics(
            link: true,
            button: widget.button,
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: link),
          ),
        ),
      ),
    );
  }
}

/// The keyboard focus ring, a little outside the link's box.
class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).inflate(HoverLinkMetrics.focusRingGap);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(HoverLinkMetrics.focusRingRadius)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = HoverLinkMetrics.focusRingWidth,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) => old.color != color;
}
