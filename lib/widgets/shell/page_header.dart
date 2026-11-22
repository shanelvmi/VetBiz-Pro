import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/polish_metrics.dart';
import '../../theme/theme_context.dart';
import 'app_shell.dart';
import 'shell_banner.dart';

/// UX1a (owner, 2026-11-21): the one page header of the PC/tablet screens,
/// passed as Scaffold.appBar. A white (surface) bar with a hairline under it,
/// the title on the LEFT with an optional one-line subtitle under it, and the
/// screen's actions on the right. No coloured bar, no centred title. The
/// phone keeps its own bars (PhoneListScaffold, AppBar); this is never used
/// there.
///
/// The leading button, in order: [leading] when given; the menu button when
/// the Scaffold has a drawer (Products and Stock Store keep their filter
/// panel as a drawer below 900, as AppBar did); a back arrow only when the
/// page was pushed above another one, never on a destination's own screen in
/// the shell (ShellScope), where the sidebar is the way out. [showBack]
/// overrides the back rule.
///
/// The height is today's page bars' (72), so a screen's body does not move.
class PageHeader extends StatefulWidget implements PreferredSizeWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.actions = const [],
    this.leading,
    this.showBack,
  });

  static const double height = 72;

  final String title;
  final String? subtitle;

  /// UX1b: a line under the title that is not plain text (a report draft's
  /// status dot); used when [subtitle] is null.
  final Widget? subtitleWidget;

  /// The screen's actions, right-aligned, in order. They keep their size; the
  /// title gives way first (an ellipsis). An action wrapped in a Flexible
  /// (Transactions' date range) shrinks with the title, and the actions still
  /// end at the right padding (UX4).
  final List<Widget> actions;
  final Widget? leading;
  final bool? showBack;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  State<PageHeader> createState() => _PageHeaderState();
}

class _PageHeaderState extends State<PageHeader> {
  // UX8b: inside the shell, where the title text ends and the actions start
  // (its title slot's right edge), for the floating subscription banner.
  // Keys on widgets the header already has: no node is added.
  final ShellHeaderKeys _keys = ShellHeaderKeys();
  ShellHeaderSpan? _span;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final span = ShellHeaderScope.maybeOf(context);
    if (span != _span) {
      _span?.unregister(_keys);
      _span = span?..register(_keys);
    }
  }

  @override
  void didUpdateWidget(PageHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title || oldWidget.actions.length != widget.actions.length) _span?.touch();
  }

  @override
  void dispose() {
    _span?.unregister(_keys);
    super.dispose();
  }

  Widget? _leading(BuildContext context) {
    if (widget.leading != null) return widget.leading;
    final scaffold = Scaffold.maybeOf(context);
    // The same DrawerButton (and tooltip) AppBar adds for a drawer.
    if (scaffold != null && scaffold.hasDrawer) return const DrawerButton();
    final back = widget.showBack ?? (!ShellScope.isTopLevel(context) && (ModalRoute.of(context)?.canPop ?? false));
    return back ? const BackButton() : null;
  }

  @override
  Widget build(BuildContext context) {
    final lead = _leading(context);
    return Semantics(
      container: true,
      child: Material(
        color: context.colors.surface,
        child: Container(
          height: PageHeader.height,
          padding: EdgeInsets.only(left: lead == null ? PolishMetrics.pagePadding : AppSpacing.s4, right: AppSpacing.s4),
          // Painted over, not laid out: the row is centred in the full 72 as
          // in the AppBar it replaced (a laid-out border took 1 and moved the
          // bell, and the stock-alerts panel anchored to it, up by 0.5).
          foregroundDecoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.colors.divider, width: PolishMetrics.hairline)),
          ),
          child: IconTheme.merge(
            data: IconThemeData(color: context.colors.textPrimary),
            child: Row(
              children: [
                if (lead != null) ...[lead, const SizedBox(width: AppSpacing.s8)],
                // UX4: without a flex action the plain Row already ends the actions at the
                // right padding (and keeps the tree every wide fingerprint recorded).
                if (widget.actions.any((a) => a is Flexible))
                  Expanded(child: _TitleAndActions(title: _title(context), actions: widget.actions))
                else ...[
                  Expanded(child: _title(context)),
                  ...widget.actions,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(BuildContext context) => Column(
    key: _span == null ? null : _keys.slot,
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        key: _span == null ? null : _keys.title,
        header: true,
        child: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: AppFontWeight.bold,
            fontSize: AppFontSize.f19,
            color: context.colors.textPrimary,
          ),
        ),
      ),
      if (widget.subtitle != null)
        Text(
          widget.subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary),
        )
      else if (widget.subtitleWidget != null)
        widget.subtitleWidget!,
    ],
  );
}

