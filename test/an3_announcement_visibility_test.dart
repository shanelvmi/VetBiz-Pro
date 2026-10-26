import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/data/announcement_fields.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/services/announcement_service.dart';
import 'package:vetbiz_pro/utils/announcement_visibility.dart';

// AN3, written before the code: ONE audience rule for the login page, the
// dashboard's bell and Notifications; the bell blinks only for an urgent
// announcement this person may see; an edit is dated, so a removed
// announcement can show again once it changes.

Announcement _a(String id, {String? audience, bool hidden = false, bool urgent = true, DateTime? at}) =>
    Announcement.fromMap(id, {
      'title': 'T',
      if (audience != null) 'audience': audience,
      'hidden': hidden,
      'urgent': urgent,
      if (at != null) 'timestamp': Timestamp.fromDate(at),
    });

void main() {
  group('isShown', () {
    test('everyone, missing and unknown audiences show in both languages', () {
      for (final lang in ['en', 'sw']) {
        expect(AnnouncementVisibility.isShown(_a('1'), languageCode: lang), isTrue);
        expect(AnnouncementVisibility.isShown(_a('1', audience: 'all'), languageCode: lang), isTrue);
        expect(AnnouncementVisibility.isShown(_a('1', audience: 'fr'), languageCode: lang), isTrue);
      }
    });

    test('English-only shows in English only; Kiswahili-only in Kiswahili only', () {
      expect(AnnouncementVisibility.isShown(_a('1', audience: 'en'), languageCode: 'en'), isTrue);
      expect(AnnouncementVisibility.isShown(_a('1', audience: 'en'), languageCode: 'sw'), isFalse);
      expect(AnnouncementVisibility.isShown(_a('1', audience: 'sw'), languageCode: 'sw'), isTrue);
      expect(AnnouncementVisibility.isShown(_a('1', audience: 'sw'), languageCode: 'en'), isFalse);
    });

    test('hidden never shows', () {
      expect(AnnouncementVisibility.isShown(_a('1', hidden: true), languageCode: 'en'), isFalse);
    });
  });

  group('the dashboard bell: new since this device last viewed Notifications', () {
    final viewed = DateTime(2026, 10, 26, 9);
    final later = viewed.add(const Duration(hours: 1));

    test('an urgent one published later, for my language, blinks', () {
      expect(AnnouncementVisibility.hasNewUrgentSince([_a('1', at: later)], viewed, languageCode: 'en'), isTrue);
    });

    test('not for the other language, hidden, not urgent, older, or never viewed', () {
      for (final a in [
        _a('1', at: later, audience: 'sw'),
        _a('1', at: later, hidden: true),
        _a('1', at: later, urgent: false),
        _a('1', at: viewed.subtract(const Duration(minutes: 1))),
        _a('1'),
      ]) {
        expect(AnnouncementVisibility.hasNewUrgentSince([a], viewed, languageCode: 'en'), isFalse);
      }
      expect(AnnouncementVisibility.hasNewUrgentSince([_a('1', at: later)], null, languageCode: 'en'), isFalse);
    });

    test('the dashboard uses the shared rule', () {
      final source = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();
      expect(source, contains('AnnouncementVisibility.hasNewUrgentSince('));
    });
  });

  test('an edit is dated (updatedAt), so a removal before it no longer hides it', () async {
    final db = FakeFirebaseFirestore();
    final service = AnnouncementService(firestore: db);
    await service.save(AnnouncementDraft(kind: AnnouncementKind.text, title: 'Hello', message: 'World'));
    final doc = (await db.collection(Collections.publicAnnouncements).get()).docs.single;
    final created = Announcement.fromMap(doc.id, doc.data());
    expect(created.updatedAt, isNull);
    expect(created.versionAt, created.publishedAt);
    await service.save(AnnouncementDraft.from(created)..message = 'Changed', existing: created);
    final edited = (await db.collection(Collections.publicAnnouncements).doc(doc.id).get()).data()!;
    expect(edited[AnnouncementFields.updatedAt], isA<Timestamp>());
    expect(AnnouncementFields.updatedAt, 'updatedAt');
    final reread = Announcement.fromMap(doc.id, edited);
    expect(reread.versionAt, reread.updatedAt);
  });
}
