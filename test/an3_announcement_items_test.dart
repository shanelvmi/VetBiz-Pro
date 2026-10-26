import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/data/announcement_fields.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/models/notification_state.dart';
import 'package:vetbiz_pro/services/announcement_service.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';

import 'helpers/notification_harness.dart';

// AN3 (owner decision: wire D5 for all urgent announcements), written before
// the code: an urgent announcement is DISMISSIBLE per person, like a
// promotion. Its state lives in my notificationState under an id no
// notification can have; a removal or read from before an edit is out of
// date, so the edited announcement shows again, unread.

final _published = DateTime(2026, 10, 20);
final _edited = DateTime(2026, 10, 25);

Announcement _a(String id, {String? kind, DateTime? updated}) => Announcement.fromMap(id, {
      'title': 'T $id',
      if (kind != null) 'kind': kind,
      'urgent': true,
      'timestamp': Timestamp.fromDate(_published),
      if (updated != null) 'updatedAt': Timestamp.fromDate(updated),
    });

void main() {
  group('buildAnnouncementItems', () {
    test('an id of its own; unread and removable; a kind-less one is text', () {
      final items = buildAnnouncementItems(announcements: [_a('A1')], state: NotificationState.empty);
      expect(items.single.id, 'announcement:A1');
      expect(announcementStateId('A1'), 'announcement:A1');
      expect(items.single.isRead, isFalse);
      expect(items.single.canRemove, isTrue);
      expect(items.single.persistentReason, isNull);
      expect(items.single.announcement.kind, AnnouncementKind.text);
    });

    test('removed for me: gone; removed before an edit: back', () {
      final state = NotificationState(removed: {'announcement:A1': DateTime(2026, 10, 22)});
      expect(buildAnnouncementItems(announcements: [_a('A1')], state: state), isEmpty);
      expect(buildAnnouncementItems(announcements: [_a('A1', updated: _edited)], state: state), hasLength(1));
    });

    test('read: read, unless marked unread or edited since', () {
      final read = NotificationState(read: {'announcement:A1': DateTime(2026, 10, 22)});
      expect(buildAnnouncementItems(announcements: [_a('A1')], state: read).single.isRead, isTrue);
      expect(buildAnnouncementItems(announcements: [_a('A1', updated: _edited)], state: read).single.isRead, isFalse);
      final unread = NotificationState(
          read: {'announcement:A1': DateTime(2026, 10, 22)}, unread: {'announcement:A1': DateTime(2026, 10, 23)});
      expect(buildAnnouncementItems(announcements: [_a('A1')], state: unread).single.isRead, isFalse);
    });
  });

  group('the feed controller', () {
    late FakeFirebaseFirestore db;
    late Clock clock;

    setUp(() async {
      db = FakeFirebaseFirestore();
      clock = Clock()..now = DateTime(2026, 10, 26);
      final col = db.collection(Collections.publicAnnouncements);
      await col.doc('P1').set({
        'kind': 'poster',
        'title': 'Poster',
        'imageUrl': 'https://files.example/p.png',
        'urgent': true,
        'hidden': false,
        'timestamp': Timestamp.fromDate(_published),
      });
      await col.doc('N1').set({'title': 'Not urgent', 'urgent': false, 'timestamp': Timestamp.fromDate(_published)});
    });

    test('lists the urgent ones; read, remove and Undo are mine, in my state', () async {
      final feed = newFeed(db, 'owner', clock)..start();
      addTearDown(feed.dispose);
      await settle();
      expect([for (final i in feed.announcementItems) i.announcement.id], ['P1']);
      final poster = feed.announcementItems.single;

      await feed.markRead([poster]);
      await settle();
      expect(feed.announcementItems.single.isRead, isTrue);

      final entries = await feed.remove([feed.announcementItems.single]);
      await settle();
      expect(feed.announcementItems, isEmpty);
      final stored = (await db.doc('facilities/F1/notificationState/owner').get()).data()!;
      expect((stored['removed'] as Map).keys, ['announcement:P1']);

      await feed.restore(entries);
      await settle();
      expect([for (final i in feed.announcementItems) i.announcement.id], ['P1']);

      // Someone else in the facility still has it, unread.
      final other = newFeed(db, 'assistant', clock, admin: false)..start();
      addTearDown(other.dispose);
      await settle();
      expect(other.announcementItems.single.isRead, isFalse);
    });

    test('an edit after my removal brings it back', () async {
      final feed = newFeed(db, 'owner', clock)..start();
      addTearDown(feed.dispose);
      await settle();
      await feed.remove(feed.announcementItems);
      await settle();
      expect(feed.announcementItems, isEmpty);
      await db
          .collection(Collections.publicAnnouncements)
          .doc('P1')
          .update({AnnouncementFields.updatedAt: Timestamp.fromDate(DateTime(2026, 10, 27))});
      await settle();
      expect(feed.announcementItems, hasLength(1));
    });
  });
}
