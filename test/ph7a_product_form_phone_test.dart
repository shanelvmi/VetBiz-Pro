// PH7a: Add and Edit Product on a phone with the PH6 form shell (S6): one
// column, fields at least 48 high, the action bar pinned above the keyboard,
// the discard check, the type, category and unit pickers as sheets, number
// keyboards for prices and quantities, and error lines kept under the simple
// fields; the photo picker and its size check as before. What it saves is
// ph7a_saved_forms_test.dart's.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/products/add_edit_product_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph5b_finders.dart';
import 'helpers/ph7a_fakes.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';

const _skip = false;

/// A page whose button opens the form, so leaving it can be seen.
class _Host extends StatelessWidget {
  final Widget form;
  const _Host(this.form);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => form)),
          child: const Text('OPEN'),
        ),
      );
}

Future<FakeStorage> _form(WidgetTester tester, {bool edit = false, bool admin = true, FakeImagePicker? picker}) async {
  final storage = FakeStorage();
  await pumpPh5(
      tester,
      (fs) => _Host(AddEditProductScreen(
          product: edit ? ph7LongProduct : null,
          firestore: fs,
          storage: storage,
          imagePicker: picker ?? FakeImagePicker(),
          currentUserInfo: testUserInfo)),
      admin: admin,
      seed: ph7SeedProducts);
  await tester.tap(find.text('OPEN'));
  await ph5Settle(tester);
  return storage;
}

Finder _field(String label) => find.ancestor(of: find.text(label), matching: find.byType(TextField)).first;

void main() {
  ph5TestWidgets('one column, fields at least 48 high, Cancel and Save Product pinned in the bar', (tester) async {
    await _form(tester);
    final type = find.text('Injectable');
    final category = find.text('Select Category');
    expect(tester.getTopLeft(type).dx, tester.getTopLeft(category).dx, reason: 'type above category, not side by side');
    expect(tester.getTopLeft(type).dy < tester.getTopLeft(category).dy, isTrue);
    for (final label in ['Product Name *', 'Buying Price (Tsh) *', 'Selling Price (Tsh) *', 'Quantity *']) {
      expect(tester.getSize(_field(label)).height, greaterThanOrEqualTo(48), reason: label);
    }
    final bar = ph5Key('formActionBar');
    expect(find.descendant(of: bar, matching: find.text('Save Product')), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text('Cancel')), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('the bar stays above the keyboard', (tester) async {
    await _form(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    final bar = ph5Key('formActionBar');
    expect(tester.getBottomLeft(ph5Key('formActionBar-primary')).dy, lessThanOrEqualTo(844 - 300 + 1));
    expect(find.descendant(of: bar, matching: find.text('Save Product')).hitTestable(), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('the type, category and unit pickers are sheets that save the stored value', (tester) async {
    await _form(tester);
    final l10n = L10n.current;
    for (final (opener, option) in [
      (l10n.productTypeLabel('Injectable'), l10n.productTypeLabel('Powder')),
      ('Select Category', l10n.productCategoryLabel('Antibiotic')),
      (l10n.productUnitLabel('pcs'), l10n.productUnitLabel('bottles')),
    ]) {
      await tester.ensureVisible(find.text(opener).first);
      await tester.tap(find.text(opener).first);
      await ph5Settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget, reason: opener);
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(option)));
      await ph5Settle(tester);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(option), findsOneWidget, reason: option);
    }
  }, skip: _skip);

  ph5TestWidgets('number keyboards for the prices and quantities', (tester) async {
    await _form(tester);
    for (final label in ['Buying Price (Tsh) *', 'Selling Price (Tsh) *', 'Quantity *', 'Minimum Stock Level']) {
      expect(tester.widget<TextField>(_field(label)).keyboardType, TextInputType.number, reason: label);
    }
  }, skip: _skip);

  ph5TestWidgets('an empty save shows the messages in the kept lines: nothing moves', (tester) async {
    await _form(tester);
    final before = tester.getTopLeft(find.text('Injectable')).dy;
    await tester.tap(find.descendant(of: ph5Key('formActionBar'), matching: find.text('Save Product')));
    await ph5Settle(tester);
    expect(find.text('Product name is required'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Injectable')).dy, before);
  }, skip: _skip);

  ph5TestWidgets('Back with typed data asks (Keep editing stays, Discard leaves); a clean form leaves', (tester) async {
    await _form(tester);
    await tester.binding.handlePopRoute();
    await ph5Settle(tester);
    expect(find.byType(AddEditProductScreen), findsNothing, reason: 'clean: no question');

    await tester.tap(find.text('OPEN'));
    await ph5Settle(tester);
    await tester.enterText(_field('Product Name *'), 'Amoxicillin');
    await tester.binding.handlePopRoute();
    await ph5Settle(tester);
    expect(find.text('Discard this product?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await ph5Settle(tester);
    expect(find.byType(AddEditProductScreen), findsOneWidget);
    await tester.tap(find.descendant(of: ph5Key('formActionBar'), matching: find.text('Cancel')));
    await ph5Settle(tester);
    await tester.tap(find.text('Discard'));
    await ph5Settle(tester);
    expect(find.byType(AddEditProductScreen), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('the photo: picked and uploaded as before; one over the size limit is refused', (tester) async {
    var storage = await _form(tester);
    await tester.tap(find.text('Add photo'));
    await ph5Settle(tester);
    // The fake bytes are no real picture: the preview cannot decode them.
    while (tester.takeException() != null) {}
    expect(storage.uploads.single.path, startsWith('product_images/$testFacilityId/'));
    expect(storage.uploads.single.contentType, 'image/jpeg');

    storage = await _form(tester, picker: FakeImagePicker(Uint8List(AppLimits.maxUploadBytes + 1)));
    await tester.tap(find.text('Add photo'));
    await ph5Settle(tester);
    expect(storage.uploads, isEmpty);
  }, skip: _skip);

  ph5TestWidgets('Edit Product: Update Product in the bar; an assistant\'s details stay locked (quantities editable)', (tester) async {
    await _form(tester, edit: true);
    expect(find.descendant(of: ph5Key('formActionBar'), matching: find.text('Update Product')), findsOneWidget);
    await _form(tester, edit: true, admin: false);
    expect(tester.widget<TextField>(_field('Product Name *')).enabled, isFalse);
    expect(tester.widget<TextField>(_field('Store Qty *')).enabled, isNot(false));
  }, skip: _skip);
}
