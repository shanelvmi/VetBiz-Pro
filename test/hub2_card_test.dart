// HUB2 (1): the phone Home card with its Sales | Vet services switch: the
// segmented control (Sales by default, a tap or a horizontal swipe switches,
// the card's tap still opens All details), the choice saved on the device,
// the exact range under the switch for every period in English and
// Kiswahili, the Vet services figures (the FALLBACK: the daily service
// summaries have no paid or outstanding amount, so Visits, Collected and
// Owed of the facility), roles, the eye, and one outer size for both
// choices, hidden and shown, in every period.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/data/home_card_mode.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/services/dashboard_summary_service.dart';
import 'package:vetbiz_pro/widgets/press_scale.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

const _totals = DashboardPeriodTotals(
  totalSales: 1250000,
  totalCollected: 980000,
  totalProfit: 200000,
  totalRealizedProfit: 150000,
  totalUnrealizedProfit: 50000,
  netProfit: 145000,
  totalExpenses: 55000,
  completedServicesCount: 7,
  totalServiceRevenue: 84000,
);
final _figures = PhoneHomeFigures.from(_totals, owed: 310000);

const _card = ValueKey('phone-home-today-card');
Finder _option(HomeCardMode m) => find.byKey(ValueKey('home-card-mode-${m.key}'));

Future<void> _pump(
  WidgetTester tester, {
  HomeCardMode mode = HomeCardMode.sales,
  ValueChanged<HomeCardMode>? onModeChanged,
  VoidCallback? onAllDetails,
  bool isAdmin = true,
  bool hidden = false,
  String period = 'Today',
  String periodLabel = 'Mon 9 Nov',
  PhoneHomeFigures? figures,
  MatrixLook look = MatrixLook.light,
  Size size = const Size(390, 844),
}) =>
    pumpAtSize(
      tester,
      size: size,
      look: look,
      screen: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topCenter,
            child: TodayCard(
              figures: figures ?? _figures,
              isAdmin: isAdmin,
              period: period,
              periodLabel: periodLabel,
              onPeriodChanged: (_) {},
              onAllDetails: onAllDetails ?? () {},
              amountsHidden: hidden,
              onToggleAmounts: () {},
              mode: mode,
              onModeChanged: onModeChanged ?? (_) {},
            ),
          ),
        ),
      ),
    );

bool _selected(WidgetTester tester, HomeCardMode m) =>
    tester.getSemantics(_option(m)).flagsCollection.isSelected == Tristate.isTrue;

