// HUB3 (2): the live line under the Today card's amount. It always shows the
// facility's latest activity on one muted line ("Sale · Amina Juma · Tsh
// 45,000 · 10:15"), from the activity entry as stored (the English
// description is read, never shown translated, and never changed), after a
// small dot: solid while the data connection is live, a muted ring and
// "Offline" when it is not. A new event slides in with a soft highlight
// (instant under reduced motion); the eye swaps the amount for UI3's dots;
// an empty facility keeps the same height with no text; a tap opens the
// activity log.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/screens/dashboard/home_live_line.dart';

import 'helpers/screen_size_matrix.dart';
import 'helpers/test_clock.dart';

const _skip = false;

const _line = ValueKey('home-live-line');
const _text = ValueKey('home-live-text');

Map<String, dynamic> _entry(String type, String description, DateTime at, {String? targetUserId}) => {
      'userId': 'u1',
      'userName': 'Asha',
      'actionType': type,
      'description': description,
      'timestamp': Timestamp.fromDate(at),
      if (targetUserId != null) 'targetUserId': targetUserId,
    };

final _l = lookupAppLocalizations(const Locale('en'));
final _sw = lookupAppLocalizations(const Locale('sw'));

String _say(HomeLiveEvent e, {AppLocalizations? l, bool amount = true, String locale = 'en'}) =>
    homeLiveText(l ?? _l, e, now: testNow, locale: locale, showAmount: amount);

