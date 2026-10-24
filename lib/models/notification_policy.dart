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

  static NotificationClass classOf(NotificationType type) => throw UnimplementedError('NOTIF-2b');

  /// Never shown at all (the legacy stored "trial started" notice).
  static bool isNeverShown(NotificationType type) => throw UnimplementedError('NOTIF-2b');

  static bool canRemove(NotificationType type) => throw UnimplementedError('NOTIF-2b');

  /// The explanation for a persistent type; null for any other.
  static PersistentReason? persistentReason(NotificationType type) => throw UnimplementedError('NOTIF-2b');

  /// Whether a persistent notification's condition has gone, so it leaves
  /// the list. Never true for a type that isn't persistent.
  static bool isResolved(NotificationType type, PersistentFacts facts) => throw UnimplementedError('NOTIF-2b');

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
  }) =>
      throw UnimplementedError('NOTIF-2b');

  /// Whether the subscription notice, read at [seenStage], is unread again
  /// at [current]: only a move to a LATER stage.
  static bool isUnreadAgain({required SubscriptionNoticeStage? seenStage, required SubscriptionNoticeStage current}) =>
      throw UnimplementedError('NOTIF-2b');
}
