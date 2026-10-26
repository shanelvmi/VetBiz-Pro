import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';
import 'package:vetbiz_pro/widgets/announcement_poster.dart';

import 'helpers/notification_harness.dart';
import 'helpers/updates_harness.dart' show goodImage, badImage;

// AN3, written before the screen changed: the bell's dropdown shows urgent
// announcements of both kinds as my own DISMISSIBLE rows - a poster as a row
// with its thumbnail, title and Important or New chip, opening the whole
// poster; a text one keeps its card; menu, Remove and Undo like any row; the
// same audience rule as the login page; no overflow.

final _en = lookupAppLocalizations(const Locale('en'));

Future<void> _announce(FirebaseFirestore fs, String id, Map<String, dynamic> data) =>
    fs.collection(Collections.publicAnnouncements).doc(id).set({
      'title': 'Title $id',
      'message': 'Message $id',
      'urgent': true,
      'hidden': false,
      'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
      ...data,
    });

Map<String, dynamic> _posterData({String audience = 'all', String? link, String? label}) => {
      'kind': 'poster',
      'message': '',
      'imageUrl': 'https://files.example/p.png',
      'audience': audience,
      if (link != null) 'linkUrl': link,
      if (label != null) 'linkLabel': label,
    };

void main() {
  late FakeFirebaseFirestore fs;
  late NotificationFeedController c;

  setUp(() => fs = FakeFirebaseFirestore());

  Future<void> pump(WidgetTester tester,
      {double width = 390, bool dark = false, String locale = 'en', ImageProvider Function(String)? imageFor}) async {
    c = newFeed(fs, 'A', Clock());
    addTearDown(c.dispose);
    await pumpNotifications(tester, c, dropdown: true, width: width, dark: dark, locale: locale, imageFor: imageFor ?? goodImage);
  }

  testWidgets('a text announcement keeps its card, now with the menu; a kind-less one is text', (tester) async {
    await _announce(fs, 'T1', {});
    await pump(tester);
    expect(find.text('Title T1'), findsOneWidget);
    expect(find.textContaining('Message T1', findRichText: true), findsOneWidget);
    expect(find.byType(AnnouncementThumbnail), findsNothing);
    final more = moreOf('announcement:T1');
    expect(tester.getSize(more).width, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(tester.getSize(more).height, greaterThanOrEqualTo(kMinInteractiveDimension));
    await tester.tap(find.text('Title T1'));
    await tester.pumpAndSettle();
    expect(c.announcementItems.single.isRead, isTrue);
  });

  testWidgets('a poster: thumbnail, title and Important chip; a tap opens the whole poster, with its link', (tester) async {
    await _announce(fs, 'P1', _posterData(link: 'https://a.example/book', label: 'Book now'));
    await pump(tester);
    expect(find.byType(AnnouncementThumbnail), findsOneWidget);
    expect(find.text('Title P1'), findsOneWidget);
    expect(find.text(_en.updates_important), findsOneWidget);
    await tester.tap(find.text('Title P1'));
    await tester.pumpAndSettle();
    expect(find.byType(AnnouncementPosterView), findsOneWidget);
    expect(find.text('Book now'), findsOneWidget);
    expect(c.announcementItems.single.isRead, isTrue);
  });

  testWidgets('a poster with an unsafe link: no button in its dialog', (tester) async {
    await _announce(fs, 'P1', _posterData(link: 'javascript:alert(1)', label: 'Go'));
    await pump(tester);
    await tester.tap(find.text('Title P1'));
    await tester.pumpAndSettle();
    expect(find.text('Go'), findsNothing);
  });

  testWidgets('a poster whose image fails: the thumbnail falls back, nothing breaks', (tester) async {
    await _announce(fs, 'P1', _posterData());
    await pump(tester, imageFor: badImage);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.byKey(AnnouncementThumbnail.fallbackKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Remove a poster row for me, then Undo puts it back', (tester) async {
    await _announce(fs, 'P1', _posterData());
    await pump(tester);
    await openMenu(tester, 'announcement:P1');
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Title P1'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Title P1'), findsOneWidget);
    await letToastGo(tester);
  });

  testWidgets('the audience: English-only and Kiswahili-only, each in its own language', (tester) async {
    await _announce(fs, 'EN', _posterData(audience: 'en'));
    await _announce(fs, 'SW', _posterData(audience: 'sw'));
    await pump(tester);
    expect(find.text('Title EN'), findsOneWidget);
    expect(find.text('Title SW'), findsNothing);
    await pump(tester, locale: 'sw');
    expect(find.text('Title SW'), findsOneWidget);
    expect(find.text('Title EN'), findsNothing);
  });

  testWidgets('with no notifications, an urgent announcement still shows (not the empty state)', (tester) async {
    await _announce(fs, 'T1', {});
    await pump(tester);
    expect(find.text(_en.notifications_emptyHint), findsNothing);
    expect(find.text('Title T1'), findsOneWidget);
  });

  testWidgets('no overflow at 360, 390, 768 and 1200 in Light, Dark and Kiswahili', (tester) async {
    final longTitle = List.filled(12, 'Mafunzo').join(' ');
    await _announce(fs, 'T1', {'title': longTitle, 'message': List.filled(60, 'Wafugaji').join(' ')});
    await _announce(fs, 'P1', {..._posterData(), 'title': longTitle, 'timestamp': Timestamp.now()});
    for (final width in [360.0, 390.0, 768.0, 1200.0]) {
      for (final dark in [false, true]) {
        for (final locale in ['en', 'sw']) {
          await pump(tester, width: width, dark: dark, locale: locale);
          expect(tester.takeException(), isNull, reason: '$width $dark $locale');
        }
      }
    }
  });
}
