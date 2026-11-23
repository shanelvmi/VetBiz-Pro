// PAGE2: Clients on PC/tablet pages on the server, A to Z by name, pageSize +
// 1 a page (the shared pager: Previous via kept pages, no total count). The
// search runs on the server: a name prefix on nameLower, a phone prefix on
// phoneKey (the fields every save writes), 300 ms after typing stops; a slow
// old answer never replaces a newer one, and the rows stay (dimmed) while the
// new ones load. The Clients screen no longer restarts the whole-clients
// listener that facility activation started. The phone keeps its newest-first
// list (ph5b_clients_phone_test).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/client_provider.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';
import 'package:vetbiz_pro/utils/client_duplicate_matcher.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/fake_firestore.dart';
import 'helpers/page1_harness.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'helpers/test_clock.dart';

const _wide = Size(1600, 900);
const _page = AppLimits.pageSize + 1;

String _n(int i) => i.toString().padLeft(2, '0');

/// [count] clients "Client 00".. A to Z; the newest is the last one (so A to
/// Z and newest first disagree). Every fifth is Inactive; every third a Vet.
Future<void> _seed(FirebaseFirestore fs, {int count = 60}) async {
  final clients = facilityCollection(fs, Collections.clients);
  for (var i = 0; i < count; i++) {
    final name = 'Client ${_n(i)}';
    final phone = '07120000${_n(i)}';
    await clients.doc('c${_n(i)}').set({
      'name': name,
      'nameLower': name.toLowerCase(),
      'phone': phone,
      'phoneKey': ClientDuplicateMatcher.phoneKey(phone),
      'address': 'Arusha',
      'types': [if (i % 3 == 0) 'Vet' else 'Farmer'],
      'status': i % 5 == 0 ? 'Inactive' : 'Active',
      'balance': 0,
      'createdAt': Timestamp.fromDate(testNow.subtract(Duration(minutes: count - i))),
    });
  }
}

Future<CountingFirestore> _open(WidgetTester tester,
    {int count = 60, Size size = _wide, MatrixLook look = MatrixLook.light, double textScale = 1, CountingFirestore? db}) async {
  final store = db ?? CountingFirestore();
  await tester.runAsync(() => _seed(store.inner, count: count));
  await pumpPh5(tester, (fs) => ClientsScreen(firestore: fs),
      size: size, pushed: true, firestore: store, look: look, textScale: textScale);
  return store;
}

Finder get _search => find.descendant(of: find.byType(ClientsScreen), matching: find.byType(TextField)).first;

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_search, text);
  await tester.pump(const Duration(milliseconds: 350));
  await ph5Settle(tester);
}

Future<void> _setFilter(WidgetTester tester, int index, String value) async {
  final dropdowns = find.descendant(of: find.byType(ClientsScreen), matching: find.byType(DropdownButton<String>));
  tester.widget<DropdownButton<String>>(dropdowns.at(index)).onChanged!(value);
  await ph5Settle(tester);
}

