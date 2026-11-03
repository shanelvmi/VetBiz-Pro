// PH8a (4): Trash on phones, on the PH5a list pattern: one list of every
// deleted record, newest first, two-line rows with the record type chip,
// quick chips by type, a details page with Restore and Delete forever for
// admins (today's confirmation; a restore tells the lists through
// RecordChanges), pull to refresh, the empty and error states, the
// listeners made once; the size matrix. Wider windows keep the five tabs
// (ph8a_settings_wide_test pins them).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/screens/settings/trash_screen.dart';
import 'package:vetbiz_pro/services/record_changes.dart';
import 'package:vetbiz_pro/widgets/phone_list/record_tile.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/fake_firestore.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'ph8a_settings_wide_test.dart' show ph8UserInfo, seedTrash;

// True until the phone list exists.
const _skip = true;

Future<Ph5App> _pump(WidgetTester tester,
        {Size size = const Size(390, 844), MatrixLook look = MatrixLook.light, bool admin = true, FirebaseFirestore? fs, bool seed = true}) =>
    pumpPh5(tester, (fs) => TrashScreen(firestore: fs, currentUserInfo: ph8UserInfo),
        size: size, look: look, admin: admin, pushed: true, firestore: fs, seed: seed ? seedTrash : null);

Finder _row(String text) => find.ancestor(of: find.textContaining(text), matching: find.byType(RecordTile));

Future<bool> _exists(WidgetTester tester, FirebaseFirestore fs, String collection, String id) async =>
    (await tester.runAsync(() => facilityCollection(fs, collection).doc(id).get()))!.exists;

void main() {
  for (final size in ph5PhoneSizes) {
    for (final look in MatrixLook.values) {
      final where = 'Trash ${size.label} ${look.name}';
      ph5TestWidgets('$where: the list and a details page; no overflow, 48 px targets, text 12 px or more', (tester) async {
        await _pump(tester, size: size.size, look: look);
        await checkCase(tester, phone: true, where: where);
        await tester.tap(_row('Amina Juma').first);
        await ph5Settle(tester);
        await checkCase(tester, phone: true, where: '$where details');
      }, skip: _skip);
    }
  }

  ph5TestWidgets('one list of every type, newest first, each row with its type chip; the chips filter', (tester) async {
    await _pump(tester);
    expect(find.byType(RecordTile), findsNWidgets(4));
    for (final type in ['Products', 'Clients', 'Sales', 'Transactions']) {
      expect(find.descendant(of: find.byType(RecordTile), matching: find.text(type)), findsOneWidget, reason: type);
    }
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sales'));
    await ph5Settle(tester);
    expect(find.byType(RecordTile), findsOneWidget);
    expect(_row('Amina Juma'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('Restore from the details page puts it back and tells the lists', (tester) async {
    final changes = <String>[];
    final sub = RecordChanges.listen({Collections.products}, changes.add);
    addTearDown(sub.cancel);
    final app = await _pump(tester);
    await tester.tap(_row('Albendazole').first);
    await ph5Settle(tester);
    await tester.tap(find.text('Restore'));
    await ph5Settle(tester);
    expect(await _exists(tester, app.fs, Collections.products, 'p1'), isTrue);
    expect(await _exists(tester, app.fs, Collections.trashProducts, 'p1'), isFalse);
    expect(changes, [testFacilityId]);
    expect(find.text('Restore'), findsNothing, reason: 'the details page closes');
  }, skip: _skip);

  ph5TestWidgets('Delete forever asks first (today\'s question); Cancel keeps it, confirming deletes it', (tester) async {
    final app = await _pump(tester);
    await tester.tap(_row('Fuel').first);
    await ph5Settle(tester);
    await tester.tap(find.text('Delete Forever'));
    await ph5Settle(tester);
    expect(find.text('Delete Forever?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await ph5Settle(tester);
    expect(await _exists(tester, app.fs, Collections.trashTransactions, 't1'), isTrue);
    await tester.tap(find.text('Delete Forever'));
    await ph5Settle(tester);
    await tester.tap(find.text('Delete Forever').last);
    await ph5Settle(tester);
    expect(await _exists(tester, app.fs, Collections.trashTransactions, 't1'), isFalse);
  }, skip: _skip);

  ph5TestWidgets('an assistant sees the details but no Restore or Delete forever', (tester) async {
    await _pump(tester, admin: false);
    await tester.tap(_row('Amina Juma').first);
    await ph5Settle(tester);
    expect(find.text('Restore'), findsNothing);
    expect(find.text('Delete Forever'), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('the empty state and the error state with Retry', (tester) async {
    await _pump(tester, seed: false);
    expect(find.text('Trash is empty'), findsOneWidget);
    final fs = CountingFirestore()..failListens = true;
    await _pump(tester, fs: fs);
    expect(find.text('Retry'), findsWidgets);
  }, skip: _skip);

  ph5TestWidgets('the five listeners are made once: a chip or a rebuild does not listen again; pull to refresh does', (tester) async {
    final fs = CountingFirestore();
    await _pump(tester, fs: fs);
    final opened = fs.listens;
    await tester.tap(find.widgetWithText(ChoiceChip, 'Clients'));
    await ph5Settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await ph5Settle(tester);
    expect(fs.listens, opened);
    await tester.fling(find.byType(RecordTile).first, const Offset(0, 400), 1000);
    await ph5Settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await ph5Settle(tester);
    expect(fs.listens, greaterThan(opened));
  }, skip: _skip);
}
