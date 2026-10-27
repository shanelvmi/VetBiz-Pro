import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/auth_card.dart';
import 'package:vetbiz_pro/widgets/updates_carousel.dart';

// AN2, written before the login page changed: the old Announcements card
// (icon, title, chevron, divider, rotating PageView, "No announcements") is
// replaced by the shared Updates widget; with nothing to show there is no
// Updates area at all and, on wide windows, the sign-in form stands alone in
// the middle of the card.
// AN6 (owner): the Updates card is always there (a calm panel when there
// is nothing), and the frame is a PageView.

final _en = lookupAppLocalizations(const Locale('en'));

class _NoAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _long(String word, int n) => List.filled(n, word).join(' ');

void main() {
  Future<void> pump(WidgetTester tester, FirebaseFirestore db,
      {double width = 1200, Brightness brightness = Brightness.light, Locale locale = const Locale('en')}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final ui = (await tester.runAsync(() async {
      final p = UiSettingsProvider();
      while (!p.loaded) {
        await Future<void>.delayed(Duration.zero);
      }
      return p;
    }))!;
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: ui,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        theme: AppTheme.build(AppColorTheme.pasture, brightness),
        home: LoginScreen(authService: _NoAuth(), firestore: db),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  Future<void> add(FakeFirebaseFirestore db, String id, Map<String, dynamic> data) =>
      db.collection(Collections.publicAnnouncements).doc(id).set({
        'title': 'Title $id',
        'message': 'Message $id',
        'urgent': false,
        'hidden': false,
        'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
        ...data,
      });

  // AN6 (owner): changed from "no Updates area; the form centred alone": the
  // Updates card is always there, with a calm panel when there is nothing.
  testWidgets('no announcements: the calm panel in the Updates card, no old empty state; the form in the right card on a wide window', (tester) async {
    await pump(tester, FakeFirebaseFirestore());
    expect(find.byType(UpdatesSlides), findsNothing);
    expect(find.byKey(UpdatesCarousel.emptyKey), findsOneWidget);
    expect(find.text(_en.updates_label), findsOneWidget);
    for (final gone in ['Announcements', 'No announcements', "You're all caught up!"]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    final card = tester.getRect(find.byKey(AuthCard.surfaceKey));
    final email = tester.getRect(find.byType(TextField).first);
    expect(email.center.dx, greaterThan(card.center.dx));
  });


  testWidgets('with an update: the Updates label, the shared widget; no Announcements title, icon or chevron', (tester) async {
    final db = FakeFirebaseFirestore();
    await add(db, '1', {});
    for (final width in [390.0, 1200.0]) {
      await pump(tester, db, width: width);
      expect(find.byType(UpdatesSlides), findsOneWidget, reason: '$width');
      expect(find.text(_en.updates_label), findsOneWidget);
      expect(find.text('Title 1'), findsOneWidget);
      expect(find.text('Announcements'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byIcon(Icons.campaign_outlined), findsNothing);
      // AN6: one PageView, the Updates frame's own (was: none at all).
      expect(find.byType(PageView), findsOneWidget);
      expect(find.descendant(of: find.byKey(UpdatesSlides.frameKey), matching: find.byType(PageView)), findsOneWidget);
    }
  });

  testWidgets('a phone: the form first, the Updates below it', (tester) async {
    final db = FakeFirebaseFirestore();
    await add(db, '1', {});
    await pump(tester, db, width: 390);
    expect(tester.getRect(find.byType(UpdatesSlides)).top, greaterThan(tester.getRect(find.byType(TextField).last).bottom));
  });

  testWidgets('no overflow at 360, 390, 768 and 1200 in Light, Dark and Kiswahili with a very long title and message', (tester) async {
    final db = FakeFirebaseFirestore();
    await add(db, 'long', {
      'title': _long('Mafunzo', 12),
      'message': _long('Wafugaji', 90),
      'urgent': true,
      'linkUrl': 'https://a.example',
      'linkLabel': 'Jifunze zaidi sasa',
      'timestamp': Timestamp.now(),
    });
    await add(db, 'poster', {'kind': 'poster', 'imageUrl': 'https://files.example/p.png', 'urgent': true});
    for (final width in [360.0, 390.0, 768.0, 1200.0]) {
      for (final brightness in Brightness.values) {
        for (final locale in const [Locale('en'), Locale('sw')]) {
          await pump(tester, db, width: width, brightness: brightness, locale: locale);
          expect(tester.takeException(), isNull, reason: '$width $brightness $locale');
        }
      }
    }
  });
}
