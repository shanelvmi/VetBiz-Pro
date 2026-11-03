// PH8a (5): the Activity log on phones, on the PH5a list pattern: grouped by
// day, two-line rows (who and the time, then the action, with its type
// chip), quick chips and a Filter sheet with the tablet's type filter (the
// same entries for the same choice), search, the retention choice and its
// warning as sheets (showSheetOrDialog), the details as a full page, an
// assistant's scope note, no new queries; the size matrix. Wider windows keep
// today's log (ph8a_activity_wide_test).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/widgets/phone_list/record_tile.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'ph8a_activity_wide_test.dart' show pumpActivity;

// True until the phone list exists.
const _skip = true;

const _sales = ['Recorded sale to Mwanaisha', 'Recorded sale to Walk-in'];
const _phone = Size(390, 844);

Finder get _sheet => find.byType(BottomSheet);

/// The entries a list shows, by the start of their description.
List<String> _shown(WidgetTester tester, List<String> starts) =>
    [for (final s in starts) if (find.textContaining(s).evaluate().isNotEmpty) s];

void main() {
  for (final size in ph5PhoneSizes) {
    for (final look in MatrixLook.values) {
      final where = 'Activity log ${size.label} ${look.name}';
      ph5TestWidgets('$where: the list and a details page; no overflow, 48 px targets, text 12 px or more', (tester) async {
        await pumpActivity(tester, size: size.size, look: look);
        await checkCase(tester, phone: true, where: where);
        await tester.tap(find.byType(RecordTile).first);
        await ph5Settle(tester);
        await checkCase(tester, phone: true, where: '$where details');
      }, skip: _skip);
    }
  }

  ph5TestWidgets('grouped by day, newest first, each row with its type chip', (tester) async {
    await pumpActivity(tester, size: _phone);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.byType(RecordTile), findsNWidgets(6));
    expect(find.descendant(of: find.byType(RecordTile), matching: find.text('Trash')), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('a type chip shows what the tablet\'s chip shows', (tester) async {
    await pumpActivity(tester, size: const Size(1024, 768), modal: true);
    await tester.tap(find.textContaining('Sales').first);
    await ph5Settle(tester);
    final tablet = _shown(tester, [..._sales, 'Added product', 'Restored', 'Approved', 'Recorded payment']);
    expect(tablet, _sales);

    await pumpActivity(tester, size: _phone);
    final chip = find.widgetWithText(ChoiceChip, 'Sales · 2');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await ph5Settle(tester);
    expect(_shown(tester, [..._sales, 'Added product', 'Restored', 'Approved', 'Recorded payment']), tablet);
  }, skip: _skip);

  ph5TestWidgets('the Filter sheet sets the same type filter', (tester) async {
    await pumpActivity(tester, size: _phone);
    await tester.tap(find.byTooltip('Filter'));
    await ph5Settle(tester);
    expect(_sheet, findsOneWidget);
    await tester.tap(find.descendant(of: _sheet, matching: find.text('Trash')).first);
    await tester.tap(find.text('Apply'));
    await ph5Settle(tester);
    expect(find.byType(RecordTile), findsOneWidget);
    expect(find.textContaining('Restored Amina Juma'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('an admin chooses how long logs are kept in a sheet; a shorter time asks first, in a sheet too', (tester) async {
    await pumpActivity(tester, size: _phone);
    await tester.tap(find.byIcon(Icons.more_vert));
    await ph5Settle(tester);
    await tester.tap(find.text('Keeping logs for 90 days'));
    await ph5Settle(tester);
    expect(_sheet, findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('30 days'));
    await ph5Settle(tester);
    expect(find.descendant(of: _sheet, matching: find.textContaining('Delete')), findsWidgets);
    await tester.tap(find.descendant(of: _sheet, matching: find.text('Cancel')));
    await ph5Settle(tester);
    expect(_sheet, findsNothing);
  }, skip: _skip);

  ph5TestWidgets('an assistant sees the scope note and no retention choice', (tester) async {
    await pumpActivity(tester, size: _phone, admin: false);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byType(RecordTile), findsNWidgets(3));
  }, skip: _skip);

  ph5TestWidgets('no new queries: a phone opens the listeners the tablet opens', (tester) async {
    final wide = CountingFirestore();
    await pumpActivity(tester, size: const Size(1024, 768), modal: true, fs: wide);
    final phone = CountingFirestore();
    await pumpActivity(tester, size: _phone, fs: phone);
    expect(phone.listens, wide.listens);
    expect(phone.gets, wide.gets);
  }, skip: _skip);
}
