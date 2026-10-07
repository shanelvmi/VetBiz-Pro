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
  roleChanged, // a Platform Admin changed someone's role (Assistant <-> Co-admin)
  trialStarted, // LEGACY: a stored notice an earlier version wrote at registration - no longer shown
  trialStatus, // the live "Free Trial - N days left" row (never stored; built from the subscription)
  assistantPending, // an assistant registered (or asked to join) and needs approval
  general; // fallback for anything unrecognized - never crashes on unknown data

  static NotificationType fromString(String? value) {
    if (value == null) return NotificationType.general;
    // Compared ignoring underscores and case: the subscription-rejection
    // flow writes 'subscription_rejected', not the enum's own
    // 'subscriptionRejected', so an exact match never found it and every
    // rejection notice fell through to [general] - filed under "Update"
    // instead of "System", with the wrong icon.
    final normalized = value.replaceAll('_', '').toLowerCase();
    return NotificationType.values.firstWhere(
      (t) => t.name.toLowerCase() == normalized,
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
      case NotificationType.roleChanged:
      case NotificationType.trialStarted:
      case NotificationType.trialStatus:
      case NotificationType.assistantPending:
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
      case NotificationType.roleChanged:
        return Icons.manage_accounts_outlined;
      case NotificationType.trialStarted:
        return Icons.rocket_launch_outlined;
      case NotificationType.trialStatus:
        // The same icon as the Dashboard's blue "View Plans" pill.
        return Icons.workspace_premium_outlined;
      case NotificationType.assistantPending:
        return Icons.person_add_alt_1_outlined;
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
      case NotificationType.roleChanged:
        return Colors.teal;
      case NotificationType.trialStarted:
      case NotificationType.trialStatus:
        return Colors.blue;
      case NotificationType.assistantPending:
        return Colors.orange;
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

  // Who this is FOR. Notifications used to be facility-wide - everyone in
  // the facility saw every one - which can't express "tell this person they
  // were promoted" or "tell the admins". All three are optional, and a
  // notification without them (every older one) is still for everybody.
  //
  //   audience 'all' (or absent)  - everyone in the facility
  //   audience 'admins'           - Admins and Co-admins only
  //   audience 'user'             - just [targetUserId]
  //   excludeUserId               - hidden from this one person, however the
  //                                 audience would otherwise include them
  //                                 (so the person a notice is ABOUT doesn't
  //                                 get it twice, once for them and once as
  //                                 an admin)
  //
  // This decides what each screen SHOWS. It is not access control: the
  // security rules still let any member of the facility read the collection.
  final String? audience;
  final String? targetUserId;
  final String? excludeUserId;

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
    this.audience,
    this.targetUserId,
    this.excludeUserId,
  });

  bool get isRead => readAt != null;
  bool get isPersistent => expiresAt != null;
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  // What actually determines whether this still belongs on screen -
  // an ephemeral one only while unread, a persistent one for as long
  // as it hasn't expired, read or not.
  bool get isCurrentlyVisible => isPersistent ? !isExpired : !isRead;

  NotificationCategory get category => type.category;

  /// Whether this notification is meant for the person looking at it. Every
  /// place that lists or counts notifications (the Notifications screen and
  /// the Dashboard bell) has to apply this, or the bell would light up for
  /// something the person can't even see on the screen.
  bool isVisibleTo({required String? uid, required bool isAdmin}) {
    // A stored "trial started" notice (an earlier version wrote one at
    // registration) is superseded by the live trial row, which says the same
    // thing, to everyone, and stays correct. Left visible it would duplicate
    // that row - and being stored and unread it would flash the bell red and
    // couldn't be cleared once hidden. Dropped here, which is where both the
    // bell and the Notifications screen already filter.
    if (type == NotificationType.trialStarted) return false;
    if (excludeUserId != null && excludeUserId == uid) return false;
    switch (audience) {
      case 'admins':
        return isAdmin;
      case 'user':
        return targetUserId != null && targetUserId == uid;
      default:
        return true; // 'all', or an older notification with no audience
    }
  }

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
      audience: data['audience'] as String?,
      targetUserId: data['targetUserId'] as String?,
      excludeUserId: data['excludeUserId'] as String?,
    );
  }
}
