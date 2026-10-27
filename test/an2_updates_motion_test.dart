import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_motion.dart';
import 'package:vetbiz_pro/widgets/updates_carousel.dart';

import 'helpers/updates_harness.dart';

// AN2 (the owner's approved design), written before the widget: one slide
// is still; several fade, advance every 7 s and pause on hover or touch,
// never under reduced motion; dots (48 px) and swipe, arrows on wide
// windows; the next poster preloaded. The feed: read once, nothing drawn
// when there is nothing (or an error), the audience by language, urgent
// ones take over, five at most. No overflow anywhere.
// AN6 (owner): the dots are 24 x 48 px, no arrows
// (their test removed; test/an6_updates_slider_test.dart), and with nothing
// to show (or an error with nothing known) the calm panel is drawn.

// AN6: the timer is a running fill now, so it never settles: pump through.
Future<void> settleSlide(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(AppMotion.updatesSlide);
  await tester.pump(AppMotion.updatesSlide);
  await tester.pump(AppMotion.updatesSlide);
  await tester.pump();
}

void main() {
  setUp(() => UpdatesSlides.debugTimerStarts = 0);

  group('one slide and several', () {
    testWidgets('one slide is still: no timer, no dots, no arrows', (tester) async {
      await pumpSlides(tester, [textUpdate('1')]);
      await tester.pump(AppTimeouts.updatesAdvance * 3);
      expect(find.text('Title 1'), findsOneWidget);
      expect(UpdatesSlides.debugTimerStarts, 0);
      expect(find.bySemanticsLabel(enL10n.updates_slideOf(1, 1)), findsNothing);
      expect(find.byIcon(Icons.arrow_forward), findsNothing); // AN6: was the Next tooltip (arrows retired)
    });

    testWidgets('several advance every 7 seconds with a fade, and wrap around', (tester) async {
      await pumpSlides(tester, [textUpdate('1'), textUpdate('2')]);
      expect(find.text('Title 1'), findsOneWidget);
      await tester.pump(AppTimeouts.updatesAdvance);
      await settleSlide(tester);
      expect(find.text('Title 2'), findsOneWidget);
      expect(find.text('Title 1'), findsNothing);
      await tester.pump(AppTimeouts.updatesAdvance);
      await settleSlide(tester);
      expect(find.text('Title 1'), findsOneWidget);
      expect(find.byType(FadeTransition), findsWidgets);
    });

    testWidgets('pause while the pointer hovers; go on when it leaves', (tester) async {
      await pumpSlides(tester, [textUpdate('1'), textUpdate('2')]);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(frame(tester).center);
      await tester.pump(AppTimeouts.updatesAdvance * 3);
      await settleSlide(tester);
      expect(find.text('Title 1'), findsOneWidget);
      await mouse.moveTo(Offset.zero);
      await tester.pump(); // AN6: the resumed timer starts on this frame
      await tester.pump(AppTimeouts.updatesAdvance);
      await settleSlide(tester);
      expect(find.text('Title 2'), findsOneWidget);
    });

    testWidgets('pause while a finger touches; go on after it lifts', (tester) async {
      await pumpSlides(tester, [textUpdate('1'), textUpdate('2')]);
      final finger = await tester.startGesture(frame(tester).center, kind: PointerDeviceKind.touch);
      await tester.pump(AppTimeouts.updatesAdvance * 3);
      expect(find.text('Title 1'), findsOneWidget);
      await finger.up();
      await tester.pump(); // AN6: the resumed timer starts on this frame
      await tester.pump(AppTimeouts.updatesAdvance);
      await settleSlide(tester);
      expect(find.text('Title 2'), findsOneWidget);
    });

    testWidgets('no auto-advance when the system asks for less motion; the dots still work', (tester) async {
      await pumpSlides(tester, [textUpdate('1'), textUpdate('2')], reduceMotion: true);
      await tester.pump(AppTimeouts.updatesAdvance * 3);
      expect(find.text('Title 1'), findsOneWidget);
      expect(UpdatesSlides.debugTimerStarts, 0);
      await tester.tap(find.bySemanticsLabel(enL10n.updates_slideOf(2, 2)));
      await tester.pump();
      expect(find.text('Title 2'), findsOneWidget);
    });

    testWidgets('dots:  24 x 48 px hit areas (AN6: was 48 x 48), a tap shows that slide; a swipe moves on', (tester) async {
      await pumpSlides(tester, [textUpdate('1'), textUpdate('2'), textUpdate('3')], width: 390);
      final dot = find.bySemanticsLabel(enL10n.updates_slideOf(3, 3));
      expect(tester.getSize(dot).width, greaterThanOrEqualTo(UpdatesMetrics.dotSlot)); // AN6: was kMinInteractiveDimension
      expect(tester.getSize(dot).height, greaterThanOrEqualTo(kMinInteractiveDimension));
      await tester.tap(dot);
      await settleSlide(tester);
      expect(find.text('Title 3'), findsOneWidget);
      await tester.fling(find.byKey(UpdatesSlides.frameKey), const Offset(-200, 0), 1000);
      await settleSlide(tester);
      expect(find.text('Title 1'), findsOneWidget);
    });

    testWidgets('the next poster is loaded before it shows', (tester) async {
      final asked = <String>[];
      await pumpSlides(
        tester,
        [textUpdate('1'), posterUpdate('2', url: 'https://files.example/next.png')],
        imageFor: (url) {
          asked.add(url);
          return MemoryImage(testPng);
        },
      );
      await tester.pump();
      expect(asked, contains('https://files.example/next.png'));
    });
  });

  group('the feed', () {
    late FakeFirebaseFirestore db;
    setUp(() => db = FakeFirebaseFirestore());

    Future<void> add(String id, Map<String, dynamic> data) => db.collection(Collections.publicAnnouncements).doc(id).set({
      'title': 'Title $id',
      'message': 'M',
      'urgent': false,
      'hidden': false,
      'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
      ...data,
    });

    Future<void> pumpFeed(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
      FirebaseFirestore? firestore,
      int rebuilds = 0,
    }) async {
      late StateSetter rebuild;
      await tester.pumpWidget(
        updatesApp(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return UpdatesCarousel(
                firestore: firestore ?? db,
                imageFor: goodImage,
                builder: (context, updates) => updates,
              );
            },
          ),
          locale: locale,
        ),
      );
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < rebuilds; i++) {
        rebuild(() {});
        await tester.pump();
      }
    }

    // AN6: the calm panel (was: nothing drawn at all).
    testWidgets('no documents: the calm panel, never a spinner', (tester) async {
      await pumpFeed(tester);
      expect(find.byKey(UpdatesCarousel.emptyKey), findsOneWidget);
      expect(find.text(enL10n.updates_empty), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('the audience filter in each language; none for this language shows the calm panel (AN6)', (tester) async {
      await add('en', {'audience': 'en'});
      await pumpFeed(tester);
      expect(find.text('Title en'), findsOneWidget);
      await pumpFeed(tester, locale: const Locale('sw'));
      expect(find.byKey(UpdatesCarousel.emptyKey), findsOneWidget);
      await add('sw', {'audience': 'sw'});
      await pumpFeed(tester, locale: const Locale('sw'));
      expect(find.text('Title sw'), findsOneWidget);
      expect(find.text('Title en'), findsNothing);
    });

    testWidgets('urgent ones take over; at most five slides', (tester) async {
      for (var i = 1; i <= 7; i++) {
        await add('$i', {'timestamp': Timestamp.fromDate(DateTime(2026, 1, i))});
      }
      await pumpFeed(tester);
      expect(find.bySemanticsLabel(enL10n.updates_slideOf(5, 5)), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('of 6|of 7')), findsNothing);
      await add('u', {'urgent': true});
      await pumpFeed(tester);
      expect(find.text('Title u'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Slide 1 of')), findsNothing); // one slide: no dots
    });

    testWidgets('an error with nothing known shows the calm panel (AN6: was nothing), never an endless spinner', (tester) async {
      await pumpFeed(tester, firestore: FailingFirestore());
      expect(find.byKey(UpdatesCarousel.emptyKey), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('the collection is read once and the timer started once, whatever rebuilds', (tester) async {
      await add('1', {});
      await add('2', {});
      final counting = CountingAnnouncementsFirestore(db);
      await pumpFeed(tester, firestore: counting, rebuilds: 2);
      expect(counting.reads, 1);
      expect(UpdatesSlides.debugTimerStarts, 1);
    });
  });

  group('no overflow', () {
    testWidgets('360, 390, 768 and 1200; Light, Dark and Kiswahili; a very long title and message', (tester) async {
      final slides = [
        textUpdate(
          '1',
          title: longText('Mafunzo', 12),
          message: longText('Wafugaji', 90),
          urgent: true,
          fresh: true,
          link: 'https://a.example',
          label: 'Jifunze zaidi sasa',
        ),
        posterUpdate('2', urgent: true, fresh: true),
      ];
      for (final width in [360.0, 390.0, 768.0, 1200.0]) {
        for (final brightness in Brightness.values) {
          for (final locale in const [Locale('en'), Locale('sw')]) {
            await pumpSlides(tester, slides, width: width, brightness: brightness, locale: locale);
            expect(tester.takeException(), isNull, reason: '$width $brightness $locale');
          }
        }
      }
    });
  });
}
