import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/debt_provider.dart';
import 'package:vetbiz_pro/providers/facility_provider.dart';
import 'package:vetbiz_pro/providers/payment_provider.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';
import 'package:vetbiz_pro/providers/service_provider.dart';
import 'package:vetbiz_pro/providers/subscription_provider.dart';
import 'package:vetbiz_pro/providers/transaction_provider.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/providers/user_role_provider.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';
import 'package:vetbiz_pro/screens/debtors/add_payment_screen.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';
import 'package:vetbiz_pro/screens/payments/payments_screen.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/sales/add_sale_screen.dart';
import 'package:vetbiz_pro/screens/services/services_screen.dart';
import 'package:vetbiz_pro/screens/transactions/add_transaction_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/screen_size_matrix.dart';

// PH2a seams for the money screens (phone_foundations.md section 10): each
// takes an optional firestore (and Add Transaction an authService), as
// LoginScreen does, so the size matrix can build them in PH5 and PH6.
const _skip = true;

/// No one signed in; nothing else is called while a screen only builds.
class _NoAuth implements AuthService {
  @override
  User? getCurrentUser() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Every provider the eight screens read, on [fs], with a facility chosen
/// (as after sign-in) and a long-named client and product in it.
Future<Widget Function(Widget)> _providers(WidgetTester tester, FirebaseFirestore fs) async {
  SharedPreferences.setMockInitialValues({'facilityId': testFacilityId, 'facilityName': matrixLongFacilityName});
  await tester.runAsync(() async {
    await facilityDoc(fs).set({'name': matrixLongFacilityName});
    await fs.collection(Collections.users).doc(testUserId).set({'role': 'admin'});
    await seedClient(fs, id: 'c1', name: matrixLongClientName, balance: matrixBigAmount);
    await seedProduct(fs, id: matrixLongProductName, legacyQty: 3, buyPrice: matrixBigAmount);
  });
  final facility = FacilityProvider(firestore: fs);
  final ui = UiSettingsProvider();
  await tester.runAsync(() async {
    while (facility.selectedFacilityId == null || !ui.loaded) {
      await Future<void>.delayed(Duration.zero);
    }
  });
  final debts = DebtProvider(firestore: fs);
  return (app) => MultiProvider(providers: [
        Provider<AuthService>.value(value: _NoAuth()),
        ChangeNotifierProvider<FacilityProvider>.value(value: facility),
        ChangeNotifierProvider.value(value: ui),
        ChangeNotifierProvider.value(value: debts),
        ChangeNotifierProvider(create: (_) => UserRoleProvider(firestore: fs, currentUid: () => testUserId)..listenToCurrentUser()),
        ChangeNotifierProvider(create: (_) => newClientProvider(fs)..listenToClients(testFacilityId)),
        ChangeNotifierProvider(create: (_) => newSaleProvider(fs)),
        ChangeNotifierProvider(create: (_) => ServiceProvider(debtProvider: debts, firestore: fs, currentUserInfo: testUserInfo)),
        ChangeNotifierProvider(create: (_) => TransactionProvider(firestore: fs, currentUserInfo: testUserInfo)),
        ChangeNotifierProvider(create: (_) => ProductProvider(firestore: fs, currentUserInfo: testUserInfo)..listenToProducts(testFacilityId)),
        ChangeNotifierProvider(create: (_) => PaymentProvider(firestore: fs)),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider(firestore: fs)),
      ], child: app);
}

/// The screens, each given the fake Firestore.
final Map<String, Widget Function(FirebaseFirestore)> _screens = {
  'Debtors': (fs) => DebtorsScreen(firestore: fs),
  'Payments': (fs) => PaymentsScreen(firestore: fs),
  'Record Payment': (fs) => AddPaymentScreen(firestore: fs, facilityId: testFacilityId, debtorClients: const [], debtorBalances: const {}),
  'Add Sale': (fs) => AddSaleScreen(firestore: fs),
  'Clients': (fs) => ClientsScreen(firestore: fs),
  'Services': (fs) => ServicesScreen(firestore: fs),
  'Products': (fs) => ProductsScreen(firestore: fs),
  'Add Transaction': (fs) => AddTransactionScreen(firestore: fs, authService: _NoAuth()),
};

/// The files, and what each must read Firestore (and sign-in) through.
const _files = {
  'lib/screens/debtors/debtors_screen.dart': 7,
  'lib/screens/payments/payments_screen.dart': 7,
  'lib/screens/debtors/add_payment_screen.dart': 9,
  'lib/screens/sales/add_sale_screen.dart': 2,
  'lib/screens/clients/clients_screen.dart': 1,
  'lib/screens/services/services_screen.dart': 1,
  'lib/screens/products/products_screen.dart': 1,
  'lib/screens/transactions/add_transaction_screen.dart': 1,
};

void main() {
  for (final e in _screens.entries) {
    testWidgets('${e.key} builds on a fake Firestore at 390x844 with no exception', (tester) async {
      final fs = newFakeFirestore();
      final wrap = await _providers(tester, fs);
      await pumpAtSize(tester, screen: e.value(fs), size: const Size(390, 844), wrap: wrap);
      await checkCase(tester, phone: false, where: e.key);
      expect(find.byWidgetPredicate((w) => w.runtimeType == e.value(fs).runtimeType), findsOneWidget);
    }, skip: _skip);
  }

  test('with nothing passed, each screen uses FirebaseFirestore.instance (and Add Transaction a new AuthService)', () {
    // Unset by default...
    expect(const DebtorsScreen().firestore, isNull);
    expect(const PaymentsScreen().firestore, isNull);
    expect(const AddPaymentScreen().firestore, isNull);
    expect(const AddSaleScreen().firestore, isNull);
    expect(const ClientsScreen().firestore, isNull);
    expect(const ServicesScreen().firestore, isNull);
    expect(const ProductsScreen().firestore, isNull);
    expect(const AddTransactionScreen().firestore, isNull);
    expect(const AddTransactionScreen().authService, isNull);
    // ...and then the one getter falls back to the app's own instance, the
    // only place each file still names it; every old use goes through it.
    for (final e in _files.entries) {
      final src = File(e.key).readAsStringSync();
      expect('FirebaseFirestore.instance'.allMatches(src).length, 1, reason: e.key);
      expect(src, contains('FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;'), reason: e.key);
      expect(RegExp(r'\b_db\b').allMatches(src).length, greaterThanOrEqualTo(e.value + 1), reason: e.key);
    }
    final tx = File('lib/screens/transactions/add_transaction_screen.dart').readAsStringSync();
    expect(tx, contains('widget.authService ?? AuthService()'));
    expect('AuthService()'.allMatches(tx).length, 1);
  }, skip: _skip);
}
