// UX8 Fix 5: a modal form's warnings and errors are shown inside it
// (ModalErrorScope, from showAdaptiveForm), not as a toast on the page
// behind its scrim. The messages and when they are raised are unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/clients/add_client_screen.dart';
import 'package:vetbiz_pro/screens/debtors/add_payment_screen.dart';
import 'package:vetbiz_pro/screens/products/add_edit_product_screen.dart';
import 'package:vetbiz_pro/screens/products/add_batch_screen.dart';
import 'package:vetbiz_pro/screens/sales/add_sale_screen.dart';
import 'package:vetbiz_pro/screens/services/add_edit_service_screen.dart';
import 'package:vetbiz_pro/screens/transactions/add_transaction_screen.dart';
import 'package:vetbiz_pro/ui/feedback/app_feedback.dart';
import 'package:vetbiz_pro/ui/feedback/modal_error.dart';

import 'helpers/ph6_forms.dart';
import 'helpers/phone_list_harness.dart';

const _banner = ValueKey('modal-error-banner');

/// Opens [open] from a page at 1200x800 (a modal) and taps its Save (the
/// last enabled ElevatedButton in the modal) with nothing filled in; or
/// only opens it when [save] is false.
Future<void> _saveEmpty(WidgetTester tester, Future<void> Function(BuildContext) open, {bool save = true}) async {
  late BuildContext host;
  await pumpPh5(
    tester,
    (fs) => Scaffold(body: Builder(builder: (c) {
      host = c;
      return const Text('PAGE');
    })),
    size: const Size(1200, 800),
    seed: ph6Seed,
    auth: Ph6Auth(),
  );
  open(host);
  await ph5Settle(tester);
  while (tester.takeException() != null) {}
  expect(find.byType(ModalErrorScope), findsOneWidget, reason: 'the form is a modal');
  if (!save) return;
  final saveButton = find.descendant(
    of: find.byType(ModalErrorScope),
    matching: find.byWidgetPredicate((w) => w is ElevatedButton && w.onPressed != null),
  );
  await tester.ensureVisible(saveButton.last);
  await tester.tap(saveButton.last);
  await ph5Settle(tester);
  while (tester.takeException() != null) {}
}

void _insideOnly(WidgetTester tester, String message) {
  expect(find.descendant(of: find.byKey(_banner), matching: find.text(message)), findsOneWidget,
      reason: 'the message is in the modal');
  expect(find.byType(SnackBar), findsNothing, reason: 'and not behind it');
}

void main() {
  for (final (name, open, message) in <(String, Future<void> Function(BuildContext), String)>[
    ('Add Sale', (c) => showAddSaleScreen(c), 'Add at least one item before saving'),
    ('Add Transaction', (c) => showAddTransactionScreen(c), 'Fill in all required fields correctly'),
  ]) {
    ph5TestWidgets('$name at 1200x800: saving with a field missing shows the error in the modal', (tester) async {
      await _saveEmpty(tester, open);
      _insideOnly(tester, message);
    });
  }

  // These forms flag an empty field on the field itself (validators), before
  // any toast; their AppFeedback messages need part of the form filled.
  // Each real modal is open while its own message is raised, as its save
  // raises it.
  for (final (name, open, raise, message) in <(String, Future<void> Function(BuildContext), VoidCallback, String)>[
    ('Add Service', (c) => showAddEditServiceScreen(c),
        () => AppFeedback.warning('Total Paid cannot exceed Total Amount'), 'Total Paid cannot exceed Total Amount'),
    ('Record Payment', (c) => showAddPaymentScreen(c),
        () => AppFeedback.warning('Select how this payment was made'), 'Select how this payment was made'),
    ('Add Client', (c) => showAddClientScreen(c).then((_) {}),
        () => AppFeedback.error("Couldn't save the client", detail: 'No facility selected'), "Couldn't save the client"),
    ('Add Product', (c) => showAddEditProductScreen(c),
        () => AppFeedback.warning('A product with this name already exists'), 'A product with this name already exists'),
    ('Add Batch', (c) => showAddBatchScreen(c, product: ph6Product()),
        () => AppFeedback.error("Couldn't add the batch"), "Couldn't add the batch"),
  ]) {
    ph5TestWidgets('$name at 1200x800: its message while open is shown in the modal', (tester) async {
      await _saveEmpty(tester, open, save: false);
      raise();
      await tester.pump();
      _insideOnly(tester, message);
    });
  }

  ph5TestWidgets('the banner closes; a toast with no modal open is still a toast', (tester) async {
    await _saveEmpty(tester, (c) => showAddSaleScreen(c));
    await tester.tap(find.byKey(const ValueKey('modal-error-close')));
    await tester.pump();
    expect(find.byKey(_banner), findsNothing);
    // The modal gone, the same call is a toast again.
    Navigator.of(tester.element(find.byType(ModalErrorScope))).pop();
    await ph5Settle(tester);
    AppFeedback.warning('Add at least one item before saving');
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });
}
