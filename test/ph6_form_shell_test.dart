// PH6 S6 on the four simple money forms (Add Client, Add Transaction,
// Record Payment, Record Visit) on a phone: the footer is the pinned
// FormActionBar, which rises above the keyboard; leaving with entered data
// asks (Keep editing, Discard), a clean form leaves, a save does not ask; a
// tap outside a field closes the keyboard; each form at 360x740, 390x844
// and 740x360 in Light, Dark and Kiswahili has no overflow, 48 px targets
// and no text under 12 px.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ph5b_finders.dart';
import 'helpers/ph6_forms.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

/// The forms done so far: the others stay skipped until theirs is.
const _done = <String>{'add-transaction', 'record-payment'};

/// Each form: its discard kind, its primary button, a field to type in.
const _forms = {
  'add-client': ('client', 'Save Client', 'Enter client name'),
  'add-transaction': ('transaction', 'Record Transaction', 'What was this for?'),
  'record-payment': ('payment', 'Save Payment', 'Payment Amount'),
  'record-visit': ('visit', 'Record Visit', 'Service Name'),
};

Finder _field(String text) => find.ancestor(of: find.text(text), matching: find.byType(TextField)).first;

void main() {
  for (final e in _forms.entries) {
    final name = e.key;
    final (kind, primary, field) = e.value;
    final skip = !_done.contains(name);

    group(name, () {
      ph5TestWidgets('the footer is the pinned action bar, above a 300 px keyboard', (tester) async {
        await pumpPh6(tester, name, pushed: true);
        final bar = ph5Key('formActionBar');
        expect(bar, findsOneWidget);
        expect(find.descendant(of: bar, matching: find.text(primary)), findsOneWidget);
        expect(tester.getRect(ph5Key('formActionBar-primary')).height, greaterThanOrEqualTo(48));
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await ph5Settle(tester);
        expect(tester.getRect(ph5Key('formActionBar-primary')).bottom, lessThanOrEqualTo(844 - 300));
        expect(tester.takeException(), isNull);
      }, skip: skip);

      ph5TestWidgets('a clean form leaves without asking', (tester) async {
        await pumpPh6(tester, name, pushed: true);
        await tester.tap(find.byType(BackButton));
        await ph5Settle(tester);
        expect(find.text('UNDER'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
      }, skip: skip);

      ph5TestWidgets('with entered data, Back asks; Keep editing stays; Discard leaves', (tester) async {
        await pumpPh6(tester, name, pushed: true);
        await tester.enterText(_field(field), '12');
        await tester.pump();
        await tester.tap(find.byType(BackButton));
        await ph5Settle(tester);
        final question = switch (kind) {
          'client' => 'Discard this client?',
          'transaction' => 'Discard this transaction?',
          'payment' => 'Discard this payment?',
          _ => 'Discard this visit?',
        };
        expect(find.text(question), findsOneWidget);
        await tester.tap(find.text('Keep editing'));
        await ph5Settle(tester);
        expect(find.text('UNDER'), findsNothing);
        // The system back (Android's gesture, the browser's back) asks too.
        await tester.binding.handlePopRoute();
        await ph5Settle(tester);
        expect(find.text(question), findsOneWidget);
        await tester.tap(find.text('Discard'));
        await ph5Settle(tester);
        expect(find.text('UNDER'), findsOneWidget);
      }, skip: skip);

      ph5TestWidgets('a tap outside a field closes the keyboard', (tester) async {
        await pumpPh6(tester, name, pushed: true);
        await tester.tap(_field(field));
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNotNull);
        await tester.tapAt(tester.getTopLeft(ph5Key('formActionBar')) - const Offset(-8, 4));
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNull);
      }, skip: skip);

      for (final size in ph5PhoneSizes) {
        for (final look in MatrixLook.values) {
          final where = '$name ${matrixCase(size, look)}';
          ph5TestWidgets(where, (tester) async {
            await pumpPh6(tester, name, size: size.size, look: look);
            await checkCase(tester, phone: true, where: where);
          }, skip: skip);
        }
      }
    });
  }

  for (final name in ['add-client', 'add-transaction']) {
    ph5TestWidgets('$name: a save leaves without asking', (tester) async {
      await pumpPh6(tester, name, pushed: true);
      if (name == 'add-client') {
        await tester.enterText(_field('Enter client name'), 'Zawadi Said');
        await tester.enterText(_field('e.g. 07XX XXX XXX'), '0754 123 456');
        await tester.enterText(_field('Enter address'), 'Moshi');
        await tester.ensureVisible(find.text('Farmer').first);
        await tester.tap(find.text('Farmer').first);
      } else {
        await tester.tap(find.text('Select category...'));
        await ph5Settle(tester);
        await tester.tap(find.text('Rent').last);
        await ph5Settle(tester);
        await tester.enterText(_field('What was this for?'), 'Rent');
        await tester.enterText(_field('0.00'), '25000');
        await tester.ensureVisible(find.text('Select method'));
        await tester.tap(find.text('Select method'));
        await ph5Settle(tester);
        await tester.tap(find.text('Cash').last);
      }
      await ph5Settle(tester);
      await tester.tap(ph5Key('formActionBar-primary'));
      await ph5Settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('UNDER'), findsOneWidget);
    }, skip: !_done.contains(name));
  }
}
