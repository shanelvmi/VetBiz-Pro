// PH5a (docs/design/phone_list_pattern.md): Services on a phone. The app bar
// with its back arrow (R1), the Record Visit button (R2: collapses and
// extends on scroll, hidden with the keyboard, through the locked-facility
// guard), the filter sheet against the toolbar (R3), the summary against the
// cards (R4), the rows (R6) and the loading, empty and error states (R9).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/screens/services/add_edit_service_screen.dart';
import 'package:vetbiz_pro/screens/services/services_screen.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/phone_list_harness.dart';

const _skip = false;

const _phone = Size(390, 844);
const _wide = Size(1200, 800);

Finder _key(String k) => find.byKey(ValueKey(k));
Finder get _list => find.descendant(of: _key('phoneList-scroll'), matching: find.byType(Scrollable)).first;
Finder _inSheet(String text) => find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

final _four = [
  Ph5Service('v1', ph5When(0, minutes: 5), client: 'Amina Juma', amount: 20000, paid: 20000, method: 'Cash', receipt: 1),
  Ph5Service('v2', ph5When(0, minutes: 50), amount: 15000, paid: 0, category: 'Preventive', method: 'Cash', receipt: 2),
  Ph5Service('v3', ph5When(1), client: 'Baraka Mushi', amount: 30000, paid: 10000, category: 'Surgical', method: 'mpesa', receipt: 3),
  Ph5Service('v4', ph5When(5), client: 'Neema Ally', amount: 10000, paid: 10000, category: 'Preventive', method: 'mpesa', receipt: 4),
];

final _many = [
  for (var i = 0; i < 24; i++) Ph5Service('m$i', ph5When(i ~/ 4, minutes: i), client: 'Client $i', amount: 1000, receipt: 10 + i),
];

Future<Ph5App> _services(WidgetTester tester,
        {Size size = _phone, List<Ph5Service>? services, bool locked = false, bool settle = true, bool reduceMotion = false}) =>
    pumpPh5(tester, (fs) => ServicesScreen(firestore: fs),
        size: size,
        pushed: true,
        locked: locked,
        settle: settle,
        reduceMotion: reduceMotion,
        seed: (fs) => ph5SeedServices(fs, services ?? _four));

/// Whether the button shows its label (extended) or only its icon.
bool _extended(WidgetTester tester) =>
    find.descendant(of: _key('phoneList-fab'), matching: find.text('Record Visit')).evaluate().isNotEmpty;

Set<String> _rowIds(WidgetTester tester) => {
      for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('phoneList-row-')).evaluate())
        (e.widget.key as ValueKey<String>).value.substring('phoneList-row-'.length),
    };

