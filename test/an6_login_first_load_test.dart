import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/services/updates_store.dart';
import 'package:vetbiz_pro/theme/app_motion.dart';
import 'package:vetbiz_pro/widgets/auth_entrance.dart';
import 'package:vetbiz_pro/widgets/updates_card.dart';
import 'package:vetbiz_pro/widgets/updates_carousel.dart';

import 'helpers/login_harness.dart';
import 'helpers/updates_harness.dart' show textUpdate;

// AN6, written before the change: the Updates card is drawn from the very
// first frame on every width, whatever the data (the welcome note at once on
// wide windows, a skeleton in the frame while nothing is known, the
// last-known slides at once when the device has them, a calm panel when
// there are none), and nothing moves when the answer arrives; the header and
// the two cards enter together once per page, never on a rebuild or a
// resize, and not at all under reduced motion.
const _skip = true;

final _en = lookupAppLocalizations(const Locale('en'));

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

({Rect card, Rect login}) _rects(WidgetTester tester) =>
    (card: _rect(tester, UpdatesCard.surfaceKey), login: _rect(tester, LoginScreen.loginCardKey));

double _opacity(WidgetTester tester, int i) => tester
    .widget<FadeTransition>(find.descendant(of: find.byType(AuthEntrance).at(i), matching: find.byType(FadeTransition)).first)
    .opacity
    .value;

void main() {
  for (final width in [1200.0, 1024.0, 390.0]) {
    final wide = width > 1000;
    testWidgets('$width, the first frame with nothing known: both cards, ${wide ? 'the welcome note, ' : ''}the skeleton in the frame', (tester) async {
      await pumpLogin(tester, await dbWithUpdates(3), width: width, height: 2400, settle: false);
      expect(find.byKey(UpdatesCard.surfaceKey), findsOneWidget);
      expect(find.byKey(LoginScreen.loginCardKey), findsOneWidget);
      expect(find.byKey(UpdatesCard.welcomeKey), wide ? findsOneWidget : findsNothing);
      expect(find.text(_en.updates_label), findsOneWidget);
      expect(find.byKey(UpdatesCarousel.skeletonKey), findsOneWidget);
    }, skip: _skip);

    testWidgets('$width: an EMPTY answer shows the calm panel, no chips, and nothing moves', (tester) async {
      await pumpLogin(tester, FakeFirebaseFirestore(), width: width, height: 2400, settle: false, reduceMotion: true);
      final before = _rects(tester);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(UpdatesCarousel.emptyKey), findsOneWidget);
      expect(find.text(_en.updates_empty), findsOneWidget);
      expect(find.text(_en.updates_new), findsNothing);
      expect(find.text(_en.updates_important), findsNothing);
      expect(_rects(tester), before);
    }, skip: _skip);

    testWidgets('$width: an answer with slides shows the first poster, and nothing moves', (tester) async {
      final db = await dbWithUpdates(2);
      await addUpdate(db, 'first', {...posterData(), 'imageUrl': 'https://files.example/first.png', 'timestamp': Timestamp.fromDate(DateTime(2026, 2, 1))});
      await pumpLogin(tester, db, width: width, height: 2400, settle: false, reduceMotion: true);
      final before = _rects(tester);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(UpdatesCarousel.skeletonKey), findsNothing);
      final poster = find.descendant(
        of: find.byKey(UpdatesSlides.frameKey),
        matching: find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage && (w.image as NetworkImage).url == 'https://files.example/first.png'),
      );
      expect(poster, findsOneWidget);
      expect(_rects(tester), before);
    }, skip: _skip);
  }

  testWidgets('with a persisted copy the slides are there on the FIRST frame', (tester) async {
    final seed = UpdatesStore(subscribe: (_) => Stream.value([textUpdate('kept')]), warm: (_) {});
    seed.start();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await UpdatesStore.instance.restore();
    await pumpLogin(tester, FakeFirebaseFirestore(), settle: false);
    expect(find.text('Title kept'), findsOneWidget);
    expect(find.byKey(UpdatesCarousel.skeletonKey), findsNothing);
  }, skip: _skip);

  testWidgets('the entrance: the header and both cards fade in and rise 12 px together, once', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(1));
    expect(find.byType(AuthEntrance), findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      expect(_opacity(tester, i), lessThan(0.05), reason: 'part $i starts hidden');
    }
    final start = _rect(tester, UpdatesCard.surfaceKey).top;
    await tester.pump(AppMotion.authEntranceStagger * 0.5);
    expect(_opacity(tester, 1), greaterThan(_opacity(tester, 2)), reason: 'the second card a little after the first');
    await tester.pump(AppMotion.authEntrance + AppMotion.authEntranceStagger);
    for (var i = 0; i < 3; i++) {
      expect(_opacity(tester, i), 1);
    }
    expect(start - _rect(tester, UpdatesCard.surfaceKey).top, closeTo(AppMotion.authEntranceRise, 0.5));
    // Not again on a rebuild or a resize.
    tester.view.physicalSize = const Size(1024, 1000);
    await tester.pump();
    tester.view.physicalSize = const Size(390, 1000);
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      expect(_opacity(tester, i), 1, reason: 'part $i after resizing');
    }
  }, skip: _skip);

  testWidgets('the entrance plays again when the page shows again after the page above it goes back', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(1));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    var lowest = 1.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.byType(AuthEntrance).evaluate().isNotEmpty) lowest = [lowest, _opacity(tester, 1)].reduce((a, b) => a < b ? a : b);
    }
    expect(lowest, lessThan(0.5));
    await tester.pumpAndSettle();
    expect(_opacity(tester, 1), 1);
  }, skip: _skip);

  testWidgets('reduced motion: no entrance at all', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(1), reduceMotion: true);
    for (var i = 0; i < 3; i++) {
      expect(_opacity(tester, i), 1);
    }
  }, skip: _skip);

  testWidgets('no overflow at 360 to 1200, Light, Dark, Kiswahili: loading, none, one, several', (tester) async {
    final dbs = [for (final n in [0, 1, 3]) await dbWithUpdates(n)];
    for (final width in [360.0, 390.0, 768.0, 1024.0, 1200.0]) {
      for (final (brightness, locale) in const [
        (Brightness.light, Locale('en')),
        (Brightness.dark, Locale('en')),
        (Brightness.light, Locale('sw')),
      ]) {
        await pumpLogin(tester, dbs.last, width: width, brightness: brightness, locale: locale, settle: false);
        expect(tester.takeException(), isNull, reason: '$width $brightness $locale loading');
        for (final db in dbs) {
          await pumpLogin(tester, db, width: width, brightness: brightness, locale: locale);
          expect(tester.takeException(), isNull, reason: '$width $brightness $locale');
        }
      }
    }
  }, skip: _skip);
}
