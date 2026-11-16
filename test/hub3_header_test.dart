// HUB3 (1) and (3): the phone Home card's header and the delta. Row 1 is a
// compact Sales | Visits switch sized to its content (32 px, the chosen
// option a white pill with the card's deep ink) and the period chip with its
// short label, the chip 16 px from the card's right edge as the switch is
// from its left; the exact range stays under the switch. The "No sales yet"
// and "No visits yet" lines are gone. For Today only, a small chip right of
// the big amount says how today compares with yesterday ("up 12% vs
// yesterday", "down 5% vs yesterday", "New" when yesterday had nothing),
// with an arrow, hidden by the eye, never moving the card or the eye.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/data/home_card_mode.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

const _card = ValueKey('phone-home-today-card');
const _track = ValueKey('home-card-mode-track');
const _chip = ValueKey('home-period-chip');
const _delta = ValueKey('home-delta');
Finder _pill(HomeCardMode m) => find.byKey(ValueKey('home-card-mode-pill-${m.key}'));

const _figures = PhoneHomeFigures(sales: 1250000, collected: 980000, owed: 310000, netProfit: 145000, serviceRevenue: 84000, visits: 7);

Future<void> _pump(
  WidgetTester tester, {
  HomeCardMode mode = HomeCardMode.sales,
  String period = 'Today',
  PhoneHomeFigures figures = _figures,
  HomeDelta? delta,
  bool hidden = false,
  MatrixLook look = MatrixLook.light,
  AppColorTheme theme = AppColorTheme.pasture,
  Size size = const Size(390, 844),
}) =>
    pumpAtSize(
      tester,
      size: size,
      look: look,
      colorTheme: theme,
      screen: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topCenter,
            child: TodayCard(
              figures: figures,
              isAdmin: true,
              period: period,
              periodLabel: 'Wed 11 Nov',
              onPeriodChanged: (_) {},
              onAllDetails: () {},
              amountsHidden: hidden,
              onToggleAmounts: () {},
              mode: mode,
              onModeChanged: (_) {},
              delta: delta,
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => initializeDateFormatting());

  group('row 1', () {
    testWidgets('the switch reads Sales | Visits, is 32 high and only as wide as its options', (tester) async {
      await _pump(tester);
      expect(find.text('Sales'), findsOneWidget);
      expect(find.text('Visits'), findsOneWidget);
      expect(find.text('Vet services'), findsNothing);
      final track = tester.getRect(find.byKey(_track));
      expect(track.height, 32);
      final options = tester.getRect(_pill(HomeCardMode.sales)).expandToInclude(tester.getRect(_pill(HomeCardMode.services)));
      // Sized to its content: the two pills and the 3 px insets, not stretched.
      expect(track.width, closeTo(options.width + 2 * 3, 1));
      expect(track.right, lessThan(tester.getRect(find.byKey(_chip)).left), reason: 'not stretched to the chip');
    }, skip: _skip);

    for (final look in [MatrixLook.light, MatrixLook.dark]) {
      for (final theme in AppColorTheme.all) {
        // POL2 (owner rule 1: primary means selected): on the flat card the
        // chosen option is a primary pill, its ink still at 4.5.
        testWidgets('the chosen option is a primary pill with onPrimary ink (${look.name}, ${theme.id})', (tester) async {
          for (final mode in HomeCardMode.values) {
            await _pump(tester, mode: mode, look: look, theme: theme);
            final pill = tester.widget<AnimatedContainer>(_pill(mode));
            final fill = (pill.decoration! as BoxDecoration).color!;
            expect(fill.a, 1, reason: 'opaque');
            expect(fill, tester.element(_pill(mode)).colors.primary, reason: 'primary');
            final label = mode == HomeCardMode.sales ? 'Sales' : 'Visits';
            final ink = tester.widget<Text>(find.descendant(of: _pill(mode), matching: find.text(label))).style!.color!;
            expect(ColorMath.contrast(ink, fill), greaterThanOrEqualTo(4.5), reason: '$label on the pill');
            // The other option: no fill, its muted ink on the card.
            final other = HomeCardMode.values.firstWhere((m) => m != mode);
            final otherFill = ((tester.widget<AnimatedContainer>(_pill(other)).decoration! as BoxDecoration).color)!;
            expect(otherFill.a, 0);
          }
        }, skip: _skip);
      }
    }

    testWidgets('the chip shows the short labels: Today, Week, Month, Year', (tester) async {
      for (final (period, label) in [('Today', 'Today'), ('This Week', 'Week'), ('This Month', 'Month'), ('This Year', 'Year')]) {
        await _pump(tester, period: period);
        expect(find.descendant(of: find.byKey(_chip), matching: find.text(label)), findsOneWidget, reason: period);
      }
    }, skip: _skip);

    testWidgets('the chip in Kiswahili: short labels, still inside the card', (tester) async {
      for (final period in dashboardPeriods) {
        await _pump(tester, period: period, look: MatrixLook.kiswahili, size: const Size(360, 740));
        expect(tester.takeException(), isNull);
        expect(tester.getRect(find.byKey(_chip)).right, lessThan(tester.getRect(find.byKey(_card)).right));
      }
    }, skip: _skip);

    for (final width in [360.0, 390.0, 412.0]) {
      testWidgets('equal 16 px margins at $width wide, the chip never touching the edge', (tester) async {
        for (final period in dashboardPeriods) {
          await _pump(tester, period: period, size: Size(width, 844));
          final card = tester.getRect(find.byKey(_card));
          final left = tester.getRect(find.byKey(_track)).left - card.left;
          final right = card.right - tester.getRect(find.byKey(_chip)).right;
          expect(left, closeTo(16, 1), reason: '$period left');
          expect(right, closeTo(left, 1), reason: '$period right equals left');
        }
      }, skip: _skip);
    }

    testWidgets('the exact range stays under the switch, small and muted', (tester) async {
      await _pump(tester);
      final range = find.text('Wed 11 Nov');
      expect(range, findsOneWidget);
      expect(tester.getTopLeft(range).dy, greaterThanOrEqualTo(tester.getRect(find.byKey(_track)).bottom - 8));
      final style = tester.widget<Text>(range).style!;
      expect(style.fontSize, 12);
      final context = tester.element(range);
      // POL2: the card's muted ink is textSecondary on the flat card.
      expect(style.color, context.colors.textSecondary);
    }, skip: _skip);
  });

  group('the removed lines', () {
    testWidgets('no "No sales yet" or "No visits yet" under a zero', (tester) async {
      const none = PhoneHomeFigures(sales: 0, collected: 0, owed: 0, netProfit: 0);
      for (final mode in HomeCardMode.values) {
        await _pump(tester, figures: none, mode: mode);
        expect(find.text('No sales yet'), findsNothing);
        expect(find.text('No visits yet'), findsNothing);
      }
    }, skip: _skip);
  });

  group('the delta (pure)', () {
    test('Today only; up, down, the same, New when yesterday is zero, nothing for two zeros', () {
      expect(homeDeltaFor(period: 'Today', today: 112, yesterday: 100), const HomeDelta.change(12));
      expect(homeDeltaFor(period: 'Today', today: 95, yesterday: 100), const HomeDelta.change(-5));
      expect(homeDeltaFor(period: 'Today', today: 100, yesterday: 100), const HomeDelta.change(0));
      expect(homeDeltaFor(period: 'Today', today: 5000, yesterday: 0), const HomeDelta.fresh());
      expect(homeDeltaFor(period: 'Today', today: 0, yesterday: 0), isNull);
      expect(homeDeltaFor(period: 'Today', today: 10, yesterday: null), isNull, reason: 'yesterday not read yet');
      for (final p in dashboardPeriods.skip(1)) {
        expect(homeDeltaFor(period: p, today: 112, yesterday: 100), isNull, reason: p);
      }
      // Rounded to a whole percent.
      expect(homeDeltaFor(period: 'Today', today: 1, yesterday: 3), const HomeDelta.change(-67));
    }, skip: _skip);
  });

  group('the delta on the card', () {
    testWidgets('up: an arrow and the words, right of the amount', (tester) async {
      await _pump(tester, delta: const HomeDelta.change(12));
      expect(find.descendant(of: find.byKey(_delta), matching: find.text('up 12% vs yesterday')), findsOneWidget);
      expect(find.descendant(of: find.byKey(_delta), matching: find.byIcon(Icons.arrow_upward)), findsOneWidget);
      expect(tester.getRect(find.byKey(_delta)).left, greaterThan(tester.getRect(find.text(Money.format(1250000))).right));
    }, skip: _skip);

    testWidgets('down and New', (tester) async {
      await _pump(tester, delta: const HomeDelta.change(-5));
      expect(find.text('down 5% vs yesterday'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      await _pump(tester, delta: const HomeDelta.fresh());
      expect(find.descendant(of: find.byKey(_delta), matching: find.text('New')), findsOneWidget);
    }, skip: _skip);

    testWidgets('the eye hides it', (tester) async {
      await _pump(tester, delta: const HomeDelta.change(12), hidden: true);
      expect(find.byKey(_delta), findsNothing);
      expect(find.textContaining('vs yesterday'), findsNothing);
    }, skip: _skip);

    testWidgets('it never changes the card\'s size or moves the eye (8-digit amounts, 360 wide, Kiswahili)', (tester) async {
      for (final look in [MatrixLook.light, MatrixLook.kiswahili]) {
        Rect? card, eye;
        for (final delta in [null, const HomeDelta.change(-67), const HomeDelta.change(1234), const HomeDelta.fresh()]) {
          await _pump(tester, figures: ph4BigFigures, delta: delta, look: look, size: const Size(360, 740));
          expect(tester.takeException(), isNull);
          final c = tester.getRect(find.byKey(_card));
          final e = tester.getRect(find.byIcon(Icons.visibility_outlined));
          card ??= c;
          eye ??= e;
          expect(c, card, reason: '$look $delta card');
          expect(e, eye, reason: '$look $delta eye');
        }
      }
    }, skip: _skip);
  });
}