/// The skeleton's rows (keyed phoneList-skeletonRow-0 to -5).
final _skeletonRows = find.byWidgetPredicate(
    (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('phoneList-skeletonRow-'));

void main() {
  group('the app bar (R1)', () {
    testWidgets('opened from More: the back arrow, the title only, search, one overflow menu with Archive', (tester) async {
      await _services(tester);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.text('Service Records'), findsOneWidget);
      expect(find.byTooltip('Search'), findsOneWidget);
      await tester.tap(find.byTooltip('Show menu'));
      await ph5Settle(tester);
      expect(find.text('Archive'), findsOneWidget);
    }, skip: _skip);
  });

  group('Record Visit (R2)', () {
    testWidgets('extended at the bottom right; collapses scrolling down, extends scrolling up', (tester) async {
      await _services(tester, services: _many);
      final fab = _key('phoneList-fab');
      expect(_extended(tester), isTrue);
      expect(tester.getBottomRight(fab).dx, greaterThan(_phone.width - 40));
      await tester.drag(_list, const Offset(0, -300));
      await ph5Settle(tester);
      expect(_extended(tester), isFalse);
      expect(fab, findsOneWidget);
      await tester.drag(_list, const Offset(0, 150));
      await ph5Settle(tester);
      expect(_extended(tester), isTrue);
    }, skip: _skip);

    testWidgets('the last row is never under the button', (tester) async {
      await _services(tester, services: _many);
      for (var i = 0; i < 3; i++) {
        await tester.drag(_list, const Offset(0, -3000));
        await ph5Settle(tester);
      }
      final lastRow = tester.getRect(_key('phoneList-row-m23'));
      expect(lastRow.bottom, lessThanOrEqualTo(tester.getRect(_key('phoneList-fab')).top));
    }, skip: _skip);

    testWidgets('hidden while the keyboard is open', (tester) async {
      await _services(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      // The Scaffold animates the button out.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(_key('phoneList-fab'), findsNothing);
    }, skip: _skip);

    testWidgets('locked: the guard holds and no form opens', (tester) async {
      await _services(tester, locked: true);
      await tester.tap(_key('phoneList-fab'));
      await ph5Settle(tester);
      expect(find.byType(AddEditServiceScreen), findsNothing);
    }, skip: _skip);

    testWidgets('unlocked: the form opens', (tester) async {
      await _services(tester);
      await tester.tap(_key('phoneList-fab'));
      await ph5Settle(tester);
      expect(find.byType(AddEditServiceScreen), findsOneWidget);
      // The form's own phone layout is PH6 (it overflows at 390 today).
      while (tester.takeException() != null) {}
    }, skip: _skip);
  });

  group('filters (R3) and the summary (R4)', () {
    testWidgets('the sheet\'s category and status give the toolbar\'s results', (tester) async {
      await _services(tester, size: _wide);
      await tester.tap(find.text('Category: All'));
      await ph5Settle(tester);
      await tester.tap(find.text('Category: Preventive').last);
      await ph5Settle(tester);
      final toolbar = {for (final e in find.textContaining(' visit').evaluate()) (e.widget as Text).data!};
      expect(toolbar, {'Preventive visit'});
      expect(find.text('Preventive visit'), findsNWidgets(2));

      await _services(tester);
      await tester.tap(find.byTooltip('Filter'));
      await ph5Settle(tester);
      for (final field in ['Date', 'Category', 'Status']) {
        expect(_inSheet(field), findsOneWidget);
      }
      await tester.tap(_inSheet('Preventive'));
      await tester.pump();
      await tester.tap(_inSheet('Apply'));
      await ph5Settle(tester);
      expect(_rowIds(tester), {'v2', 'v4'});
    }, skip: _skip);

    testWidgets('the summary line and sheet are the cards\' figures', (tester) async {
      await _services(tester);
      expect(find.text('Last 30 days: 4 services, ${Money.format(75000)}'), findsOneWidget);
      await tester.tap(find.text('Summary'));
      await ph5Settle(tester);
      for (final (label, value) in [
        ('Total Services', '4'),
        ('Paid Amount', Money.format(40000)),
        ('Outstanding', Money.format(35000)),
        ('Digital Payments', Money.format(20000)),
      ]) {
        final row = find.ancestor(of: _inSheet(label), matching: find.byType(Row)).first;
        expect(find.descendant(of: row, matching: find.text(value)), findsOneWidget, reason: label);
      }
    }, skip: _skip);

    testWidgets('a row: the category icon, client and amount, category and time, status as text', (tester) async {
      await _services(tester);
      final row = _key('phoneList-row-v3');
      for (final t in ['Baraka Mushi', Money.format(30000), 'Surgical', 'Partial']) {
        expect(find.descendant(of: row, matching: find.text(t)), findsOneWidget, reason: t);
      }
      expect(find.descendant(of: row, matching: find.byType(Icon)), findsWidgets);
    }, skip: _skip);
  });

  group('states (R9)', () {
    testWidgets('loading: six skeleton rows, with a pulse; still under reduced motion', (tester) async {
      for (final still in [false, true]) {
        // The list's first page is held back, so it stays loading.
        final db = CountingFirestore()..holdGets = Completer<void>();
        await tester.runAsync(() => ph5SeedServices(db.inner, _four));
        await pumpPh5(tester, (fs) => ServicesScreen(firestore: fs),
            pushed: true, firestore: db, settle: false, reduceMotion: still);
        final skeleton = _key('phoneList-skeleton');
        expect(skeleton, findsOneWidget);
        expect(find.descendant(of: skeleton, matching: _skeletonRows), findsNWidgets(6));
        // RV2: the first load's skeleton is the reveal's, which pulses as a
        // whole (SkeletonPulse around it), still under reduced motion.
        final pulse = tester.widget<FadeTransition>(find
            .ancestor(of: skeleton, matching: find.descendant(of: find.byType(SkeletonPulse), matching: find.byType(FadeTransition)))
            .first);
        final at = pulse.opacity.value;
        await tester.pump(const Duration(milliseconds: 300));
        expect(pulse.opacity.value == at, still, reason: still ? 'still' : 'pulsing');
        db.holdGets!.complete();
        await ph5Settle(tester);
        expect(skeleton, findsNothing);
      }
    }, skip: _skip);

    testWidgets('empty: an icon, one plain line and Record Visit as a button (through the guard)', (tester) async {
      await _services(tester, services: const [], locked: true);
      final empty = _key('phoneList-empty');
      expect(find.descendant(of: empty, matching: find.text('No services yet')), findsOneWidget);
      expect(find.descendant(of: empty, matching: find.byType(Icon)), findsWidgets);
      await tester.tap(find.descendant(of: empty, matching: find.text('Record Visit')));
      await ph5Settle(tester);
      expect(find.byType(AddEditServiceScreen), findsNothing);
    }, skip: _skip);

    testWidgets('error: the message and Retry, which loads the list again', (tester) async {
      final db = CountingFirestore();
      await tester.runAsync(() => ph5SeedServices(db.inner, _four));
      db.failGets = true;
      await pumpPh5(tester, (fs) => ServicesScreen(firestore: fs), pushed: true, firestore: db);
      expect(_key('phoneList-error'), findsOneWidget);
      db.failGets = false;
      await tester.tap(find.text('Retry'));
      await ph5Settle(tester);
      expect(_key('phoneList-error'), findsNothing);
      expect(_rowIds(tester), {'v1', 'v2', 'v3', 'v4'});
    }, skip: _skip);
  });
}
