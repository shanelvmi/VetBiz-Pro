import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/services/announcement_service.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_motion.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/widgets/updates_card.dart';
import 'package:vetbiz_pro/widgets/updates_carousel.dart';
import 'package:vetbiz_pro/widgets/updates_parts.dart';

import 'helpers/updates_harness.dart';

// AN6, written before the change: no arrows anywhere; small 8 px dots with
// 24 px wide, 48 px high tap areas, the active one a 28 px pill that fills
// over the slide's time and pauses on hover, touch and focus; a PageView
// that slides in from the right, follows the finger and the mouse, loops
// forward, goes in a tapped dot's direction, answers the Left and Right
// keys; one slide: no dots, the same row height; 3:1 in every theme.
const _skip = false;

final _three = [textUpdate('1'), textUpdate('2'), textUpdate('3')];

double _fill(WidgetTester tester) => tester.widget<FractionallySizedBox>(find.byKey(UpdatesDots.pillFillKey)).widthFactor!;

Rect _title(WidgetTester tester, String id) => tester.getRect(find.text('Title $id'));

/// Frame by frame until both slides are in view (the slide has started).
Future<void> _untilBoth(WidgetTester tester, String a, String b) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (find.text('Title $a').evaluate().isNotEmpty && find.text('Title $b').evaluate().isNotEmpty) return;
  }
  fail('Title $a and Title $b were never in view together');
}

Future<void> _settleSlide(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(AppMotion.updatesSlide);
  await tester.pump(AppMotion.updatesSlide);
  await tester.pump();
}

