// PH7a: on a phone Add Product, Edit Product and Add Batch save exactly what
// they saved before PH7a. For fixed inputs, everything in the fake Firestore
// after the save, and every upload to Storage (its path and content type),
// with dates and generated ids masked, is compared with what the old forms
// saved (test/fixtures/ph7a_saved_forms.json, recorded once from the code
// before PH7a with --dart-define=PH7A_RECORD=true). Inputs are found by
// their labels, the same on the old and the new forms; a picker that became
// a sheet on phones is used through its option's label.
import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/products/add_batch_screen.dart';
import 'package:vetbiz_pro/screens/products/add_edit_product_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph7a_fakes.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';

const _skip = false;

const _fixture = 'test/fixtures/ph7a_saved_forms.json';

final _autoId = RegExp(r'(?<![A-Za-z0-9])[A-Za-z0-9]{20}(?![A-Za-z0-9])');
final _uuid = RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}');
final _isoTime = RegExp(r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}');

String _maskIds(String s) => s.replaceAll(_uuid, '<uuid>').replaceAll(_autoId, '<id>');

/// Dates become `<time>`; generated ids become `<id>` (`<uuid>` for the
/// product ids the form makes), and a map keyed by them becomes the sorted
/// list of its values.
Object? _normalize(Object? node) {
  if (node is Map) {
    final fixed = <String, Object?>{};
    final generated = <String>[];
    for (final e in node.entries) {
      final key = '${e.key}';
      final value = _normalize(e.value);
      if (_autoId.hasMatch(key) || _uuid.hasMatch(key)) {
        generated.add(jsonEncode({'key': _maskIds(key), 'value': value}));
      } else {
        fixed[key] = value;
      }
    }
    if (generated.isNotEmpty) fixed['<generated>'] = [for (final s in generated..sort()) jsonDecode(s)];
    return Map.fromEntries(fixed.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }
  if (node is List) return [for (final v in node) _normalize(v)];
  if (node is String && _isoTime.hasMatch(node)) return '<time>';
  if (node is String) return _maskIds(node);
  return node;
}

void _expectSameSaved(String name, FakeFirebaseFirestore fs, [FakeStorage? storage]) {
  final saved = jsonEncode(_normalize({
    'firestore': storedData(fs),
    'storage': [for (final u in storage?.uploads ?? const <FakeUpload>[]) {'path': u.path, 'contentType': u.contentType}],
  }));
  final file = File(_fixture);
  final recorded = file.existsSync() ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic> : <String, dynamic>{};
  if (const bool.fromEnvironment('PH7A_RECORD')) {
    recorded[name] = jsonDecode(saved);
    final keys = recorded.keys.toList()..sort();
    file.writeAsStringSync('{\n${[for (final k in keys) '  ${jsonEncode(k)}: ${jsonEncode(recorded[k])}'].join(',\n')}\n}\n');
    return;
  }
  expect(jsonDecode(saved), recorded[name], reason: '$name: the saved data changed');
}

Finder _field(String label) => find.ancestor(of: find.text(label), matching: find.byType(TextField)).first;

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await ph5Settle(tester);
}

/// Opens a picker (a dialog, a menu or a phone's sheet) and chooses [option].
Future<void> _pick(WidgetTester tester, String opener, String option) async {
  await _tap(tester, find.text(opener).first);
  await tester.tap(find.text(option).last);
  await ph5Settle(tester);
}

/// The date picker: today's suggestion, OK.
Future<void> _pickDate(WidgetTester tester, String label) async {
  await _tap(tester, _field(label));
  await tester.tap(find.text('OK'));
  await ph5Settle(tester);
}

/// Today's phone layouts of these forms may overflow (PH7a fixes them): the
/// data is what is compared.
void _drain(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

void main() {
  ph5TestWidgets('Add Product saves what it saved before (with a photo, to the catalog)', (tester) async {
    final storage = FakeStorage();
    final app = await pumpPh5(
        tester,
        (fs) => AddEditProductScreen(
            firestore: fs, storage: storage, imagePicker: FakeImagePicker(), currentUserInfo: testUserInfo),
        seed: ph7SeedProducts);
    _drain(tester);
    final l10n = L10n.current;
    await _tap(tester, find.text(l10n.products_addPhoto));
    _drain(tester);
    await _type(tester, 'Product Name *', 'Amoxicillin 15%');
    await _pick(tester, l10n.productTypeLabel('Injectable'), l10n.productTypeLabel('Powder'));
    await _pick(tester, 'Select Category', l10n.productCategoryLabel('Antibiotic'));
    _drain(tester);
    await _type(tester, 'Supplier', 'Vetcare Ltd');
    await _type(tester, 'Batch No', 'AMX-2026');
    await _pickDate(tester, 'Expiry');
    await _type(tester, 'Description', 'For chest infections');
    await _type(tester, 'Buying Price (Tsh) *', '8000');
    await _type(tester, 'Selling Price (Tsh) *', '12000');
    await _type(tester, 'Quantity *', '24');
    await _pick(tester, l10n.productUnitLabel('pcs'), l10n.productUnitLabel('bottles'));
    await _type(tester, 'Minimum Stock Level', '6');
    await _tap(tester, find.text('Track in Daily Reports'));
    _drain(tester);
    await _tap(tester, find.text('Save Product').last);
    await _tap(tester, find.text('Continue'));
    _drain(tester);
    _expectSameSaved('add-product', app.fs as FakeFirebaseFirestore, storage);
  }, skip: _skip);

  ph5TestWidgets('Edit Product saves what it saved before (price, name, store quantity)', (tester) async {
    final storage = FakeStorage();
    final app = await pumpPh5(
        tester,
        (fs) => AddEditProductScreen(
            product: ph7LongProduct, firestore: fs, storage: storage, currentUserInfo: testUserInfo),
        seed: ph7SeedProducts);
    _drain(tester);
    await _type(tester, 'Product Name *', 'Albendazole 10% 1L');
    await _type(tester, 'Selling Price (Tsh) *', '13000000');
    await _type(tester, 'Store Qty *', '55');
    await _type(tester, 'Minimum Stock Level', '12');
    _drain(tester);
    await _tap(tester, find.text('Update Product').last);
    _drain(tester);
    _expectSameSaved('edit-product', app.fs as FakeFirebaseFirestore, storage);
  }, skip: _skip);

  ph5TestWidgets('Add Batch saves what it saved before (to the shelf, with an expiry)', (tester) async {
    final app = await pumpPh5(tester, (fs) => AddBatchScreen(product: ph7LongProduct), seed: ph7SeedProducts);
    _drain(tester);
    await _type(tester, 'Batch No (optional)', 'BN-002');
    await _pickDate(tester, 'Expiry Date');
    await _tap(tester, find.text('Sellable (straight to the shelf)'));
    await _type(tester, 'Quantity Received', '10');
    await _type(tester, 'Buy Price (Tsh)', '9100000');
    _drain(tester);
    await _tap(tester, find.text('Add Batch').last);
    _drain(tester);
    _expectSameSaved('add-batch', app.fs as FakeFirebaseFirestore);
  }, skip: _skip);
}
