// PAGE1b: the Activity Log's category chips on PC/tablet are server queries:
// a category is a where clause on the paged query (an assistant's two
// questions both), the numbers are one count() per category. If the index is
// missing (failed-precondition), the note stands in place of the chips, All
// keeps working, loaded rows are never filtered, and nothing retries until
// the tab is opened again.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/screens/activity/activity_log_screen.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/fake_firestore.dart';
import 'helpers/page1_harness.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'helpers/test_clock.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;

const _wide = Size(1600, 900);
const _types = ['Sales', 'Products', 'Account', 'Debtors'];

/// 120 entries a minute apart (e000 newest), the type by i % 4 (Sales,
/// Products, Account, Debtors; e004 is an old 'Sale', shown under Sales).
/// Even ones were done by the signed-in person; odd multiples of 3 were done
/// by an admin about them (as the app writes: the actor is never the
/// target). Admin: 30 of each. Assistant: Sales 30, Account 30, Products 10,
/// Debtors 10 (80 in all).
Future<void> _seed(FirebaseFirestore fs) async {
  final logs = facilityCollection(fs, Collections.activityLogs);
  for (var i = 0; i < 120; i++) {
    await logs.doc('e${i.toString().padLeft(3, '0')}').set({
      'timestamp': Timestamp.fromDate(testNow.subtract(Duration(minutes: i + 1))),
      'userId': i.isEven ? testUserId : 'admin2',
      'userName': i.isEven ? 'Asha Mushi' : 'Juma Hassan',
      'actionType': i == 4 ? 'Sale' : _types[i % 4],
      'description': 'Entry $i',
      if (i.isOdd && i % 3 == 0) 'targetUserId': testUserId,
    });
  }
}

Future<CountingFirestore> _open(WidgetTester tester,
    {bool admin = true, Size size = _wide, MatrixLook look = MatrixLook.light, double textScale = 1, CountingFirestore? db}) async {
  final store = db ?? CountingFirestore();
  await tester.runAsync(() => _seed(store.inner));
  await pumpPh5(tester, (fs) => ActivityLogScreen(isModal: true, firestore: fs, auth: Ph8Auth()),
      size: size, admin: admin, pushed: true, firestore: store, look: look, textScale: textScale);
  await ph5Settle(tester);
  return store;
}

Finder _chip(String label) => find.widgetWithText(ChoiceChip, label);

Future<void> _choose(WidgetTester tester, String label) async {
  await tester.tap(_chip(label));
  await ph5Settle(tester);
}

Finder _row(String text) =>
    find.descendant(of: find.byKey(const ValueKey('activity-table')), matching: find.text(text));

/// The descriptions of the rows shown.
List<int> _shown(WidgetTester tester) => find
    .descendant(of: find.byKey(const ValueKey('activity-table')), matching: find.textContaining(RegExp(r'^Entry \d+$')))
    .evaluate()
    .map((e) => int.parse((e.widget as Text).data!.substring(6)))
    .toList();