void main() {
  setUp(() => UpdatesSlides.debugTimerStarts = 0);

  for (final width in [390.0, 768.0, 1200.0]) {
    testWidgets('$width: no arrows', (tester) async {
      await pumpSlides(tester, _three, width: width);
      for (final icon in [Icons.arrow_back, Icons.arrow_forward, Icons.chevron_left, Icons.chevron_right]) {
        expect(find.byIcon(icon), findsNothing, reason: '$icon');
      }
      expect(find.descendant(of: find.byType(UpdatesSlides), matching: find.byType(IconButton)), findsNothing);
    }, skip: _skip);
  }

  testWidgets('the dots: 8 px with 24 x 48 px tap areas; the active one a 28 x 8 px pill', (tester) async {
    await pumpSlides(tester, _three);
    expect(tester.getSize(find.byKey(UpdatesDots.dotKey(0))), const Size(UpdatesMetrics.pill, UpdatesMetrics.dot));
    expect(UpdatesMetrics.pill, 28);
    expect(UpdatesMetrics.dot, 8);
    expect(UpdatesMetrics.dotSlot, 24);
    for (final i in [1, 2]) {
      expect(tester.getSize(find.byKey(UpdatesDots.dotKey(i))), const Size.square(UpdatesMetrics.dot));
    }
    for (final i in [0, 1, 2]) {
      final slot = tester.getSize(find.byKey(UpdatesDots.slotKey(i)));
      expect(slot.width, greaterThanOrEqualTo(UpdatesMetrics.dotSlot));
      expect(slot.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    }
  }, skip: _skip);

  testWidgets('the pill fills over the slide\'s time, pauses on hover, resumes when the pointer leaves', (tester) async {
    await pumpSlides(tester, _three);
    await tester.pump(AppTimeouts.updatesAdvance * 0.5);
    expect(_fill(tester), closeTo(0.5, 0.05));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(frame(tester).center);
    await tester.pump();
    final paused = _fill(tester);
    await tester.pump(AppTimeouts.updatesAdvance * 2);
    expect(_fill(tester), closeTo(paused, 0.01), reason: 'paused where it was');
    expect(find.text('Title 1'), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.pump(AppTimeouts.updatesAdvance * 0.2);
    expect(_fill(tester), closeTo(paused + 0.2, 0.05), reason: 'resumed from there');
  }, skip: _skip);

  testWidgets('the pill pauses while a finger touches and resumes after', (tester) async {
    await pumpSlides(tester, _three, width: 390);
    await tester.pump(AppTimeouts.updatesAdvance * 0.3);
    final finger = await tester.startGesture(frame(tester).center, kind: PointerDeviceKind.touch);
    await tester.pump();
    final paused = _fill(tester);
    await tester.pump(AppTimeouts.updatesAdvance * 2);
    expect(_fill(tester), closeTo(paused, 0.01));
    await finger.up();
    await tester.pump();
    await tester.pump(AppTimeouts.updatesAdvance * 0.2);
    expect(_fill(tester), greaterThan(paused + 0.1));
  }, skip: _skip);

  testWidgets('reduced motion: no fill, no auto-advance, the active pill simply wide', (tester) async {
    await pumpSlides(tester, _three, reduceMotion: true);
    expect(tester.getSize(find.byKey(UpdatesDots.dotKey(0))).width, UpdatesMetrics.pill);
    expect(_fill(tester), 1);
    await tester.pump(AppTimeouts.updatesAdvance * 3);
    expect(find.text('Title 1'), findsOneWidget);
    expect(UpdatesSlides.debugTimerStarts, 0);
    await tester.tap(find.byKey(UpdatesDots.slotKey(2)));
    await tester.pump();
    expect(find.text('Title 3'), findsOneWidget, reason: 'instant');
    expect(find.text('Title 1'), findsNothing);
  }, skip: _skip);

  testWidgets('auto-advance slides in from the right and loops forward from the last to the first', (tester) async {
    await pumpSlides(tester, _three);
    for (final (from, to) in [('1', '2'), ('2', '3'), ('3', '1')]) {
      await tester.pump(AppTimeouts.updatesAdvance);
      await _untilBoth(tester, from, to);
      expect(_title(tester, to).center.dx, greaterThan(_title(tester, from).center.dx), reason: '$to comes from the right of $from');
      await _settleSlide(tester);
      expect(find.text('Title $to'), findsOneWidget);
      expect(find.text('Title $from'), findsNothing);
    }
  }, skip: _skip);

  testWidgets('the outgoing slide moves about 70 percent as far as the incoming one', (tester) async {
    await pumpSlides(tester, _three);
    final start1 = _title(tester, '1').center.dx;
    await tester.pump(AppTimeouts.updatesAdvance);
    await _untilBoth(tester, '1', '2');
    await tester.pump(AppMotion.updatesSlide * 0.1);
    final out = start1 - _title(tester, '1').center.dx;
    final incoming = (start1 + frame(tester).width) - _title(tester, '2').center.dx;
    expect(out / incoming, closeTo(AppMotion.updatesOutgoingTravel, 0.05));
  }, skip: _skip);

  testWidgets('a dot slides in the direction of that dot: a later one from the right, an earlier one from the left', (tester) async {
    await pumpSlides(tester, _three);
    await tester.tap(find.byKey(UpdatesDots.slotKey(1)));
    await _untilBoth(tester, '1', '2');
    expect(_title(tester, '2').center.dx, greaterThan(_title(tester, '1').center.dx), reason: 'from the right');
    await _settleSlide(tester);
    expect(find.text('Title 2'), findsOneWidget);
    await tester.tap(find.byKey(UpdatesDots.slotKey(0)));
    await _untilBoth(tester, '2', '1');
    expect(_title(tester, '1').center.dx, lessThan(_title(tester, '2').center.dx), reason: 'from the left');
    await _settleSlide(tester);
    expect(find.text('Title 1'), findsOneWidget);
    // Two dots ahead: it passes the one between, still from the right.
    await tester.tap(find.byKey(UpdatesDots.slotKey(2)));
    await _untilBoth(tester, '1', '2');
    expect(_title(tester, '2').center.dx, greaterThan(_title(tester, '1').center.dx));
    await _settleSlide(tester);
    expect(find.text('Title 3'), findsOneWidget);
  }, skip: _skip);

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets('a ${kind.name} drag moves the page, following the pointer', (tester) async {
      await pumpSlides(tester, _three);
      final start = _title(tester, '1').center.dx;
      final drag = await tester.startGesture(frame(tester).center, kind: kind);
      await drag.moveBy(const Offset(-40, 0));
      await drag.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect(_title(tester, '1').center.dx, lessThan(start - 50), reason: 'follows the pointer');
      await drag.moveBy(const Offset(-300, 0));
      await drag.up();
      await _settleSlide(tester);
      await tester.pump(AppMotion.updatesSlide);
      expect(find.text('Title 2'), findsOneWidget);
      expect(find.text('Title 1'), findsNothing);
    }, skip: _skip);
  }

  testWidgets('the keyboard: one Tab stop on the dots with a visible ring; Right and Left move', (tester) async {
    await pumpSlides(tester, _three);
    Color ring() => ((tester.widget<DecoratedBox>(find.byKey(UpdatesDots.focusRingKey)).decoration as BoxDecoration).border! as Border).top.color;
    expect(ring().a, 0, reason: 'no ring before focus');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ring().a, greaterThan(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _settleSlide(tester);
    expect(find.text('Title 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _settleSlide(tester);
    expect(find.text('Title 1'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _settleSlide(tester);
    expect(find.text('Title 3'), findsOneWidget, reason: 'Left from the first goes to the last');
    // The group is the page's only stop here: the next Tab comes back to
    // it, never to a single dot.
    final group = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(group), reason: 'one Tab stop for the group');
  }, skip: _skip);

  testWidgets('each dot: "Slide n of total", a button, with the selected state', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSlides(tester, _three);
    expect(enL10n.updates_slideOf(2, 3), 'Slide 2 of 3');
    expect(tester.getSemantics(find.bySemanticsLabel('Slide 1 of 3')), isSemantics(isButton: true, isSelected: true));
    expect(tester.getSemantics(find.bySemanticsLabel('Slide 2 of 3')), isSemantics(isButton: true, isSelected: false));
    handle.dispose();
  }, skip: _skip);

  testWidgets('one slide: no dots, still, and the controls row keeps its height', (tester) async {
    await pumpSlides(tester, [textUpdate('1')]);
    final one = tester.getSize(find.byType(UpdatesSlides)).height;
    expect(find.byKey(UpdatesDots.dotKey(0)), findsNothing);
    await tester.pump(AppTimeouts.updatesAdvance * 2);
    expect(UpdatesSlides.debugTimerStarts, 0);
    await pumpSlides(tester, _three);
    expect(tester.getSize(find.byType(UpdatesSlides)).height, one);
  }, skip: _skip);

  for (final theme in AppColorTheme.all) {
    for (final brightness in Brightness.values) {
      testWidgets('${theme.id} ${brightness.name}: the dots, the pill and its fill read at 3:1 or more on the card', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.build(theme, brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 520,
                child: UpdatesCard(wide: false, child: UpdatesSlides(slides: <Announcement>[..._three], now: () => testNow, imageFor: goodImage)),
              ),
            ),
          ),
        ));
        await tester.pump();
        final card = AppColors.fromTheme(theme, brightness: brightness).surface;
        Color colorOf(Finder f) {
          final w = tester.widget(f);
          return w is ColoredBox ? w.color : ((w as dynamic).decoration as BoxDecoration).color!;
        }
        final fill = find.descendant(of: find.byKey(UpdatesDots.pillFillKey), matching: find.byType(ColoredBox));
        for (final (name, color) in [
          ('pill', colorOf(find.byKey(UpdatesDots.dotKey(0)))),
          ('fill', colorOf(fill.first)),
          ('dot', colorOf(find.byKey(UpdatesDots.dotKey(1)))),
        ]) {
          expect(ColorMath.contrast(ColorMath.composite(color, card), card), greaterThanOrEqualTo(3), reason: name);
        }
      }, skip: _skip);
    }
  }

  testWidgets('no overflow: 360 to 1200, Light, Dark, Kiswahili; one and several', (tester) async {
    for (final width in [360.0, 390.0, 768.0, 1024.0, 1200.0]) {
      for (final slides in [[textUpdate('1')], _three]) {
        for (final (brightness, locale) in const [
          (Brightness.light, Locale('en')),
          (Brightness.dark, Locale('en')),
          (Brightness.light, Locale('sw')),
        ]) {
          await pumpSlides(tester, slides, width: width, brightness: brightness, locale: locale);
          expect(tester.takeException(), isNull, reason: '$width ${slides.length} $brightness $locale');
        }
      }
    }
  }, skip: _skip);
}
