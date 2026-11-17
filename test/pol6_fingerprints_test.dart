// POL6: the "before" fingerprints of the group 5 forms that had none (Add
// Client, Edit Client, Record Payment, Add Transaction) at 768x1024,
// 1024x768 and 1200x800, recorded on the code before POL6 changed them
// (test/fixtures/ph5a_wide_fingerprints.json, the pol6- names). A later
// commit may change one only where a decoration was removed or a pill
// became a dot, and says which.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/models/client.dart';
import 'package:vetbiz_pro/screens/clients/add_client_screen.dart';
import 'package:vetbiz_pro/screens/debtors/add_payment_screen.dart';
import 'package:vetbiz_pro/screens/transactions/add_transaction_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph7b_report.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/tree_fingerprint.dart';

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

final _client = Client(
  id: 'c1',
  name: 'Amina Juma',
  phone: '0712345678',
  address: 'Arusha',
  types: const ['Farmer', 'Vet'],
  animalSpecies: const ['Cattle'],
);

void main() {
  final forms = <String, (Widget Function(dynamic fs), Type)>{
    'add-client': ((fs) => const AddClientScreen(isModal: true), AddClientScreen),
    'edit-client': ((fs) => AddClientScreen(client: _client, isModal: true), AddClientScreen),
    'record-payment': (
      (fs) => AddPaymentScreen(firestore: fs, facilityId: testFacilityId, isModal: true, debtorClients: const [], debtorBalances: const {}),
      AddPaymentScreen
    ),
    'add-transaction': ((fs) => AddTransactionScreen(firestore: fs, authService: Ph7bNoAuth(), isModal: true), AddTransactionScreen),
  };
  for (final e in forms.entries) {
    final (build, type) = e.value;
    for (final size in ph5WideSizes) {
      final where = 'pol6-${e.key}-${size.width.toInt()}x${size.height.toInt()}';
      ph5TestWidgets('$where: the form as before POL6', (tester) async {
        await pumpPh5(tester, (fs) => build(fs), size: size, pushed: true);
        expectSameFingerprint(where, '${_errors(tester)}${treeFingerprint(tester, find.byType(type))}');
      });
    }
  }
}
