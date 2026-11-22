// PAGE1: Trash on PC/tablet pages each kind by cursor (pageSize + 1, newest
// deleted first) instead of streaming the whole trash; the soon-to-expire
// banner counts the whole kind with one count() (it counted the loaded
// docs). No counts on the kind chips (there were none). Restore and Delete
// Forever are the same calls; the page starts over after one. The phone
// keeps its list (ph8a_trash_phone_test).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/screens/settings/trash_screen.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/fake_firestore.dart';
import 'helpers/page1_harness.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'helpers/test_clock.dart';
import 'ph8a_settings_wide_test.dart' show ph8UserInfo;

const _wide = Size(1600, 900);

/// [count] trashed products an hour apart (p00 newest); the oldest [old]
/// of them deleted 25 days ago (expiring within the 7-day warning).
Future<void> _seed(FirebaseFirestore fs, {int count = 30, int old = 0}) async {
  final trash = facilityCollection(fs, Collections.trashProducts);
  for (var i = 0; i < count; i++) {
    final ago = i >= count - old ? const Duration(days: 25) : Duration(hours: i + 1);
    await trash.doc('p${i.toString().padLeft(2, '0')}').set({
      'name': 'Product $i',
      'deletedAt': Timestamp.fromDate(testNow.subtract(ago).subtract(Duration(minutes: i))),
      'deletedBy': 'Asha',
      'sellPrice': 1000,
    });
  }
}

Future<CountingFirestore> _open(WidgetTester tester,
    {int count = 30, int old = 0, Size size = _wide, MatrixLook look = MatrixLook.light, double textScale = 1, CountingFirestore? db}) async {
  final store = db ?? CountingFirestore();
  await tester.runAsync(() => _seed(store.inner, count: count, old: old));
  await pumpPh5(tester, (fs) => TrashScreen(firestore: fs, currentUserInfo: ph8UserInfo),
      size: size, pushed: true, firestore: store, look: look, textScale: textScale);
  return store;
}

void main() {
  ph5TestWidgets('page 1, Next, Previous; the last page has no Next', (tester) async {
    final db = await _open(tester);
    expect(page1Range(tester), 'Showing 1 to 25');
    db.resetCounts();
    await page1Next(tester);
    expect(db.reads, lessThanOrEqualTo(26));
    expect(page1Range(tester), 'Showing 26 to 30');
    expect(page1NextEnabled(tester), isFalse);
    db.resetCounts();
    await page1Previous(tester);
    expect(db.reads, 0);
  });

  ph5TestWidgets('page size goes back to page 1', (tester) async {
    await _open(tester);
    await page1Next(tester);
    await page1PageSize(tester, 10);
    expect(page1BarWidget(tester).currentPage, 1);
    expect(page1Range(tester), 'Showing 1 to 10');
  });

  ph5TestWidgets('the expiring banner counts the whole kind, not the page', (tester) async {
    await _open(tester, count: 30, old: 3);
    // The three old ones are on page 2 (oldest last); the banner says 3 on page 1.
    expect(find.textContaining('3 items'), findsOneWidget);
  });

  ph5TestWidgets('restore: the row leaves and the page starts over', (tester) async {
    // The plain fake (a restore writes in a batch).
    await pumpPh5(tester, (fs) => TrashScreen(firestore: fs, currentUserInfo: ph8UserInfo),
        size: _wide, pushed: true, seed: (fs) => _seed(fs));
    await page1Next(tester);
    await page1Previous(tester);
    await tester.tap(find.byKey(const ValueKey('trash-restore-p00')));
    await ph5Settle(tester);
    expect(find.byKey(const ValueKey('trash-row-p00')), findsNothing);
    expect(page1Range(tester), 'Showing 1 to 25');
    expect(page1NextEnabled(tester), isTrue, reason: '29 left: 25 here, 4 on the next page');
  });

  ph5TestWidgets('empty: the empty text', (tester) async {
    await _open(tester, count: 0);
    expect(find.text('Trash is empty'), findsWidgets);
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

  ph5TestWidgets('the skeleton while the page loads, no spinner', (tester) async {
    final db = CountingFirestore()..holdGets = Completer<void>();
    await _open(tester, db: db);
    expect(find.byKey(const ValueKey('pagedList-skeleton')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    db.holdGets!.complete();
    db.holdGets = null;
    await ph5Settle(tester);
    expect(page1Range(tester), 'Showing 1 to 25');
  });

  ph5TestWidgets('reads on open: one page (pageSize + 1) and one count, no listener on the trash', (tester) async {
    final db = await _open(tester);
    // ignore: avoid_print
    print('PAGE1 Trash open (listeners, gets, reads): (${db.listeners}, ${db.gets}, ${db.reads})');
    expect(db.listeners, lessThanOrEqualTo(1), reason: 'only the app\'s role listener');
    expect(db.reads, lessThanOrEqualTo(26 + 1 + 1));
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
