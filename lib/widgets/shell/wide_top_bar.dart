import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';

/// LAY2: the wide shell's top bar (computer and tablet), its layout only;
/// the dashboard fills it. [leading] is the sidebar's collapse button (none
/// on the tablet rail or in Layout Fixed Mode).
///
/// The search is at most 260 wide and shrinks when room is short; below
/// [AppBreakpoints.topBarSearchIcon] it is an icon that calls
/// [onSearchIcon] (the dashboard opens the same search in a dialog), so the
/// bell, Help and the profile button always fit (owner, LAY2).
class WideTopBar extends StatelessWidget {
  const WideTopBar({
    super.key,
    this.leading,
    required this.search,
    required this.onSearchIcon,
    required this.trailing,
  });

  static const double height = 72;
  static const double searchMaxWidth = 260;

  final Widget? leading;
  final Widget search;
  final VoidCallback onSearchIcon;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < AppBreakpoints.topBarSearchIcon;
    return Container(
      height: height,
      padding: const EdgeInsets.only(left: AppSpacing.s16, right: AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a20))),
      ),
      child: Row(
        children: [
          if (leading != null) leading!,
          const Spacer(),
          if (narrow)
            IconButton(
              key: const ValueKey('top-bar-search-icon'),
              icon: Icon(Icons.search, color: context.colors.textPrimary, size: AppIconSize.i22),
              tooltip: context.l10n.dashboard_searchProductsOrClients,
              onPressed: onSearchIcon,
            )
          else
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: searchMaxWidth),
                margin: const EdgeInsets.only(right: AppSpacing.s12),
                child: search,
              ),
            ),
          ...trailing,
        ],
      ),
    );
  }
}
