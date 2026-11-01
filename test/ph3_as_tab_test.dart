// PH3 (2): Sales and Products as tabs of the phone shell show their own
// AppBar with NO back arrow (it would pop the whole shell); pushed as screens
// (tablets, computers, the sidebar) they keep it. Pumped at 1200x800, where
// both lay out today (their phone layouts are PH5); the flag does not depend
// on the size.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/debt_provider.dart';
import 'package:vetbiz_pro/providers/facility_provider.dart';
import 'package:vetbiz_pro/providers/payment_provider.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';
import 'package:vetbiz_pro/providers/service_provider.dart';
import 'package:vetbiz_pro/providers/subscription_provider.dart';
import 'package:vetbiz_pro/providers/transaction_provider.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/providers/user_role_provider.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/sales/sales_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

import 'helpers/fake_firestore.dart';

const _skip = false;

class _NoAuth implements AuthService {
  @override
  User? getCurrentUser() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pushes [screen] over a first page, as the sidebar does (or as a tab
/// root that could pop would be), and says whether a back arrow shows.
Future<bool> _hasBackArrow(WidgetTester tester, Widget Function(FirebaseFirestore fs) screen) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'facilityId': testFacilityId, 'facilityName': 'Kilimo Agrovet'});
  final fs = newFakeFirestore();
  await tester.runAsync(() async {
    await facilityDoc(fs).set({'name': 'Kilimo Agrovet'});
    await fs.collection(Collections.users).doc(testUserId).set({'role': 'admin'});
  });
  final facility = FacilityProvider(firestore: fs);
  final ui = UiSettingsProvider();
  await tester.runAsync(() async {
    while (facility.selectedFacilityId == null || !ui.loaded) {
      await Future<void>.delayed(Duration.zero);
    }
  });
  final debts = DebtProvider(firestore: fs);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<AuthService>.value(value: _NoAuth()),
      ChangeNotifierProvider<FacilityProvider>.value(value: facility),
      ChangeNotifierProvider.value(value: ui),
      ChangeNotifierProvider.value(value: debts),
      ChangeNotifierProvider(create: (_) => UserRoleProvider(firestore: fs, currentUid: () => testUserId)),
      ChangeNotifierProvider(create: (_) => newClientProvider(fs)),
      ChangeNotifierProvider(create: (_) => newSaleProvider(fs)),
      ChangeNotifierProvider(create: (_) => ServiceProvider(debtProvider: debts, firestore: fs, currentUserInfo: testUserInfo)),
      ChangeNotifierProvider(create: (_) => TransactionProvider(firestore: fs, currentUserInfo: testUserInfo)),
      ChangeNotifierProvider(create: (_) => ProductProvider(firestore: fs, currentUserInfo: testUserInfo)),
      ChangeNotifierProvider(create: (_) => PaymentProvider(firestore: fs)),
      ChangeNotifierProvider(create: (_) => SubscriptionProvider(firestore: fs)),
    ],
    child: MaterialApp(
      navigatorKey: navigator,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      home: const Scaffold(body: Text('under')),
    ),
  ));
  navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => screen(fs)));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return find.byType(BackButton).evaluate().isNotEmpty;
}

void main() {
  testWidgets('Sales as a tab: no back arrow', (tester) async {
    expect(await _hasBackArrow(tester, (fs) => SalesScreen(firestore: fs, asTab: true)), isFalse);
  }, skip: _skip);

  testWidgets('Sales pushed as a screen: the back arrow, as before', (tester) async {
    expect(await _hasBackArrow(tester, (fs) => SalesScreen(firestore: fs)), isTrue);
  }, skip: _skip);

  testWidgets('Products as a tab: no back arrow', (tester) async {
    expect(await _hasBackArrow(tester, (fs) => ProductsScreen(firestore: fs, asTab: true)), isFalse);
  }, skip: _skip);

  testWidgets('Products pushed as a screen: the back arrow, as before', (tester) async {
    expect(await _hasBackArrow(tester, (fs) => ProductsScreen(firestore: fs)), isTrue);
  }, skip: _skip);
}
