// PH7a: the batches on a phone. View Batches opens as a bottom sheet with
// its batches in 48 px rows and text of at least 14 px, Add New Batch at its
// foot; its adjust and delete dialogs (and Move to Stock, already a sheet
// since PH6) open as sheets with their buttons at the bottom. Add Batch is a
// phone form with the PH6 shell: the action bar pinned above the keyboard,
// the discard check, number keyboards and kept error lines. Tablets and
// computers keep today's screens (ph7a_wide_unchanged_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/products/add_batch_screen.dart';
import 'package:vetbiz_pro/screens/products/view_batches_screen.dart';

import 'helpers/ph5b_finders.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = true;

/// A page with buttons that open View Batches and Add Batch, as the
/// Products details page does.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          TextButton(onPressed: () => showViewBatchesScreen(context, product: ph7LongProduct), child: const Text('BATCHES')),
          TextButton(onPressed: () => showAddBatchScreen(context, product: ph7LongProduct), child: const Text('ADD')),
        ]),
      );
}

Future<void> _open(WidgetTester tester, String button, {bool admin = true}) async {
  await pumpPh5(tester, (fs) => const Ph7Listening(child: _Host()), admin: admin, seed: ph7SeedProducts);
  await tester.tap(find.text(button));
  await ph5Settle(tester);
}

Finder get _sheet => find.byType(BottomSheet);

void main() {
  ph5TestWidgets('View Batches is a sheet: the batch in a row of at least 48 px, text of at least 14, Add New Batch at the foot', (tester) async {
    await _open(tester, 'BATCHES');
    expect(_sheet, findsOneWidget);
    expect(find.byType(ViewBatchesScreen), findsNothing, reason: 'no full page on a phone');
    final row = find.ancestor(of: find.descendant(of: _sheet, matching: find.textContaining('BN-001')), matching: find.byType(ListTile)).first;
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    expect(smallTexts(tester, min: 14).where((t) => !t.contains('Out of Stock')), isEmpty);
    expect(find.descendant(of: _sheet, matching: find.text('Add New Batch')), findsOneWidget);
    for (final tip in ['Adjust quantity', 'Delete batch', 'Move to Stock']) {
      final button = find.descendant(of: _sheet, matching: find.byTooltip(tip));
      expect(button, findsOneWidget, reason: tip);
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
    }
  }, skip: _skip);

  ph5TestWidgets('an assistant\'s sheet has no Delete (as today)', (tester) async {
    await _open(tester, 'BATCHES', admin: false);
    expect(find.descendant(of: _sheet, matching: find.byTooltip('Delete batch')), findsNothing);
    expect(find.descendant(of: _sheet, matching: find.byTooltip('Adjust quantity')), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('Adjust quantity opens as a sheet with Cancel and Save at the bottom, and saves the batch', (tester) async {
    await _open(tester, 'BATCHES');
    await tester.tap(find.byTooltip('Adjust quantity'));
    await ph5Settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    final save = find.widgetWithText(ElevatedButton, 'Save');
    expect(save, findsOneWidget);
    expect(tester.getBottomLeft(save).dy, greaterThan(tester.getBottomLeft(find.text('Cancel')).dy - 1));
    expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
    await tester.enterText(find.widgetWithText(TextField, 'Add to Store Qty'), '5');
    await tester.tap(save);
    await ph5Settle(tester);
    expect(find.textContaining('Store: 65'), findsWidgets);
  }, skip: _skip);

  ph5TestWidgets('Delete batch opens as a sheet with Cancel and Delete at the bottom', (tester) async {
    await _open(tester, 'BATCHES');
    await tester.tap(find.byTooltip('Delete batch'));
    await ph5Settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Delete This Batch?'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Delete'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('Add Batch: the action bar above the keyboard, number keyboards, kept error lines, the discard check', (tester) async {
    await _open(tester, 'ADD');
    final bar = ph5Key('formActionBar');
    expect(bar, findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text('Add Batch')), findsOneWidget);
    for (final label in ['Quantity Received', 'Buy Price (Tsh)']) {
      final field = tester.widget<TextField>(find.widgetWithText(TextField, label));
      expect(field.keyboardType, TextInputType.number, reason: label);
    }
    final quantity = find.widgetWithText(TextField, 'Quantity Received');
    final before = tester.getTopLeft(find.widgetWithText(TextField, 'Buy Price (Tsh)')).dy;
    await tester.tap(find.descendant(of: bar, matching: find.text('Add Batch')));
    await ph5Settle(tester);
    expect(find.text('Enter a valid quantity'), findsOneWidget);
    expect(tester.getTopLeft(find.widgetWithText(TextField, 'Buy Price (Tsh)')).dy, before, reason: 'the error line was kept');

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(tester.getBottomLeft(bar).dy, lessThanOrEqualTo(844 - 300 + 1), reason: 'above the keyboard');
    tester.view.resetViewInsets();
    await tester.pump();

    await tester.enterText(quantity, '7');
    await tester.binding.handlePopRoute();
    await ph5Settle(tester);
    expect(find.text('Discard this batch?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await ph5Settle(tester);
    expect(find.byType(AddBatchScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await ph5Settle(tester);
    await tester.tap(find.text('Discard'));
    await ph5Settle(tester);
    expect(find.byType(AddBatchScreen), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('Add Batch: a clean form leaves without asking', (tester) async {
    await _open(tester, 'ADD');
    await tester.binding.handlePopRoute();
    await ph5Settle(tester);
    expect(find.byType(AddBatchScreen), findsNothing);
    expect(ph5Key('formActionBar'), findsNothing);
  }, skip: _skip);
}