/// UX4: the title and the actions, laid out as the Row of Expanded(title) +
/// actions was (the same flex split: a Flexible action and the title share
/// what the fixed actions leave, by flex), except that what a loose Flexible
/// action does not use goes to the title, not to a gap after the actions. In
/// the Row, Transactions' date range left its unused half there and the
/// buttons sat left of the right edge. The actions now always end at the
/// header's right padding; the range still gives way first in a narrow bar.
class _TitleAndActions extends StatelessWidget {
  const _TitleAndActions({required this.title, required this.actions});

  final Widget title;
  final List<Widget> actions;

  static const Object _titleId = 'title';

  @override
  Widget build(BuildContext context) {
    final flexes = <int?>[];
    final fits = <FlexFit>[];
    final children = <Widget>[LayoutId(id: _titleId, child: title)];
    for (var i = 0; i < actions.length; i++) {
      final a = actions[i];
      flexes.add(a is Flexible ? a.flex : null);
      fits.add(a is Flexible ? a.fit : FlexFit.loose);
      children.add(LayoutId(id: i, child: a is Flexible ? a.child : a));
    }
    return CustomMultiChildLayout(
      delegate: _TitleAndActionsDelegate(flexes, fits, Directionality.of(context)),
      children: children,
    );
  }
}

class _TitleAndActionsDelegate extends MultiChildLayoutDelegate {
  _TitleAndActionsDelegate(this.flexes, this.fits, this.direction);

  /// Per action: its flex when it was a Flexible, else null (fixed size).
  final List<int?> flexes;
  final List<FlexFit> fits;
  final TextDirection direction;

  @override
  void performLayout(Size size) {
    final widths = List<double>.filled(flexes.length, 0);
    final heights = List<double>.filled(flexes.length, 0);
    final loose = BoxConstraints(maxHeight: size.height);
    var fixed = 0.0;
    var totalFlex = 1; // the title's (Expanded, flex 1)
    for (var i = 0; i < flexes.length; i++) {
      final flex = flexes[i];
      if (flex == null) {
        final s = layoutChild(i, loose);
        widths[i] = s.width;
        heights[i] = s.height;
        fixed += s.width;
      } else {
        totalFlex += flex;
      }
    }
    final free = math.max(0.0, size.width - fixed);
    var used = fixed;
    for (var i = 0; i < flexes.length; i++) {
      final flex = flexes[i];
      if (flex == null) continue;
      final share = free * flex / totalFlex;
      final s = layoutChild(
        i,
        fits[i] == FlexFit.tight ? loose.copyWith(minWidth: share, maxWidth: share) : loose.copyWith(maxWidth: share),
      );
      widths[i] = s.width;
      heights[i] = s.height;
      used += s.width;
    }
    final titleWidth = math.max(0.0, size.width - used);
    final titleSize = layoutChild(
      _TitleAndActions._titleId,
      loose.copyWith(minWidth: titleWidth, maxWidth: titleWidth),
    );
    final rtl = direction == TextDirection.rtl;
    positionChild(
      _TitleAndActions._titleId,
      Offset(rtl ? size.width - titleWidth : 0, (size.height - titleSize.height) / 2),
    );
    // The actions in order after the title, the last at the right edge.
    var x = titleWidth;
    for (var i = 0; i < flexes.length; i++) {
      positionChild(i, Offset(rtl ? size.width - x - widths[i] : x, (size.height - heights[i]) / 2));
      x += widths[i];
    }
  }

  @override
  bool shouldRelayout(_TitleAndActionsDelegate old) =>
      !listEquals(old.flexes, flexes) || !listEquals(old.fits, fits) || old.direction != direction;
}
