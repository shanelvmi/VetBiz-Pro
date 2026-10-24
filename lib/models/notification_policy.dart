import '../config/app_ranges.dart';
import '../data/subscription_notice_stage.dart';
import 'notification_model.dart' show NotificationType;

/// How a notification behaves for the person looking at it
/// (docs/design/notifications.md, section 2, approved).
enum NotificationClass {
  /// Stays until its condition is resolved; cannot be removed.
  persistent,

  /// Can be removed; leaves by itself when its offer ends.
  dismissible,

  /// Can be removed; leaves by itself after a while (read or unread).
  routine,
}

/// Why a persistent notification can't be removed: the explanation line
/// the screens show in place of Remove (texts in NOTIF-2c).
enum PersistentReason { untilRenewed, untilTrialEnds, untilDecided, untilNewClaim }

/// The facts that tell whether a persistent notification is resolved. Each
/// screen supplies the ones it knows; a fact it doesn't know is null, and an
/// unknown fact never resolves anything.
class PersistentFacts {
  /// The subscription notice's stage right now.
  final SubscriptionNoticeStage? subscriptionStage;

  /// Whether the free trial is in its calm part (SubscriptionProvider.isInCalmTrial).
  final bool? inCalmTrial;

  /// A payment claim newer than the rejection exists (pending or approved).
  final bool? newerClaimExists;

  /// The assistant's request was decided (approved, rejected, or they left).
  final bool? decisionMade;

  const PersistentFacts({this.subscriptionStage, this.inCalmTrial, this.newerClaimExists, this.decisionMade});
}

/// The approved notification policy, as plain rules with no screen in them.
class NotificationPolicy {
  NotificationPolicy._();

  /// Urgent announcements are not stored notifications, but follow the same
  /// policy (owner decision D5).
  static const NotificationClass urgentAnnouncementClass = NotificationClass.dismissible;

  static NotificationClass classOf(NotificationType type) {
    switch (type) {
      case NotificationType.subscriptionExpiring:
      case NotificationType.trialStatus:
      case NotificationType.assistantPending:
      case NotificationType.subscriptionRejected:
        return NotificationClass.persistent;
      case NotificationType.promotion:
        return NotificationClass.dismissible;
      // Everything else, including the types nothing writes today
      // (debtReminder, productExpiry) and the legacy trialStarted.
      case NotificationType.criticalStock:
      case NotificationType.lowStock:
      case NotificationType.reorderSoon:
      case NotificationType.restockShelf:
      case NotificationType.paymentReceived:
      case NotificationType.serviceRecorded:
      case NotificationType.newClient:
      case NotificationType.debtReminder:
      case NotificationType.productExpiry:
      case NotificationType.roleChanged:
      case NotificationType.trialStarted:
      case NotificationType.general:
        return NotificationClass.routine;
    }
  }

  /// Never shown at all (the legacy stored "trial started" notice).
  static bool isNeverShown(NotificationType type) => type == NotificationType.trialStarted;

  static bool canRemove(NotificationType type) => classOf(type) != NotificationClass.persistent;

  /// The explanation for a persistent type; null for any other.
  static PersistentReason? persistentReason(NotificationType type) => switch (type) {
        NotificationType.subscriptionExpiring => PersistentReason.untilRenewed,
        NotificationType.trialStatus => PersistentReason.untilTrialEnds,
        NotificationType.assistantPending => PersistentReason.untilDecided,
        NotificationType.subscriptionRejected => PersistentReason.untilNewClaim,
        _ => null,
      };

  /// Whether a persistent notification's condition has gone, so it leaves
  /// the list. Never true for a type that isn't persistent.
  static bool isResolved(NotificationType type, PersistentFacts facts) => switch (type) {
        NotificationType.subscriptionExpiring => facts.subscriptionStage == SubscriptionNoticeStage.none,
        NotificationType.trialStatus => facts.inCalmTrial == false,
        NotificationType.assistantPending => facts.decisionMade == true,
        NotificationType.subscriptionRejected => facts.newerClaimExists == true,
        _ => false,
      };

  /// Whether [now] is past the notification's lifetime. [myReadAt] is when
  /// I read it, [sharedReadAt] the facility-wide readAt from before NOTIF-2
  /// (it counts as read for everyone), [markedUnread] that I marked it
  /// unread again; [endsAt] is a dismissible item's end (its expiresAt).
  static bool isHiddenByAge({
    required NotificationClass cls,
    required DateTime now,
    DateTime? createdAt,
    DateTime? myReadAt,
    DateTime? sharedReadAt,
    bool markedUnread = false,
    DateTime? endsAt,
  }) {
    switch (cls) {
      case NotificationClass.persistent:
        return false;
      case NotificationClass.dismissible:
        if (endsAt != null) return !now.isBefore(endsAt);
        break; // no end: as routine
      case NotificationClass.routine:
        break;
    }
    final readAt = markedUnread ? null : (myReadAt ?? sharedReadAt);
    if (readAt != null) return !now.isBefore(readAt.add(AppRanges.notificationReadLifetime));
    if (createdAt == null) return false;
    return !now.isBefore(createdAt.add(AppRanges.notificationUnreadLifetime));
  }

  /// Whether the subscription notice, read at [seenStage], is unread again
  /// at [current]: only a move to a LATER stage.
  static bool isUnreadAgain({required SubscriptionNoticeStage? seenStage, required SubscriptionNoticeStage current}) =>
      seenStage != null && current.index > seenStage.index;
}
