import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_dimens.dart';
import '../theme/app_motion.dart';
import '../theme/polish_metrics.dart';
import '../theme/theme_context.dart';

/// LAY6a: how a record screen shows a record's details beside its list.
enum DetailsMode {
  /// The panel beside the list at every width (the record screens before
  /// LAY6a).
  inline,

  /// Beside the list when the width this layout is given (the content's, not
  /// the window's) is at least [AppBreakpoints.medium]; narrower, the panel
  /// slides over the list from the right, with the list dimmed behind it.
  auto,
}

/// LAY6a (owner, 2026-11-18): the list and its details panel. Opt-in: a
/// screen that passes [DetailsMode.inline] gets the Row it had (Expanded
/// list, a 1 px divider, the panel at [detailsWidth]).
///
/// The slide-over is a dialog-like region named [label] (the panel's own
/// title): it enters from the right (AppMotion.normal, none under reduced
/// motion), is at most [detailsWidth] or 90 % of the width, has a hairline
/// edge and no shadow, and closes with the panel's own close button or a tap
/// on the dimmed list (labelled Close). Focus moves into it when it opens and
/// back to what had it (the row) when it closes.
class DetailsLayout extends StatefulWidget {
  const DetailsLayout({
    super.key,
    required this.list,
    required this.details,
    required this.detailsWidth,
    required this.onClose,
    required this.label,
    this.mode = DetailsMode.inline,
  });

  final Widget list;

  /// The open record's panel, or null when none is open.
  final Widget? details;
  final double detailsWidth;
  final VoidCallback onClose;
  final String label;
  final DetailsMode mode;

  @override
  State<DetailsLayout> createState() => _DetailsLayoutState();
}

class _DetailsLayoutState extends State<DetailsLayout> {
  final FocusScopeNode _panelScope = FocusScopeNode(debugLabel: 'details-slide-over');
  FocusNode? _returnTo;

  /// Whether the last build slid the panel over (focus moves into it then).
  bool _slidOver = false;

  @override
  void didUpdateWidget(DetailsLayout old) {
    super.didUpdateWidget(old);
    if (old.details == null && widget.details != null) {
      _returnTo = FocusManager.instance.primaryFocus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _slidOver && widget.details != null) _panelScope.requestFocus();
      });
    } else if (old.details != null && widget.details == null) {
      final back = _returnTo;
      _returnTo = null;
      if (back != null && back.context != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (back.context != null) back.requestFocus();
        });
      }
    }
  }

  @override
  void dispose() {
    _panelScope.dispose();
    super.dispose();
  }

  Widget _inline() {
    _slidOver = false;
    final details = widget.details;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: widget.list),
        if (details != null) ...[
          const VerticalDivider(width: 1),
          SizedBox(width: widget.detailsWidth, child: details),
        ],
      ],
    );
  }

  Widget _slideOver(double width) {
    _slidOver = true;
    final details = widget.details;
    final reduce = MediaQuery.of(context).disableAnimations;
    final duration = reduce ? Duration.zero : AppMotion.normal;
    final panelWidth = math.min(widget.detailsWidth, width * DetailsLayoutMetrics.slideOverMaxFactor);
    return Stack(
      children: [
        Positioned.fill(child: widget.list),
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: duration,
            layoutBuilder: _fill,
            child: details == null
                ? const SizedBox.shrink(key: ValueKey('details-slide-over-none'))
                : Semantics(
                    key: const ValueKey('details-slide-over-scrim'),
                    button: true,
                    label: context.l10n.common_close,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onClose,
                      child: ColoredBox(color: context.colors.scrim.withValues(alpha: AppAlpha.a50)),
                    ),
                  ),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: panelWidth,
          child: AnimatedSwitcher(
            duration: duration,
            layoutBuilder: _fill,
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
            child: details == null
                ? const SizedBox.shrink(key: ValueKey('details-slide-over-closed'))
                : Semantics(
                    key: const ValueKey('details-slide-over'),
                    scopesRoute: true,
                    namesRoute: true,
                    explicitChildNodes: true,
                    label: widget.label,
                    child: FocusScope(
                      node: _panelScope,
                      autofocus: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          border: Border(left: BorderSide(color: context.colors.divider, width: PolishMetrics.hairline)),
                        ),
                        child: details,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// The switcher's children fill its slot (the default centres them
  /// loosely, which would shrink the scrim and the panel to their content).
  static Widget _fill(Widget? current, List<Widget> previous) =>
      Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]);

  @override
  Widget build(BuildContext context) {
    if (widget.mode == DetailsMode.inline) return _inline();
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= AppBreakpoints.medium ? _inline() : _slideOver(constraints.maxWidth),
    );
  }
}
