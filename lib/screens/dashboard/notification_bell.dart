import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/notification_feed.dart';

/// PH8a: the number a bell shows for [count] unread items (NOTIF-2d,
/// docs/design/notifications.md section 3): none at 0, 1 to 9, then "9+".
String? bellCountLabel(int count, AppLocalizations l10n) => throw UnimplementedError();

/// PH8a: whether a bell opens the full Notifications page (a phone, or any
/// window narrower than AppBreakpoints.medium, as before) rather than the
/// dropdown anchored to the bell.
bool notificationsOpenAsPage(BuildContext context) => throw UnimplementedError();

/// PH8a: what every notifications bell does when tapped: the full page
/// pushed over everything on a phone (Back returns to the same tab and
/// scroll), the dropdown under [anchorKey] on a wide window. [controller]
/// is for tests; the screen builds its own from the providers otherwise.
Future<void> openNotifications(
  BuildContext context, {
  required GlobalKey anchorKey,
  NotificationFeedController? controller,
}) => throw UnimplementedError();

/// PH8a: the panel anchored under a bell ([anchorKey]): 400 wide, at most
/// 75% of the window high, kept inside the window, with a transparent
/// barrier so it reads as a dropdown rather than a modal. The Notifications
/// bell and the Products and Stock Store stock-alert bells share it.
Future<void> showAnchoredDropdown(BuildContext context, {required GlobalKey anchorKey, required Widget child}) =>
    throw UnimplementedError();

/// PH8a: the bell's icon with my unread number on it (none at 0).
class NotificationBellIcon extends StatelessWidget {
  final int count;

  const NotificationBellIcon({super.key, required this.count});

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
