import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notification_model.dart';

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
  return DateFormat('d MMM').format(dt);
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(notification.type.icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(notification.message,
                      style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(relativeTime(notification.createdAt), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                if (hasTarget) ...[
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
