import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// The specific kind of event this notification represents. Deliberately
/// granular - one value per distinct event kind - with [category] below
/// providing the broader grouping used for filter tabs, so the two
/// concerns (exact meaning vs. how it's filtered) don't have to be the
/// same thing.
///
/// [promotion] and [subscriptionRejected] are the two type strings
/// already written to Firestore today (see PromotionService and the
/// subscription-rejection flow) - kept as their own values rather than
/// folded into a generic "system" type, so nothing already in
/// production silently loses its specific meaning.
enum NotificationType {
  criticalStock,
  lowStock,
  reorderSoon,
  restockShelf,
  paymentReceived,
  serviceRecorded,
  newClient,
  debtReminder,
  productExpiry,
  promotion,
  subscriptionRejected,
  subscriptionExpiring,
  general; // fallback for anything unrecognized - never crashes on unknown data

  static NotificationType fromString(String? value) {
    return NotificationType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => NotificationType.general,
    );
  }
}

/// The broader grouping a notification's [NotificationType] falls under -
/// this is what the Notifications screen's filter tabs (All/Critical/
/// Stock/Debts/Payments/System) actually filter by, since several
/// distinct types can share one tab (e.g. both a depleted product and
/// an expiring one are "stock" concerns to a shop owner, even though
/// they're different NotificationTypes under the hood).
enum NotificationCategory { critical, stock, payment, debt, system, other }

extension NotificationTypeDisplay on NotificationType {
  NotificationCategory get category {
    switch (this) {
      case NotificationType.criticalStock:
        return NotificationCategory.critical;
      case NotificationType.lowStock:
      case NotificationType.reorderSoon:
      case NotificationType.restockShelf:
      case NotificationType.productExpiry:
        return NotificationCategory.stock;
      case NotificationType.paymentReceived:
        return NotificationCategory.payment;
      case NotificationType.debtReminder:
        return NotificationCategory.debt;
      case NotificationType.promotion:
      case NotificationType.subscriptionRejected:
      case NotificationType.subscriptionExpiring:
        return NotificationCategory.system;
      case NotificationType.serviceRecorded:
      case NotificationType.newClient:
      case NotificationType.general:
        return NotificationCategory.other;
    }
  }

  // Centralized so every screen that shows a notification (Dashboard
  // dropdown, full Notifications screen) gets the exact same icon,
  // color, and category label - never duplicated, and never drifting
  // out of sync between the two places notifications actually render.
  IconData get icon {
    switch (this) {
      case NotificationType.criticalStock:
        return Icons.error_outline;
      case NotificationType.lowStock:
        return Icons.trending_down;
      case NotificationType.reorderSoon:
        return Icons.hourglass_bottom;
      case NotificationType.restockShelf:
        return Icons.move_up;
      case NotificationType.paymentReceived:
        return Icons.payments_outlined;
      case NotificationType.serviceRecorded:
        return Icons.medical_services_outlined;
      case NotificationType.newClient:
        return Icons.person_add_outlined;
      case NotificationType.debtReminder:
        return Icons.account_balance_wallet_outlined;
      case NotificationType.productExpiry:
        return Icons.warning_amber_outlined;
      case NotificationType.promotion:
        return Icons.celebration_outlined;
      case NotificationType.subscriptionRejected:
        return Icons.error_outline;
      case NotificationType.subscriptionExpiring:
        return Icons.timer_outlined;
      case NotificationType.general:
        return Icons.notifications_none;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.criticalStock:
      case NotificationType.subscriptionRejected:
        return Colors.red;
      case NotificationType.lowStock:
      case NotificationType.subscriptionExpiring:
        return Colors.orange;
      case NotificationType.reorderSoon:
        return Colors.amber[700]!;
      case NotificationType.restockShelf:
        return Colors.blue;
      case NotificationType.paymentReceived:
        return Colors.green;
      case NotificationType.serviceRecorded:
      case NotificationType.newClient:
        return Colors.blue;
      case NotificationType.debtReminder:
        return Colors.deepOrange;
      case NotificationType.productExpiry:
        return Colors.red;
      case NotificationType.promotion:
        return Colors.purple;
      case NotificationType.general:
        return Colors.grey;
    }
  }

  // Short label for the category badge shown on each row in the full
  // Notifications screen (e.g. "Critical", "Stock", "Payment").
  String get categoryLabel {
    switch (category) {
      case NotificationCategory.critical:
        return 'Critical';
      case NotificationCategory.stock:
        return 'Stock';
      case NotificationCategory.payment:
        return 'Payment';
      case NotificationCategory.debt:
        return 'Debt';
      case NotificationCategory.system:
        return 'System';
      case NotificationCategory.other:
        return 'Update';
    }
  }
}

/// A single, persistent, per-facility notification - the piece the
/// rest of the app's "Notifications" screen never had: a real document
/// with its own read state, rather than something recomputed live from
/// other collections on every open.
///
/// Read state is shared across the whole facility, not per-user - one
/// staff member marking a notification read is reflected for everyone
/// else on the same facility, matching how the rest of this app's
/// shared data (products, sales, etc.) already works.
///
/// Two lifecycles, distinguished by [expiresAt]:
///   - Ephemeral (expiresAt is null): meant to disappear once read -
///     e.g. "your subscription payment was rejected: <reason>". Once
///     acknowledged, there's nothing further to track.
///   - Persistent (expiresAt is set): stays visible - just no longer
///     marked as new - until the underlying condition itself ends,
///     e.g. "you're on the August promotion" remaining visible for as
///     long as that promotion is actually still running, regardless of
///     whether it's already been seen.
class FacilityNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime? createdAt;
  final DateTime? readAt;
  final DateTime? expiresAt;

  // What this notification is actually about, if anything - lets the UI
  // navigate straight to the underlying record (a product, a payment, a
  // client, etc.) when tapped, matching the '>' chevron in the mockups.
  // Both null for notifications with nothing specific to link to (e.g.
  // a promotion).
  final String? relatedEntityType; // 'product' | 'payment' | 'client' | 'debt' | 'service'
  final String? relatedEntityId;

  const FacilityNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.createdAt,
    this.readAt,
    this.expiresAt,
    this.relatedEntityType,
    this.relatedEntityId,
  });

  bool get isRead => readAt != null;
  bool get isPersistent => expiresAt != null;
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  // What actually determines whether this still belongs on screen -
  // an ephemeral one only while unread, a persistent one for as long
  // as it hasn't expired, read or not.
  bool get isCurrentlyVisible => isPersistent ? !isExpired : !isRead;

  NotificationCategory get category => type.category;

  factory FacilityNotification.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime? asDate(dynamic value) => value is Timestamp ? value.toDate() : null;
    return FacilityNotification(
      id: doc.id,
      type: NotificationType.fromString(data['type'] as String?),
      title: (data['title'] as String?) ?? '',
      message: (data['message'] as String?) ?? '',
      createdAt: asDate(data['createdAt']),
      readAt: asDate(data['readAt']),
      expiresAt: asDate(data['expiresAt']),
      relatedEntityType: data['relatedEntityType'] as String?,
      relatedEntityId: data['relatedEntityId'] as String?,
    );
  }
}