void main() {
  setUpAll(() => initializeDateFormatting());

  group('the switch', () {
    testWidgets('two options, Sales then Vet services, the chosen one selected', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);
      expect(find.text('Sales'), findsOneWidget);
      expect(find.text('Vet services'), findsOneWidget);
      expect(tester.getCenter(_option(HomeCardMode.sales)).dx,
          lessThan(tester.getCenter(_option(HomeCardMode.services)).dx));
      expect(_selected(tester, HomeCardMode.sales), isTrue);
      expect(_selected(tester, HomeCardMode.services), isFalse);
      await _pump(tester, mode: HomeCardMode.services);
      expect(_selected(tester, HomeCardMode.services), isTrue);
      semantics.dispose();
    }, skip: _skip);

    testWidgets('a tap on an option switches and does not open All details', (tester) async {
      final chosen = <HomeCardMode>[];
      var details = 0;
      await _pump(tester, onModeChanged: chosen.add, onAllDetails: () => details++);
      await tester.tap(_option(HomeCardMode.services));
      await tester.pumpAndSettle();
      expect(chosen, [HomeCardMode.services]);
      expect(details, 0);
      // The card itself still opens All details.
      await tester.tap(find.byKey(_card), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(details, 1);
    }, skip: _skip);

    testWidgets('a horizontal swipe on the card switches: left to Vet services, right to Sales', (tester) async {
      final chosen = <HomeCardMode>[];
      var details = 0;
      await _pump(tester, onModeChanged: chosen.add, onAllDetails: () => details++);
      await tester.fling(find.byKey(_card), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      await _pump(tester, mode: HomeCardMode.services, onModeChanged: chosen.add, onAllDetails: () => details++);
      await tester.fling(find.byKey(_card), const Offset(200, 0), 1000);
      await tester.pumpAndSettle();
      expect(chosen, [HomeCardMode.services, HomeCardMode.sales]);
      expect(details, 0, reason: 'a swipe is not a tap');
      // Swiping further the way it already is does nothing.
      await tester.fling(find.byKey(_card), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      expect(chosen, [HomeCardMode.services, HomeCardMode.sales]);
    }, skip: _skip);

    testWidgets('press feedback on the card', (tester) async {
      await _pump(tester);
      expect(find.ancestor(of: find.byKey(_card), matching: find.byType(PressScale)), findsOneWidget);
    }, skip: _skip);
  });

  group('the choice on the device', () {
    test('the stored values, in order, never change', () {
      expect(HomeCardMode.values.map((m) => m.key), ['sales', 'services']);
      expect(HomeCardMode.fromKey(null), HomeCardMode.sales);
      expect(HomeCardMode.fromKey('anything'), HomeCardMode.sales);
    }, skip: _skip);

    testWidgets('Sales by default; a choice is saved and read back', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final first = UiSettingsProvider();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      expect(first.homeCardMode, HomeCardMode.sales);
      await tester.runAsync(() => first.setHomeCardMode(HomeCardMode.services));
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      expect(prefs!.getString('ui_home_card_mode'), 'services');
      final again = UiSettingsProvider();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      expect(again.homeCardMode, HomeCardMode.services);
    }, skip: _skip);
  });

  group('the figures', () {
    testWidgets('Sales: the sales, then Collected, Owed and Net profit (admin)', (tester) async {
      await _pump(tester);
      for (final t in [Money.format(1250000), 'Collected', Money.format(980000), 'Owed', Money.format(310000)]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Net profit'), findsOneWidget);
      expect(find.text(Money.format(145000)), findsOneWidget);
    }, skip: _skip);

    testWidgets('Vet services (fallback): service revenue, then Visits, Collected and Owed', (tester) async {
      await _pump(tester, mode: HomeCardMode.services);
      expect(find.text(Money.format(84000)), findsOneWidget, reason: 'totalServiceRevenue');
      expect(find.text(Money.format(1250000)), findsNothing);
      final labels = ['Visits', 'Collected', 'Owed'];
      for (final t in [...labels, '7', Money.format(980000), Money.format(310000)]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Net profit'), findsNothing, reason: 'no service profit column in the fallback');
      final xs = [for (final l in labels) tester.getTopLeft(find.text(l)).dx];
      expect(xs, orderedEquals([...xs]..sort()));
    }, skip: _skip);

    testWidgets('no sales, no visits: the reserved line says so', (tester) async {
      const none = PhoneHomeFigures(sales: 0, collected: 0, owed: 0, netProfit: 0);
      await _pump(tester, figures: none);
      expect(find.text('No sales yet'), findsOneWidget);
      await _pump(tester, figures: none, mode: HomeCardMode.services);
      expect(find.text('No visits yet'), findsOneWidget);
      expect(find.text('No sales yet'), findsNothing);
    }, skip: _skip);

    testWidgets('an assistant sees no Net profit in either choice', (tester) async {
      await _pump(tester, isAdmin: false);
      expect(find.text('Net profit'), findsNothing);
      expect(find.text(Money.format(145000)), findsNothing);
      expect(find.text('Collected'), findsOneWidget);
      await _pump(tester, isAdmin: false, mode: HomeCardMode.services);
      expect(find.text('Net profit'), findsNothing);
      expect(find.text('Visits'), findsOneWidget);
    }, skip: _skip);

    testWidgets('the eye hides every amount in both choices; Visits is a count and stays', (tester) async {
      await _pump(tester, hidden: true);
      for (final v in [1250000.0, 980000.0, 310000.0, 145000.0]) {
        expect(find.text(Money.format(v)), findsNothing);
      }
      await _pump(tester, hidden: true, mode: HomeCardMode.services);
      expect(find.text(Money.format(84000)), findsNothing);
      expect(find.text('7'), findsOneWidget);
    }, skip: _skip);
  });

  group('the exact range under the switch', () {
    final now = DateTime(2026, 11, 12, 15, 30);
    for (final locale in ['en', 'sw']) {
      for (final period in dashboardPeriods) {
        testWidgets('$locale $period', (tester) async {
          final label = dashboardPeriodRangeLabel(
              lookupAppLocalizations(Locale(locale)), period, dashboardPeriodRange(period, now: now),
              locale: locale);
          await _pump(tester,
              period: period,
              periodLabel: label,
              size: const Size(360, 740),
              look: locale == 'sw' ? MatrixLook.kiswahili : MatrixLook.light);
          expect(tester.takeException(), isNull);
          final shown = find.text(label);
          expect(shown, findsOneWidget);
          // Under the switch, inside the card, on the left.
          final sw = tester.getRect(_option(HomeCardMode.sales));
          expect(tester.getTopLeft(shown).dy, greaterThanOrEqualTo(sw.bottom - 8));
          expect(tester.getRect(shown).right, lessThanOrEqualTo(tester.getRect(find.byKey(_card)).right));
        }, skip: _skip);
      }
    }
  });

  group('one outer size', () {
    for (final look in [MatrixLook.light, MatrixLook.kiswahili]) {
      testWidgets('${look.name}: both choices, hidden and shown, every period, admin and assistant', (tester) async {
        Size? first;
        for (final mode in HomeCardMode.values) {
          for (final hidden in [false, true]) {
            for (final period in dashboardPeriods) {
              for (final isAdmin in [true, false]) {
                await _pump(tester,
                    mode: mode,
                    hidden: hidden,
                    period: period,
                    isAdmin: isAdmin,
                    figures: ph4BigFigures,
                    look: look,
                    size: const Size(360, 740));
                expect(tester.takeException(), isNull);
                final size = tester.getSize(find.byKey(_card));
                first ??= size;
                expect(size, first, reason: '$mode hidden $hidden $period admin $isAdmin');
              }
            }
          }
        }
      }, skip: _skip);
    }
  });
}
