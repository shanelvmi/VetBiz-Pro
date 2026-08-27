import 'package:cloud_firestore/cloud_firestore.dart';

/// A single, persistent, per-facility notification - the piece the
/// rest of the app's "Notifications" screen never had: a real document
/// with its own read state, rather than something recomputed live from
/// other collections on every open.
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
  final String type;
  final String title;
  final String message;
  final DateTime? createdAt;
  final DateTime? readAt;
  final DateTime? expiresAt;

  const FacilityNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.createdAt,
    this.readAt,
    this.expiresAt,
  });

  bool get isRead => readAt != null;
  bool get isPersistent => expiresAt != null;
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  // What actually determines whether this still belongs on screen -
  // an ephemeral one only while unread, a persistent one for as long
  // as it hasn't expired, read or not.
  bool get isCurrentlyVisible => isPersistent ? !isExpired : !isRead;

  factory FacilityNotification.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime? asDate(dynamic value) => value is Timestamp ? value.toDate() : null;
    return FacilityNotification(
      id: doc.id,
      type: (data['type'] as String?) ?? 'general',
      title: (data['title'] as String?) ?? '',
      message: (data['message'] as String?) ?? '',
      createdAt: asDate(data['createdAt']),
      readAt: asDate(data['readAt']),
      expiresAt: asDate(data['expiresAt']),
    );
  }
}
