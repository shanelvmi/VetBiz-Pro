import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/notification_feed.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_motion.dart';
import '../../theme/theme_context.dart';
import 'notifications_screen.dart';

/// PH8a: the number a bell shows for [count] unread items (NOTIF-2d,
/// docs/design/notifications.md section 3): none at 0, 1 to 9, then "9+".
String? bellCountLabel(int count, AppLocalizations l10n) {
  if (count <= 0) return null;
  return count > BellMetrics.countMax ? l10n.notifications_bellOverNine : '$count';
}

/// PH8a: whether a bell opens the full Notifications page (a phone, or any
/// window narrower than AppBreakpoints.medium, as before) rather than the
/// dropdown anchored to the bell.
bool notificationsOpenAsPage(BuildContext context) =>
    AppLayout.isPhone(context) || MediaQuery.sizeOf(context).width < AppBreakpoints.medium;

/// PH8a: what every notifications bell does when tapped: the full page
/// pushed over everything on a phone (Back returns to the same tab and
/// scroll), the dropdown under [anchorKey] on a wide window. [controller]
/// is for tests; the screen builds its own from the providers otherwise.
Future<void> openNotifications(
  BuildContext context, {
  required GlobalKey anchorKey,
  NotificationFeedController? controller,
}) async {
  if (notificationsOpenAsPage(context)) {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => NotificationsScreen(controller: controller)));
  } else {
    await showAnchoredDropdown(context,
        anchorKey: anchorKey, child: NotificationsScreen(isDropdown: true, controller: controller));
  }
}

/// PH8a: the panel anchored under a bell ([anchorKey]): 400 wide, at most
/// 75% of the window high, kept inside the window, with a transparent
/// barrier so it reads as a dropdown rather than a modal. The Notifications
/// bell and the Products and Stock Store stock-alert bells share it.
///
/// Anchored to the bell's measured position: a bell sits in different places
/// depending on the width (the AppBar's leading on wide screens, its actions
/// on narrow), so this can't assume a fixed corner the way a generic modal
/// could.
Future<void> showAnchoredDropdown(BuildContext context, {required GlobalKey anchorKey, required Widget child}) async {
  final renderBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) return;
  final bellPosition = renderBox.localToGlobal(Offset.zero);
  final bellSize = renderBox.size;
  final screenSize = MediaQuery.of(context).size;

  const panelWidth = BellMetrics.panelWidth;
  // Keeps the panel on-screen if the bell sits close to the right edge -
  // anchors to the bell's left edge by default, but shifts left just enough
  // to stay within the viewport otherwise.
  final left = (bellPosition.dx + panelWidth > screenSize.width - BellMetrics.panelEdge)
      ? screenSize.width - panelWidth - BellMetrics.panelEdge
      : bellPosition.dx;

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.common_notifications,
    barrierColor: Colors.transparent,
    transitionDuration: AppMotion.fast,
    pageBuilder: (context, animation, secondaryAnimation) {
      return Stack(
        children: [
          Positioned(
            top: bellPosition.dy + bellSize.height + BellMetrics.panelGap,
            left: left,
            child: Material(
              elevation: AppElevation.e8,
              borderRadius: BorderRadius.circular(AppRadius.r12),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: panelWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: screenSize.height * BellMetrics.panelMaxHeight),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: BellMetrics.panelEnterScale, end: 1.0).animate(curved),
          alignment: Alignment.topLeft,
          child: child,
        ),
      );
    },
  );
}

/// PH8a: the bell's icon with my unread number on it (none at 0).
class NotificationBellIcon extends StatelessWidget {
  final int count;

  const NotificationBellIcon({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    const icon = Icon(Icons.notifications_outlined);
    final label = bellCountLabel(count, context.l10n);
    if (label == null) return icon;
    final colors = context.colors;
    return Badge(
      key: const ValueKey('bell-count'),
      largeSize: BellMetrics.countHeight,
      backgroundColor: colors.dangerAccent,
      textColor: colors.onPrimary,
      textStyle: const TextStyle(fontSize: BellMetrics.countText),
      label: Text(label),
      child: icon,
    );
  }
}
