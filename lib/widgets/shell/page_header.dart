import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/polish_metrics.dart';
import '../../theme/theme_context.dart';
import 'app_shell.dart';

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
class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.showBack,
  });

  static const double height = 72;

  final String title;
  final String? subtitle;

  /// The screen's actions, right-aligned, in order. They keep their size; the
  /// title gives way first (an ellipsis). An action wrapped in a Flexible
  /// (Transactions' date range) shrinks with the title.
  final List<Widget> actions;
  final Widget? leading;
  final bool? showBack;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  Widget? _leading(BuildContext context) {
    if (leading != null) return leading;
    final scaffold = Scaffold.maybeOf(context);
    // The same DrawerButton (and tooltip) AppBar adds for a drawer.
    if (scaffold != null && scaffold.hasDrawer) return const DrawerButton();
    final back = showBack ?? (!ShellScope.isTopLevel(context) && (ModalRoute.of(context)?.canPop ?? false));
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
          height: height,
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
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary),
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary),
                        ),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
