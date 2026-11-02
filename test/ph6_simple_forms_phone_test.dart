// PH6 on the four simple money forms, form by form, on a phone: their
// pickers open as bottom sheets (56 px rows, a check on the chosen one) and
// stay dialogs and menus on a computer; a missing entry shows its message
// in the line kept under its field, so the form does not change height;
// numbers open the number keyboard and the keyboard's action moves on.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ph5b_finders.dart';
import 'helpers/ph6_forms.dart';
import 'helpers/phone_list_harness.dart';

/// The forms done so far: the others stay skipped until theirs is.
const _done = <String>{'add-transaction'};

const _wide = Size(1200, 800);

Finder _field(String text) => find.ancestor(of: find.text(text), matching: find.byType(TextField)).first;

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await ph5Settle(tester);
}

/// The sheet is up with [option] as a 56 px row.
void _expectSheet(WidgetTester tester, String option) {
  expect(find.byType(BottomSheet), findsOneWidget);
  final row = find.ancestor(of: find.text(option).last, matching: find.byType(InkWell)).first;
  expect(tester.getSize(row).height, greaterThanOrEqualTo(56));
}

/// [action] (a save with a field left empty) shows [message] and moves
/// nothing below [anchor].
Future<void> _expectErrorInPlace(WidgetTester tester, String anchor, String message) async {
  await tester.ensureVisible(find.text(anchor).first);
  await tester.pump();
  final before = tester.getTopLeft(find.text(anchor).first);
  await tester.tap(ph5Key('formActionBar-primary'));
  await ph5Settle(tester);
  expect(find.text(message), findsWidgets);
  expect(tester.getTopLeft(find.text(anchor).first), before, reason: 'the form changed height');
}

void main() {
  group('add-transaction', () {
    final skip = !_done.contains('add-transaction');

    ph5TestWidgets('category, type and method open as sheets with a check on the chosen one', (tester) async {
      await pumpPh6(tester, 'add-transaction');
      await _tap(tester, find.text('Select category...'));
      _expectSheet(tester, 'Rent');
      await tester.tap(find.text('Rent').last);
      await ph5Settle(tester);
      await _tap(tester, find.text('Rent').first);
      expect(find.descendant(of: find.byType(BottomSheet), matching: ph5Key('pickerSheet-check')), findsOneWidget);
      await tester.tap(find.text('Rent').last);
      await ph5Settle(tester);
      await _tap(tester, find.text('Expense').first);
      _expectSheet(tester, 'Other Income');
      await tester.tap(find.text('Expense').last);
      await ph5Settle(tester);
      await _tap(tester, find.text('Select method'));
      _expectSheet(tester, 'M-Pesa');
    }, skip: skip);

    ph5TestWidgets('on a computer the category picker is still today\'s dialog', (tester) async {
      await pumpPh6(tester, 'add-transaction', size: _wide);
      await _tap(tester, find.text('Select category...'));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    }, skip: skip);

    ph5TestWidgets('an empty save: "Required" in the kept lines, the form keeps its height', (tester) async {
      await pumpPh6(tester, 'add-transaction');
      await _expectErrorInPlace(tester, 'Payment Method', 'Required');
    }, skip: skip);

    ph5TestWidgets('the amount opens the number keyboard; the keyboard moves on', (tester) async {
      await pumpPh6(tester, 'add-transaction');
      final amount = tester.widget<TextField>(_field('0.00'));
      expect(amount.keyboardType, TextInputType.number);
      expect(tester.widget<TextField>(_field('What was this for?')).textInputAction, TextInputAction.next);
      expect(amount.textInputAction, isNotNull);
    }, skip: skip);
  });

  group('add-client', () {
    final skip = !_done.contains('add-client');

    ph5TestWidgets('an empty save: the messages in the kept lines, the form keeps its height', (tester) async {
      await pumpPh6(tester, 'add-client');
      await _expectErrorInPlace(tester, 'Notes (optional)', 'Required');
    }, skip: skip);

    ph5TestWidgets('the farmer type and the crops and animals open as sheets', (tester) async {
      await pumpPh6(tester, 'add-client');
      await _tap(tester, find.text('Farmer').first);
      await _tap(tester, find.text('None').first);
      expect(find.byType(BottomSheet), findsOneWidget);
    }, skip: skip);

    ph5TestWidgets('the phone field opens the phone keyboard; the keyboard moves on', (tester) async {
      await pumpPh6(tester, 'add-client');
      expect(tester.widget<TextField>(_field('e.g. 07XX XXX XXX')).keyboardType, TextInputType.phone);
      expect(tester.widget<TextField>(_field('Enter client name')).textInputAction, TextInputAction.next);
    }, skip: skip);
  });

  group('record-payment', () {
    final skip = !_done.contains('record-payment');

    ph5TestWidgets('the debtor opens as a sheet of debtors; the chosen one is the payer', (tester) async {
      await pumpPh6(tester, 'record-payment');
      await _tap(tester, _field('Debtor'));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.getSize(find.ancestor(of: find.textContaining('Amina Juma').last, matching: find.byType(InkWell)).first).height,
          greaterThanOrEqualTo(56));
      await tester.tap(find.textContaining('Amina Juma').last);
      await ph5Settle(tester);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.textContaining('Amina Juma'), findsWidgets);
    }, skip: skip);

    ph5TestWidgets('an empty save: "Enter an amount" in the kept line, the form keeps its height', (tester) async {
      await pumpPh6(tester, 'record-payment');
      await _expectErrorInPlace(tester, 'Payment Method', 'Enter an amount');
    }, skip: skip);

    ph5TestWidgets('the amount opens the number keyboard and finishes the typing', (tester) async {
      await pumpPh6(tester, 'record-payment');
      final amount = tester.widget<TextField>(_field('Payment Amount'));
      expect(amount.keyboardType, TextInputType.number);
      expect(amount.textInputAction, TextInputAction.done);
    }, skip: skip);
  });

  group('record-visit', () {
    final skip = !_done.contains('record-visit');

    ph5TestWidgets('no overflow at 390 or 360, with an item row of a long name and an 8-digit price', (tester) async {
      for (final size in const [Size(390, 844), Size(360, 740)]) {
        await pumpPh6(tester, 'record-visit', size: size);
        await _tap(tester, find.text('Add Item'));
        await tester.enterText(_field('Item Name'), 'Dawa ya minyoo ya kuku na ng\'ombe wa maziwa');
        await tester.enterText(_field('Price'), '12345678');
        await ph5Settle(tester);
        expect(tester.takeException(), isNull, reason: '$size');
      }
    }, skip: skip);

    ph5TestWidgets('the category and the method open as sheets', (tester) async {
      await pumpPh6(tester, 'record-visit');
      await _tap(tester, find.text('Category').first);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('Treatment').last);
      await ph5Settle(tester);
      await tester.enterText(find.ancestor(of: find.text('0.00').last, matching: find.byType(TextField)).first, '1000');
      await ph5Settle(tester);
      await _tap(tester, find.text('Select method'));
      _expectSheet(tester, 'Cash');
    }, skip: skip);

    ph5TestWidgets('an empty save: the messages in the kept lines, the form keeps its height', (tester) async {
      await pumpPh6(tester, 'record-visit');
      await _expectErrorInPlace(tester, 'Expenses (Items Used)', 'Enter service name');
    }, skip: skip);
  });
}
