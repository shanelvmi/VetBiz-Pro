import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/notification_policy.dart';
import '../services/notification_feed.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

/// What a notification's more menu (and its swipes) can do (NOTIF-2c).
enum NotificationAction { markRead, markUnread, remove, open }

/// Why a persistent notification has no Remove, in the current language.
String persistentReasonLabel(AppLocalizations l, PersistentReason reason) => switch (reason) {
      PersistentReason.untilRenewed => l.notifications_reasonUntilRenewed,
      PersistentReason.untilTrialEnds => l.notifications_reasonUntilTrialEnds,
      PersistentReason.untilDecided => l.notifications_reasonUntilDecided,
      PersistentReason.untilNewClaim => l.notifications_reasonUntilNewClaim,
    };

/// The three dots on every row: Mark as read or unread (whichever
/// applies), Open when the row links to a record, and Remove - or, on a
/// persistent row, an inactive line saying why it stays.
class NotificationMoreButton extends StatelessWidget {
  final NotificationRowFacts item;
  final ValueChanged<NotificationAction> onSelected;

  /// Whether Open has somewhere to go (notificationTargetScreen).
  final bool canOpen;

  /// The icon's colour; the row's muted text colour when null.
  final Color? color;

  const NotificationMoreButton({super.key, required this.item, required this.onSelected, required this.canOpen, this.color});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reason = item.persistentReason;
    return PopupMenuButton<NotificationAction>(
      key: ValueKey('notification-more-${item.id}'),
      tooltip: l.common_moreActions,
      icon: Icon(Icons.more_vert, size: AppIconSize.i20, color: color ?? context.colors.textMuted),
      // At least 48 px to tap, whatever the platform's density.
      style: const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size.square(kMinInteractiveDimension))),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: item.isRead ? NotificationAction.markUnread : NotificationAction.markRead,
          child: Text(item.isRead ? l.notifications_markAsUnread : l.notifications_markAsRead),
        ),
        if (canOpen) PopupMenuItem(value: NotificationAction.open, child: Text(l.products_open)),
        if (item.canRemove)
          PopupMenuItem(value: NotificationAction.remove, child: Text(l.common_remove))
        else if (reason != null)
          PopupMenuItem(
            enabled: false,
            child: Text(
              persistentReasonLabel(l, reason),
              style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
            ),
          ),
      ],
    );
  }
}

/// A selection-mode tick box, 48 px to tap.
class NotificationSelectBox extends StatelessWidget {
  final String id;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const NotificationSelectBox({super.key, required this.id, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => SizedBox.square(
        key: ValueKey('notification-select-$id'),
        dimension: kMinInteractiveDimension,
        child: Checkbox(value: selected, onChanged: (v) => onChanged(v ?? false)),
      );
}

/// Phone width only: swipe left to remove, right to toggle read. A
/// persistent row does not swipe at all. The menu stays on every row, as
/// swipes are not discoverable.
class NotificationSwipe extends StatelessWidget {
  final NotificationRowFacts item;
  final Widget child;
  final VoidCallback onToggleRead;
  final VoidCallback onRemove;

  const NotificationSwipe(
      {super.key, required this.item, required this.child, required this.onToggleRead, required this.onRemove});

  Widget _background(BuildContext context, {required bool start}) {
    final color = start ? context.colors.primary : context.colors.danger;
    final icon = start
        ? (item.isRead ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined)
        : Icons.delete_outline;
    return Container(
      alignment: start ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
      decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a15), borderRadius: BorderRadius.circular(AppRadius.r12)),
      child: Icon(icon, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!item.canRemove || MediaQuery.sizeOf(context).width >= AppBreakpoints.compact) return child;
    return Dismissible(
      key: ValueKey('notification-swipe-${item.id}'),
      background: _background(context, start: true),
      secondaryBackground: _background(context, start: false),
      // The row never leaves by the swipe itself: the action changes my
      // state, and the list follows it (a removal disappears at once, and
      // comes back with Undo).
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggleRead();
        } else {
          onRemove();
        }
        return false;
      },
      child: child,
    );
  }
}
