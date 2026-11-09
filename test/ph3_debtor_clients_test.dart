// PH3 (4): the debtor fetch Record Payment needs moved out of Debtors into
// one shared function (lib/services/debtor_clients_service.dart), used by
// Debtors and the phone's "+" sheet. Debtors behaves as before.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/client_provider.dart';
import 'package:vetbiz_pro/providers/debt_provider.dart';
import 'package:vetbiz_pro/providers/facility_provider.dart';
import 'package:vetbiz_pro/providers/payment_provider.dart';
import 'package:vetbiz_pro/providers/subscription_provider.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/providers/user_role_provider.dart';
import 'package:vetbiz_pro/screens/debtors/add_payment_screen.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/services/debtor_clients_service.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/screen_size_matrix.dart';
import 'helpers/wait_until.dart';

const _skip = false;

class _NoAuth implements AuthService {
  @override
  User? getCurrentUser() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _seed(FirebaseFirestore fs) async {
  await facilityDoc(fs).set({'name': 'Kilimo Agrovet'});
  await fs.collection(Collections.users).doc(testUserId).set({'role': 'admin'});
  await seedClient(fs, id: 'c1', name: 'Juma', balance: 12500);
  await seedClient(fs, id: 'c2', name: 'Neema', balance: 0);
  await seedClient(fs, id: 'c3', name: 'Baraka', balance: 300);
}

void main() {
  test('every client who owes money now, and only them', () async {
    final fs = newFakeFirestore();
    await _seed(fs);
    final debtors = await fetchAllDebtorClients(fs, testFacilityId);
    expect({for (final c in debtors) c.name: c.balance}, {'Juma': 12500, 'Baraka': 300});
  }, skip: _skip);

  test('nobody owes money: an empty list; no facility open: an empty list', () async {
    final fs = newFakeFirestore();
    await seedClient(fs, id: 'c2', name: 'Neema', balance: 0);
    expect(await fetchAllDebtorClients(fs, testFacilityId), isEmpty);
    expect(await fetchAllDebtorClients(fs, null), isEmpty);
  }, skip: _skip);

  testWidgets('Debtors: Record Payment still opens the form with every debtor and their balances', (tester) async {
    SharedPreferences.setMockInitialValues({'facilityId': testFacilityId, 'facilityName': 'Kilimo Agrovet'});
    final fs = newFakeFirestore();
    await tester.runAsync(() => _seed(fs));
    final facility = FacilityProvider(firestore: fs);
    final ui = UiSettingsProvider();
    await waitUntil(tester, () => facility.selectedFacilityId != null && ui.loaded, what: 'the facility and UI settings');
    final debts = DebtProvider(firestore: fs);
    await pumpAtSize(
      tester,
      screen: DebtorsScreen(firestore: fs),
      size: const Size(1200, 800),
      wrap: (app) => MultiProvider(providers: [
        Provider<AuthService>.value(value: _NoAuth()),
        ChangeNotifierProvider<FacilityProvider>.value(value: facility),
        ChangeNotifierProvider.value(value: ui),
        ChangeNotifierProvider.value(value: debts),
        ChangeNotifierProvider(create: (_) => UserRoleProvider(firestore: fs, currentUid: () => testUserId)),
        ChangeNotifierProvider(create: (_) => newClientProvider(fs)),
        ChangeNotifierProvider(create: (_) => PaymentProvider(firestore: fs)),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider(firestore: fs)),
      ], child: app),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Record Payment'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    final form = tester.widget<AddPaymentScreen>(find.byType(AddPaymentScreen));
    expect({for (final c in form.debtorClients!) c.name}, {'Juma', 'Baraka'});
    expect(form.debtorBalances, {'c1': 12500, 'c3': 300});
    expect(form.facilityId, testFacilityId);
    expect(Provider.of<ClientProvider>(tester.element(find.byType(DebtorsScreen)), listen: false), isNotNull);
  }, skip: _skip);
}