void main() {
  ph5TestWidgets('admin: the chips and their numbers; a category pages by cursor from page 1', (tester) async {
    final db = await _open(tester);
    expect(find.byKey(const ValueKey('activity-categoryChips')), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-categoryUnavailable')), findsNothing);
    expect(_chip('All · 120'), findsOneWidget);
    for (final t in _types) {
      expect(_chip('$t · 30'), findsOneWidget, reason: t);
    }
    expect(find.byType(ChoiceChip), findsNWidgets(5), reason: 'no chip for a type with nothing');

    await page1Next(tester);
    expect(page1Range(tester), 'Showing 26 to 50');

    db.resetCounts();
    await _choose(tester, 'Products · 30');
    expect(db.reads, lessThanOrEqualTo(26), reason: 'one page (pageSize + 1)');
    expect(page1Range(tester), 'Showing 1 to 25', reason: 'a new category starts at page 1');
    expect(_shown(tester).every((i) => i % 4 == 1), isTrue);
    expect(page1BarWidget(tester).itemCount, 25);

    db.resetCounts();
    await page1Next(tester);
    expect(db.reads, lessThanOrEqualTo(26));
    expect(page1Range(tester), 'Showing 26 to 30');
    expect(page1NextEnabled(tester), isFalse);
    expect(_shown(tester).every((i) => i % 4 == 1), isTrue);

    await _choose(tester, 'Account · 30');
    expect(page1Range(tester), 'Showing 1 to 25');
    expect(_shown(tester).every((i) => i % 4 == 2), isTrue);

    await _choose(tester, 'All · 120');
    expect(page1Range(tester), 'Showing 1 to 25');
    expect(_shown(tester).take(4), [0, 1, 2, 3]);
  });

  ph5TestWidgets('Sales asks for Sales and the old Sale entries', (tester) async {
    await _open(tester);
    await _choose(tester, 'Sales · 30');
    expect(_row('Entry 4'), findsOneWidget, reason: 'stored as Sale');
    expect(_shown(tester).every((i) => i % 4 == 0), isTrue);
  });

  ph5TestWidgets('assistant: both questions take the category, merged once; the numbers add both', (tester) async {
    final db = await _open(tester, admin: false);
    expect(_chip('All · 80'), findsOneWidget);
    expect(_chip('Sales · 30'), findsOneWidget);
    expect(_chip('Account · 30'), findsOneWidget);
    expect(_chip('Products · 10'), findsOneWidget);
    expect(_chip('Debtors · 10'), findsOneWidget);

    db.resetCounts();
    await _choose(tester, 'Products · 10');
    expect(db.reads, lessThanOrEqualTo(2 * 26), reason: 'one page from each question');
    expect(page1BarWidget(tester).itemCount, 10);
    // About them (done by an admin): 9, 21, 33...
    expect(_shown(tester), [for (var i = 9; i < 120; i += 12) i].take(_shown(tester).length).toList());
    expect(_shown(tester).length, greaterThanOrEqualTo(5));

    await _choose(tester, 'Sales · 30');
    expect(_shown(tester).every((i) => i % 4 == 0 && i.isEven), isTrue, reason: 'their own');
    expect(page1Range(tester), 'Showing 1 to 25');
  });

  ph5TestWidgets('reads on open: one page plus one count() per category', (tester) async {
    final db = await _open(tester);
    // ignore: avoid_print
    print('PAGE1b Activity admin open (listeners, gets, reads): (${db.listeners}, ${db.gets}, ${db.reads})');
    // The page, the facility (retention), the tidy-up, All + 9 categories.
    expect(db.reads, lessThanOrEqualTo(26 + 1 + 2 + 10));
  });

  ph5TestWidgets('reads on open, assistant: two page heads plus two count()s per category', (tester) async {
    final db = await _open(tester, admin: false);
    // ignore: avoid_print
    print('PAGE1b Activity assistant open (listeners, gets, reads): (${db.listeners}, ${db.gets}, ${db.reads})');
    expect(db.reads, lessThanOrEqualTo(2 * 26 + 1 + 2 + 20));
  });

  ph5TestWidgets('index missing: the note, All works, rows not filtered, no retry loop', (tester) async {
    final db = CountingFirestore()..failActionTypeQueries = true;
    await _open(tester, db: db);
    expect(find.byKey(const ValueKey('activity-categoryUnavailable')), findsOneWidget);
    expect(find.text('Filter by category: not available yet'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byKey(const ValueKey('pagedList-error')), findsNothing);
    expect(page1Range(tester), 'Showing 1 to 25');
    expect(_shown(tester).take(4), [0, 1, 2, 3], reason: 'every category, as All');
    // ignore: avoid_print
    print('PAGE1b Activity open, index missing (gets, reads): (${db.gets}, ${db.reads})');
    // One page, the facility, the tidy-up and the All count: the refused
    // category count bills nothing and nothing else is asked.
    expect(db.reads, lessThanOrEqualTo(26 + 1 + 2 + 1));

    // No retry: frames, Next and Previous ask nothing more of the category.
    db.resetCounts();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await ph5Settle(tester);
    expect(db.gets, 0);
    await page1Next(tester);
    expect(page1Range(tester), 'Showing 26 to 50');
    expect(db.gets, lessThanOrEqualTo(1), reason: 'the next All page only');
  });

  ph5TestWidgets('index still building when a chip is chosen: All page 1 in the same fetch, then the note', (tester) async {
    final db = await _open(tester);
    await page1Next(tester);
    db
      ..failActionTypeQueries = true
      ..resetCounts();
    await _choose(tester, 'Products · 30');
    expect(find.byKey(const ValueKey('activity-categoryUnavailable')), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byKey(const ValueKey('pagedList-error')), findsNothing);
    expect(page1Range(tester), 'Showing 1 to 25');
    expect(_shown(tester).take(4), [0, 1, 2, 3], reason: 'All, not the loaded rows filtered');
    expect(db.reads, lessThanOrEqualTo(26), reason: 'one All page, the refused query bills nothing');
    expect(db.gets, 2, reason: 'the refused category query and the All page, no more');
  });

  ph5TestWidgets('opening the tab again asks the category queries again', (tester) async {
    final db = CountingFirestore()..failActionTypeQueries = true;
    await _open(tester, db: db);
    expect(find.byKey(const ValueKey('activity-categoryUnavailable')), findsOneWidget);
    // The index finished building; the person opens the tab again.
    db.failActionTypeQueries = false;
    await pumpPh5(tester, (fs) => ActivityLogScreen(key: UniqueKey(), isModal: true, firestore: fs, auth: Ph8Auth()),
        size: _wide, admin: true, pushed: true, firestore: db);
    await ph5Settle(tester);
    expect(find.byKey(const ValueKey('activity-categoryUnavailable')), findsNothing);
    expect(_chip('Products · 30'), findsOneWidget);
  });

  ph5TestWidgets('numbers unreadable (another error): chips without numbers, the filter still works', (tester) async {
    final db = CountingFirestore()..failCounts = true;
    await _open(tester, db: db);
    expect(find.byKey(const ValueKey('activity-categoryUnavailable')), findsNothing);
    expect(_chip('All'), findsOneWidget);
    expect(_chip('Products'), findsOneWidget);
    expect(find.textContaining(' · '), findsNothing);
    await _choose(tester, 'Products');
    expect(_shown(tester).every((i) => i % 4 == 1), isTrue);
  });

  ph5TestWidgets('the search still looks at the page shown', (tester) async {
    await _open(tester);
    await _choose(tester, 'Products · 30');
    await tester.enterText(find.byType(TextField), 'Entry 1');
    await ph5Settle(tester);
    expect(_row('Entry 1'), findsOneWidget);
    expect(_row('Entry 13'), findsOneWidget);
    expect(_row('Entry 101'), findsNothing, reason: 'on page 2, not this page');
    expect(find.text('Search this page...'), findsOneWidget);
  });

  for (final size in page1Widths) {
    for (final (look, scale) in const [(MatrixLook.light, 1.0), (MatrixLook.light, 1.3), (MatrixLook.kiswahili, 1.3)]) {
      ph5TestWidgets('${size.width.toInt()} ${look.name} text $scale: the chips, the page and the bar, no overflow', (tester) async {
        await _open(tester, size: size, look: look, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('activity-categoryChips')), findsOneWidget);
        expect(find.byType(ChoiceChip), findsNWidgets(5));
        for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
          expect(chip.key, isNotNull);
        }
        expect(tester.getSize(find.byKey(const ValueKey('activity-categoryChips'))).height,
            greaterThanOrEqualTo(44), reason: 'tap row height');
        expect(page1BarWidget(tester).itemCount, 25);
      });
    }
  }
}