void main() {
  ph5TestWidgets('page 1 A to Z, Next, Previous; the last page has no Next', (tester) async {
    final db = await _open(tester);
    expect(page1Range(tester), 'Showing 1 to 25');
    expect(find.text('Client 00'), findsOneWidget, reason: 'A to Z: the oldest name first');
    expect(find.text('Client 59'), findsOneWidget, reason: 'the newest: only the Last added card, not on page 1');
    expect(page1PreviousEnabled(tester), isFalse);
    db.resetCounts();
    await page1Next(tester);
    expect(db.reads, lessThanOrEqualTo(_page), reason: 'Next reads pageSize + 1');
    expect(page1Range(tester), 'Showing 26 to 50');
    await page1Next(tester);
    expect(page1Range(tester), 'Showing 51 to 60');
    expect(page1NextEnabled(tester), isFalse);
    db.resetCounts();
    await page1Previous(tester);
    expect(db.reads, 0, reason: 'Previous shows the kept page');
    expect(page1Range(tester), 'Showing 26 to 50');
  });

  ph5TestWidgets('page size goes back to page 1', (tester) async {
    await _open(tester);
    await page1Next(tester);
    await page1PageSize(tester, 10);
    expect(page1BarWidget(tester).currentPage, 1);
    expect(page1Range(tester), 'Showing 1 to 10');
  });

  ph5TestWidgets('a filter change goes back to page 1 and filters on the server', (tester) async {
    await _open(tester);
    await page1Next(tester);
    await _setFilter(tester, 1, 'Inactive');
    expect(page1BarWidget(tester).currentPage, 1);
    expect(page1Range(tester), 'Showing 1 to 12', reason: '12 of the 60 are Inactive');
    await _setFilter(tester, 0, 'Vet');
    // Inactive (i % 5 == 0) and Vet (i % 3 == 0): 00, 15, 30, 45.
    expect(page1Range(tester), 'Showing 1 to 4');
  });

  ph5TestWidgets('empty: the empty text; no Next', (tester) async {
    await _open(tester, count: 0);
    expect(find.text('No clients found'), findsOneWidget);
    expect(page1NextEnabled(tester), isFalse);
  });

  ph5TestWidgets('an error shows the message and Retry; Retry loads the page', (tester) async {
    final db = CountingFirestore()..failGets = true;
    await _open(tester, db: db);
    expect(find.byKey(const ValueKey('pagedList-error')), findsOneWidget);
    db.failGets = false;
    await tester.tap(find.text('Retry'));
    await ph5Settle(tester);
    expect(page1Range(tester), 'Showing 1 to 25');
  });

  ph5TestWidgets('the skeleton on the first load, no spinner', (tester) async {
    final db = CountingFirestore()..holdGets = Completer<void>();
    await _open(tester, db: db);
    expect(find.byKey(const ValueKey('pagedList-skeleton')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    db.holdGets!.complete();
    db.holdGets = null;
    await ph5Settle(tester);
    expect(page1Range(tester), 'Showing 1 to 25');
  });

  ph5TestWidgets('search by name on the server, any case; the no-results text names the search', (tester) async {
    await _open(tester);
    expect(find.text('Search by name or phone'), findsOneWidget);
    await _type(tester, 'CLIENT 5');
    expect(page1Range(tester), 'Showing 1 to 10', reason: 'Client 50 to 59, none of them loaded before');
    expect(find.text('Client 50'), findsOneWidget);
    await _type(tester, 'zawadi');
    expect(find.text('No clients match "zawadi"'), findsOneWidget);
  });

  ph5TestWidgets('search by phone: any common way of typing it', (tester) async {
    await _open(tester);
    await _type(tester, '0712000057');
    expect(page1Range(tester), 'Showing 1 to 1');
    expect(find.text('Client 57'), findsOneWidget);
    await _type(tester, '+255 712 000 04');
    expect(page1Range(tester), 'Showing 1 to 10', reason: 'Client 40 to 49');
  });

  ph5TestWidgets('the clear button and Escape clear the search', (tester) async {
    await _open(tester);
    await _type(tester, 'client 5');
    await tester.tap(find.descendant(of: find.byType(ClientsScreen), matching: find.byIcon(Icons.clear)));
    await tester.pump(const Duration(milliseconds: 350));
    await ph5Settle(tester);
    expect(page1Range(tester), 'Showing 1 to 25');
    await _type(tester, 'client 5');
    await tester.showKeyboard(_search);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 350));
    await ph5Settle(tester);
    expect(find.text('Client 00'), findsOneWidget);
    expect(page1Range(tester), 'Showing 1 to 25');
  });

  ph5TestWidgets('typing 5 letters quickly runs one query', (tester) async {
    final db = await _open(tester);
    db.resetCounts();
    for (final text in ['c', 'cl', 'cli', 'clie', 'clien']) {
      await tester.enterText(_search, text);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 350));
    await ph5Settle(tester);
    expect(db.gets, 1);
    expect(page1Range(tester), 'Showing 1 to 25');
  });

  ph5TestWidgets('a slow first search does not replace a faster second one; the rows stay dimmed meanwhile', (tester) async {
    final db = await _open(tester);
    final slow = Completer<void>();
    db.holdGets = slow;
    await tester.enterText(_search, 'client 1');
    await tester.pump(const Duration(milliseconds: 350));
    await ph5Settle(tester);
    expect(find.byKey(const ValueKey('pagedList-previous')), findsOneWidget, reason: 'the page shown stays, dimmed');
    expect(find.byKey(const ValueKey('pagedList-skeleton')), findsNothing);

    db.holdGets = null;
    await _type(tester, 'client 2');
    expect(find.text('Client 20'), findsOneWidget);

    slow.complete();
    await ph5Settle(tester);
    expect(find.text('Client 20'), findsOneWidget);
    expect(find.text('Client 10'), findsNothing, reason: 'the stale answer for "client 1" is dropped');
    expect(page1Range(tester), 'Showing 1 to 10');
  });

  ph5TestWidgets('reads on open: one page (pageSize + 1) beyond the whole-clients listener', (tester) async {
    const many = 120;
    final db = await _open(tester, count: many);
    // ignore: avoid_print
    print('PAGE2 Clients open (listeners, gets, reads): (${db.listeners}, ${db.gets}, ${db.reads})');
    // In the app facility activation already started the whole-clients
    // listener (its 120 here); the screen reuses it (next test).
    expect(db.reads - many, lessThanOrEqualTo(_page + 2), reason: 'one page + the app\'s setup');
    db.resetCounts();
    await page1Next(tester);
    expect(db.reads, lessThanOrEqualTo(_page));
  });

  test('listenToClients for the facility already listened to opens nothing and reads nothing more', () async {
    final db = CountingFirestore();
    await _seed(db.inner, count: 30);
    final provider = ClientProvider(firestore: db, currentUserInfo: testUserInfo, deletedBy: testDeletedBy);
    provider.listenToClients(testFacilityId);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final first = db.reads;
    provider.listenToClients(testFacilityId);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(db.listeners, 1);
    expect(first, 30);
    expect(db.reads, 30, reason: 'before PAGE2 the screen read every client again');
    provider.dispose();
  });

  test('the phone-search prefix: the common ways a number is typed', () {
    expect(clientPhoneSearchPrefix('0712 345'), '712345');
    expect(clientPhoneSearchPrefix('+255 712'), '712');
    expect(clientPhoneSearchPrefix('00255712'), '712');
    expect(clientPhoneSearchPrefix('712-34'), '71234');
    expect(clientPhoneSearchPrefix('+254 712'), '254712', reason: 'another country keeps its code, as phoneKey does');
    expect(clientPhoneSearchPrefix('Amina'), isNull);
    expect(clientPhoneSearchPrefix('0'), isNull);
    expect(clientPhoneSearchPrefix(''), isNull);
  });

  for (final size in page1Widths) {
    for (final (look, scale) in const [(MatrixLook.light, 1.0), (MatrixLook.light, 1.3), (MatrixLook.kiswahili, 1.3)]) {
      ph5TestWidgets('${size.width.toInt()} ${look.name} text $scale: the page and the bar, no overflow', (tester) async {
        await _open(tester, size: size, look: look, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(page1BarWidget(tester).itemCount, 25);
      });
    }
  }
}
