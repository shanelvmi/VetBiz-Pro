import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../config/app_date_format.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

/// "Just now", "5m ago", "2h ago", "3d ago", or a plain date once it's
/// more than a week old - shared by every screen that shows a
/// notification's timestamp, so the same moment always reads the same
/// way regardless of which screen it's shown on.
String relativeTime(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return AppDateFormat.dateShort.format(dt);
}

/// A single notification row, matching the mockup's card style: a
/// circular, colored icon (from the notification's own centralized
/// type.color/type.icon, so every screen that shows notifications
/// stays visually consistent), title and message stacked, a relative
/// timestamp, and a trailing chevron only when there's somewhere
/// specific to navigate to. Shared between the general Notifications
/// screen and the focused Stock Alerts screen - the same row, wherever
/// a notification appears.
class NotificationRow extends StatelessWidget {
  final FacilityNotification notification;

  const NotificationRow({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final color = notification.type.color;
    final hasTarget = notification.relatedEntityType != null && notification.relatedEntityId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r10),
        boxShadow: [
          BoxShadow(
              color: context.colors.shadow.withValues(alpha: AppAlpha.a05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8),
              decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), shape: BoxShape.circle),
              child: Icon(notification.type.icon, color: color, size: AppIconSize.i18),
            ),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13_5)),
                  const SizedBox(height: AppSpacing.s2),
                  Text(notification.message,
                      style: TextStyle(color: context.colors.textSoft, fontSize: AppFontSize.f12_5)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(relativeTime(notification.createdAt),
                    style: TextStyle(color: context.colors.textHint, fontSize: AppFontSize.f11)),
                if (hasTarget) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Icon(Icons.chevron_right, color: context.colors.textDisabled, size: AppIconSize.i18),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