Future<void> _pump(
  WidgetTester tester, {
  HomeLiveEvent? event,
  bool online = true,
  bool hidden = false,
  bool showAmounts = true,
  VoidCallback? onTap,
  bool still = false,
  MatrixLook look = MatrixLook.light,
  Size size = const Size(390, 844),
}) =>
    pumpAtSize(
      tester,
      size: size,
      look: look,
      wrap: still
          ? (app) => MediaQuery(data: const MediaQueryData(disableAnimations: true), child: app)
          : null,
      screen: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topLeft,
            child: HomeLiveLine(
              event: event,
              online: online,
              amountsHidden: hidden,
              showAmounts: showAmounts,
              now: () => testNow,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );

HomeLiveEvent _sale(String id, {String client = 'Amina Juma', double amount = 45000, DateTime? at}) =>
    HomeLiveEvent.fromEntry(id, _entry('Sales', 'Recorded sale to $client - ${Money.saved(amount)}', at ?? testNow.copyWith(hour: 10, minute: 15)))!;

void main() {
  setUpAll(() => initializeDateFormatting());

  group('reading an entry (stored text, never changed)', () {
    test('a sale: the client, the amount, the time', () {
      final e = _sale('sale_1');
      expect((e.kind, e.client, e.amount), (HomeLiveKind.sale, 'Amina Juma', 45000));
      expect(_say(e), 'Sale · Amina Juma · ${Money.format(45000)} · 10:15');
    }, skip: _skip);

    test('a visit: the client and the time, no amount', () {
      final e = HomeLiveEvent.fromEntry('service_1',
          _entry('Services', 'Recorded service for Hamisi Ally - ${Money.saved(30000)}', testNow.copyWith(hour: 10, minute: 5)))!;
      expect(e.kind, HomeLiveKind.visit);
      expect(_say(e), 'Visit · Hamisi Ally · 10:05');
    }, skip: _skip);

    test('a payment: the client, the amount, the time', () {
      final e = HomeLiveEvent.fromEntry('p1',
          _entry('Debtors', 'Recorded payment of ${Money.saved(20000)} from Neema Paulo', testNow.copyWith(hour: 9, minute: 40)))!;
      expect((e.kind, e.client, e.amount), (HomeLiveKind.payment, 'Neema Paulo', 20000));
      expect(_say(e), 'Payment · Neema Paulo · ${Money.format(20000)} · 09:40');
    }, skip: _skip);

    test('a walk-in sale reads "Walk-in" (and its Kiswahili label)', () {
      final e = _sale('sale_2', client: 'Walk-in');
      expect(_say(e), startsWith('Sale · Walk-in · '));
      expect(_say(e, l: _sw, locale: 'sw'), contains(' · ${_sw.common_walkIn} · '));
    }, skip: _skip);

    test('anything else: its type and the time, no client, no amount (an expense never shows its amount)', () {
      final e = HomeLiveEvent.fromEntry('t1',
          _entry('Transactions', 'Added expense: Rent - ${Money.saved(300000)}', testAt(8)))!;
      expect(e.kind, HomeLiveKind.other);
      expect(_say(e), 'Transactions · 08:00');
      final deleted = HomeLiveEvent.fromEntry('d1', _entry('Sales', 'Deleted sale to Amina - ${Money.saved(1)}', testNow))!;
      expect(deleted.kind, HomeLiveKind.other, reason: 'a deletion is not a new sale');
    }, skip: _skip);

    test('the time: HH:mm today, "Yesterday 16:40", else "Wed 04 Nov"', () {
      expect(_say(_sale('a', at: testNow.copyWith(hour: 0, minute: 1))), endsWith(' · 00:01'));
      expect(_say(_sale('b', at: testNow.subtract(const Duration(days: 1)).copyWith(hour: 16, minute: 40))),
          endsWith(' · Yesterday 16:40'));
      expect(_say(_sale('c', at: DateTime(2026, 11, 4, 12))), endsWith(' · Wed 04 Nov'));
      expect(_say(_sale('c', at: DateTime(2026, 11, 4, 12)), l: _sw, locale: 'sw'), isNot(contains('Wed')));
    }, skip: _skip);

    test('no amount when the role may not see it', () {
      expect(_say(_sale('s'), amount: false), 'Sale · Amina Juma · 10:15');
    }, skip: _skip);

    test('an entry with no time yet (the server stamp pending) is still shown, with no time', () {
      final data = _entry('Sales', 'Recorded sale to Amina Juma - ${Money.saved(45000)}', testNow)..remove('timestamp');
      final e = HomeLiveEvent.fromEntry('x', data)!;
      expect(_say(e), 'Sale · Amina Juma · ${Money.format(45000)}');
    }, skip: _skip);
  });

  group('the line', () {
    testWidgets('the latest event after a solid live dot', (tester) async {
      await _pump(tester, event: _sale('sale_1'));
      expect(find.byKey(const ValueKey('home-live-dot')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-live-ring')), findsNothing);
      expect(find.text('Sale · Amina Juma · ${Money.format(45000)} · 10:15', findRichText: true), findsOneWidget);
    }, skip: _skip);

    testWidgets('offline: a muted ring and the word Offline, the event kept', (tester) async {
      await _pump(tester, event: _sale('sale_1'), online: false);
      expect(find.byKey(const ValueKey('home-live-ring')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-live-dot')), findsNothing);
      expect(find.textContaining('Offline', findRichText: true), findsOneWidget);
      expect(find.textContaining('Amina Juma', findRichText: true), findsOneWidget);
    }, skip: _skip);

    testWidgets('hidden amounts: the amount becomes the four soft dots, nothing else changes', (tester) async {
      await _pump(tester, event: _sale('sale_1'), hidden: true);
      expect(find.textContaining(Money.format(45000), findRichText: true), findsNothing);
      expect(find.textContaining('Amina Juma', findRichText: true), findsOneWidget);
      expect(find.textContaining('10:15', findRichText: true), findsOneWidget);
      expect(find.byKey(const ValueKey('home-live-hidden-amount')), findsOneWidget);
    }, skip: _skip);

    testWidgets('an empty facility: the same height, no text', (tester) async {
      await _pump(tester, event: _sale('sale_1'));
      final full = tester.getSize(find.byKey(_line));
      await _pump(tester);
      expect(tester.getSize(find.byKey(_line)), full);
      expect(find.byKey(_text), findsNothing);
      await _pump(tester, event: _sale('sale_1', client: 'Mwanaisha Abdallah Mohamedi Shabani wa Kijiji cha Mwembeni Juu', amount: 12345678),
          size: const Size(360, 740));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(_line)).height, full.height, reason: 'one line, ellipsis');
    }, skip: _skip);

    testWidgets('a new event slides and fades in with a soft highlight, then settles', (tester) async {
      await _pump(tester, event: _sale('sale_1'));
      expect(find.byKey(const ValueKey('home-live-highlight')), findsNothing, reason: 'the first event is not news');
      await _pump(tester, event: _sale('sale_2', client: 'Juma Hassan'));
      // pumpAtSize let 300 ms pass: past the slide, the highlight still fading.
      expect(find.byKey(const ValueKey('home-live-highlight')), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-live-highlight')), findsNothing);
      expect(find.textContaining('Juma Hassan', findRichText: true), findsOneWidget);
    }, skip: _skip);

    testWidgets('reduced motion: a new event is shown at once, no highlight', (tester) async {
      await _pump(tester, event: _sale('sale_1'), still: true);
      await _pump(tester, event: _sale('sale_2', client: 'Juma Hassan'), still: true);
      expect(find.byKey(const ValueKey('home-live-highlight')), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.textContaining('Juma Hassan', findRichText: true), findsOneWidget);
    }, skip: _skip);

    testWidgets('a tap opens the activity; with no event nothing happens', (tester) async {
      var taps = 0;
      await _pump(tester, event: _sale('sale_1'), onTap: () => taps++);
      await tester.tap(find.byKey(_line));
      expect(taps, 1);
      await _pump(tester, onTap: () => taps++);
      await tester.tap(find.byKey(_line), warnIfMissed: false);
      expect(taps, 1);
    }, skip: _skip);

    testWidgets('Kiswahili and Dark: one line, no overflow', (tester) async {
      for (final look in [MatrixLook.kiswahili, MatrixLook.dark]) {
        await _pump(tester, event: _sale('sale_1', amount: 12345678), online: false, look: look, size: const Size(360, 640));
        expect(tester.takeException(), isNull);
      }
    }, skip: _skip);
  });
}
