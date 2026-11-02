// PH6: on a phone the simple money forms save exactly what they saved
// before PH6. For fixed inputs, everything in the fake Firestore after the
// save (dates and generated ids masked) is compared with what the old forms
// saved (test/fixtures/ph6_saved_forms.json, recorded once from the code
// before PH6 with --dart-define=PH6_RECORD=true). The inputs are found by
// their hints and labels, the same on the old and the new forms; a picker
// that became a sheet on phones is used through its option's label.
import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph6_forms.dart';
import 'helpers/phone_list_harness.dart';

const _skip = false;

const _fixture = 'test/fixtures/ph6_saved_forms.json';

final _autoId = RegExp(r'(?<![A-Za-z0-9])[A-Za-z0-9]{20}(?![A-Za-z0-9])');
final _isoTime = RegExp(r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}');

/// Dates become `<time>`; generated ids become `<id>`, and a map keyed by
/// them becomes the sorted list of its values.
Object? _normalize(Object? node) {
  if (node is Map) {
    final fixed = <String, Object?>{};
    final generated = <String>[];
    for (final e in node.entries) {
      final key = '${e.key}';
      final value = _normalize(e.value);
      if (_autoId.hasMatch(key)) {
        generated.add(jsonEncode({'key': key.replaceAll(_autoId, '<id>'), 'value': value}));
      } else {
        fixed[key] = value;
      }
    }
    if (generated.isNotEmpty) fixed['<generated>'] = [for (final s in generated..sort()) jsonDecode(s)];
    return Map.fromEntries(fixed.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }
  if (node is List) return [for (final v in node) _normalize(v)];
  if (node is String && _autoId.hasMatch(node)) return node.replaceAll(_autoId, '<id>');
  if (node is String && _isoTime.hasMatch(node)) return '<time>';
  return node;
}

void _expectSameSaved(String name, FakeFirebaseFirestore fs) {
  final saved = jsonEncode(_normalize(storedData(fs)));
  final file = File(_fixture);
  final recorded = file.existsSync() ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic> : <String, dynamic>{};
  if (const bool.fromEnvironment('PH6_RECORD')) {
    recorded[name] = jsonDecode(saved);
    // One form a line, so a change shows which form it is.
    final keys = recorded.keys.toList()..sort();
    file.writeAsStringSync('{\n${[for (final k in keys) '  ${jsonEncode(k)}: ${jsonEncode(recorded[k])}'].join(',\n')}\n}\n');
    return;
  }
  expect(jsonDecode(saved), recorded[name], reason: '$name: the saved data changed');
}

Finder _field(String text) => find.ancestor(of: find.text(text), matching: find.byType(TextField)).first;

Future<void> _type(WidgetTester tester, String hintOrLabel, String text) async {
  await tester.ensureVisible(_field(hintOrLabel));
  await tester.enterText(_field(hintOrLabel), text);
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

/// Today's phone layouts of these forms may overflow (PH6 fixes them): the
/// data is what is compared.
void _drain(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

void main() {
  ph5TestWidgets('Add Client saves what it saved before', (tester) async {
    final app = await pumpPh6(tester, 'add-client');
    _drain(tester);
    await _type(tester, 'Enter client name', 'Zawadi Said');
    await _type(tester, 'e.g. 07XX XXX XXX', '0754 123 456');
    await _type(tester, 'Enter address', 'Moshi');
    await _tap(tester, find.text('Farmer').first);
    _drain(tester);
    await _tap(tester, find.text('Save Client').last);
    _drain(tester);
    _expectSameSaved('add-client', app.fs as FakeFirebaseFirestore);
  }, skip: _skip);

  ph5TestWidgets('Add Transaction saves what it saved before', (tester) async {
    final app = await pumpPh6(tester, 'add-transaction');
    _drain(tester);
    await _pick(tester, 'Select category...', 'Rent');
    await _type(tester, 'What was this for?', 'Diesel for the van');
    await _type(tester, '0.00', '25000');
    await _type(tester, 'Add any additional information', 'Arusha trip');
    await _pick(tester, 'Select method', 'M-Pesa');
    _drain(tester);
    await _tap(tester, find.text('Record Transaction').last);
    _drain(tester);
    _expectSameSaved('add-transaction', app.fs as FakeFirebaseFirestore);
  }, skip: _skip);

  ph5TestWidgets('Record Payment saves what it saved before', (tester) async {
    final app = await pumpPh6(tester, 'record-payment');
    _drain(tester);
    final debtor = _field('Debtor');
    await _tap(tester, debtor);
    if (find.byType(BottomSheet).evaluate().isNotEmpty) {
      await tester.enterText(find.byKey(const ValueKey('pickerSheet-search')), 'Amina');
    } else {
      await tester.enterText(debtor, 'Amina');
    }
    await ph5Settle(tester);
    await tester.tap(find.textContaining('Amina Juma').last);
    await ph5Settle(tester);
    await _type(tester, 'Payment Amount', '20000');
    await _tap(tester, find.text('Cash').first);
    _drain(tester);
    await _tap(tester, find.text('Save Payment').last);
    _drain(tester);
    _expectSameSaved('record-payment', app.fs as FakeFirebaseFirestore);
  }, skip: _skip);

  ph5TestWidgets('Record Visit saves what it saved before', (tester) async {
    final app = await pumpPh6(tester, 'record-visit');
    _drain(tester);
    await _type(tester, 'Search or select client...', 'Amina');
    await ph5Settle(tester);
    await tester.tap(find.text('Amina Juma').last);
    await ph5Settle(tester);
    _drain(tester);
    await _type(tester, 'Service Name', 'Deworming');
    await _type(tester, 'Provided By', 'Dr. Asha');
    await tester.enterText(find.ancestor(of: find.text('0.00').first, matching: find.byType(TextField)).first, '30000');
    await tester.pump();
    await tester.enterText(find.ancestor(of: find.text('0.00').last, matching: find.byType(TextField)).first, '10000');
    await ph5Settle(tester);
    _drain(tester);
    await _pick(tester, 'Select method', 'Cash');
    _drain(tester);
    await _tap(tester, find.text('Record Visit').last);
    _drain(tester);
    _expectSameSaved('record-visit', app.fs as FakeFirebaseFirestore);
  }, skip: _skip);

  ph5TestWidgets('Add Sale saves what it saved before (three items through Browse Products)', (tester) async {
    final app = await pumpPh6(tester, 'add-sale');
    _drain(tester);
    await ph6LoadSaleProducts(tester, app);
    await _tap(tester, find.text('Browse Products').first);
    _drain(tester);
    for (final name in ['Albendazole 10%', 'Albendazole 10%', 'Ivermectin 1%', 'Vitamin B12']) {
      final row = find.ancestor(of: find.text(name).last, matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.add_circle)).last);
      await ph5Settle(tester);
    }
    // Back closes Browse Products (a dialog, or a phone's sheet).
    await tester.binding.handlePopRoute();
    await ph5Settle(tester);
    _drain(tester);
    await _type(tester, '0.00', '42500');
    await _pick(tester, 'Select Method', 'Cash');
    await _type(tester, 'Add any additional notes (optional)...', 'Morning sale');
    _drain(tester);
    await _tap(tester, find.text('Record Sale').last);
    _drain(tester);
    _expectSameSaved('add-sale', app.fs as FakeFirebaseFirestore);
  }, skip: _skip);
}

