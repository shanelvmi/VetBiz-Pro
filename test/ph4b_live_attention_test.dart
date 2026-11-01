// PH4b (1), the owner's decision: Needs attention stays live on phones. The
// facility's products used to be one get at activation, live only once
// Products or Stock Store had opened, so the phone home's strip could go
// stale. On phones (AppLayout.isPhone) that get is now a live listener whose
// first answer costs the same reads; tablets and computers keep the get.
//
// The activation, the sign-out and the providers are the real ones; the
// products go through the counting fake (helpers/counting_firestore.dart),
// and the stand-in dashboard draws the real strip from ProductProvider, as
// the phone home does (dashboard_screen.dart, attentionCountsFor).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/data/fields.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/providers/debt_provider.dart';
import 'package:vetbiz_pro/providers/facility_provider.dart';
import 'package:vetbiz_pro/providers/payment_provider.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';
import 'package:vetbiz_pro/providers/sale_provider.dart';
import 'package:vetbiz_pro/providers/service_provider.dart';
import 'package:vetbiz_pro/providers/subscription_provider.dart';
import 'package:vetbiz_pro/providers/transaction_provider.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/providers/user_role_provider.dart';
import 'package:vetbiz_pro/screens/dashboard/needs_attention.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/utils/facility_activation.dart';
import 'package:vetbiz_pro/utils/force_logout.dart';
import 'package:vetbiz_pro/utils/navigator_key.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/fake_firestore.dart';

const _skip = true;

const _phone = Size(390, 844);
const _tablet = Size(1024, 768);
const _otherFacility = 'facility2';

class _FakeUser extends Fake implements User {
  @override
  String get uid => testUserId;
}

class _FakeAuth extends Fake implements FirebaseAuth {
  int signOuts = 0;
  @override
  User? get currentUser => signOuts == 0 ? _FakeUser() : null;
  @override
  Future<void> signOut() async => signOuts++;
}

DocumentReference<Map<String, dynamic>> _product(CountingFirestore db, String facilityId, String id) =>
    db.inner.collection(Collections.facilities).doc(facilityId).collection(Collections.products).doc(id);

Future<void> _seed(CountingFirestore db, String facilityId) async {
  // One low product (3 of a threshold of 5), two fine ones.
  for (final (id, qty) in const [('amoxicillin', 50), ('dewormer', 3), ('vaccine', 40)]) {
    await _product(db, facilityId, id).set({
      'name': id,
      'sellableQty': qty,
      'stockQty': 0,
      'buyPrice': 1000,
      'sellPrice': 1500,
      'lowStockThreshold': 5,
    });
  }
}

Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The app's providers over the fake, the products over the counting fake.
Future<(CountingFirestore, ProductProvider)> _app(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final fs = newFakeFirestore();
  await facilityDoc(fs).set({'name': 'Kilimo Agrovet', 'type': 'agrovet'});
  await fs.collection(Collections.users).doc(testUserId).set({Fields.role: 'admin'});
  final db = CountingFirestore(fs);
  await _seed(db, testFacilityId);
  await _seed(db, _otherFacility);
  db.resetCounts();
  final products = ProductProvider(firestore: db, currentUserInfo: testUserInfo);
  final debts = DebtProvider(firestore: fs);
  pendingLoginMessage = null;
  dashboardScreenBuilder = () => Scaffold(
        body: Consumer<ProductProvider>(
          builder: (_, p, __) => NeedsAttentionStrip(
            counts: attentionCountsFor(products: p.products, debts: const [], overdueDays: 30),
            onOpen: (_) {},
          ),
        ),
      );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FacilityProvider(firestore: fs)),
        ChangeNotifierProvider(create: (_) => newClientProvider(fs)),
        ChangeNotifierProvider(create: (_) => UiSettingsProvider()),
        ChangeNotifierProvider.value(value: debts),
        ChangeNotifierProvider(create: (_) => UserRoleProvider(firestore: fs, currentUid: () => testUserId)),
        ChangeNotifierProvider(create: (_) => SaleProvider(firestore: fs, currentUserInfo: testUserInfo)),
        ChangeNotifierProvider(
          create: (_) => ServiceProvider(debtProvider: debts, firestore: fs, currentUserInfo: testUserInfo),
        ),
        ChangeNotifierProvider(create: (_) => TransactionProvider(firestore: fs, currentUserInfo: testUserInfo)),
        ChangeNotifierProvider.value(value: products),
        ChangeNotifierProvider(create: (_) => PaymentProvider(firestore: fs)),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider(firestore: fs)),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(body: Text('FRONT DOOR')),
      ),
    ),
  );
  return (db, products);
}

Future<void> _open(WidgetTester tester, [String facilityId = testFacilityId]) async {
  activateFacilityAndGoToDashboard(
    context: navigatorKey.currentContext!,
    facility: {Fields.facilityId: facilityId, 'facilityName': 'Kilimo Agrovet', 'facilityType': 'agrovet'},
  );
  await _wait(tester);
}

/// A sale took the amoxicillin down to 2 (low), on another device or here.
Future<void> _sellAmoxicillinDown(WidgetTester tester, CountingFirestore db, [String facilityId = testFacilityId]) async {
  await _product(db, facilityId, 'amoxicillin').update({'sellableQty': 2});
  await _wait(tester);
}

/// The strip's stock count, from the chip of its "Low or out of stock" row.
int _stockCount(WidgetTester tester) {
  final row = find.ancestor(of: find.text('Low or out of stock'), matching: find.byType(InkWell));
  final chip = find.descendant(of: row, matching: find.textContaining(RegExp(r'^\d+$')));
  return int.parse((tester.widget<Text>(chip).data)!);
}

void main() {
  tearDown(() {
    logoutAuth = () => FirebaseAuth.instance;
    pushAuthUser = null;
  });

  group('the products behind Needs attention', () {
    testWidgets('a phone: one live listener, and its first answer costs what the get did', (tester) async {
      final (db, products) = await _app(tester, _phone);
      await _open(tester);
      expect(products.products, hasLength(3));
      expect(db.listeners, 1);
      expect(db.gets, 0);
      expect(db.reads, 3, reason: 'one read per product, as the one-time get');
    }, skip: _skip);

    testWidgets('a tablet or a computer: today\'s one get, no listener', (tester) async {
      final (db, products) = await _app(tester, _tablet);
      await _open(tester);
      expect(products.products, hasLength(3));
      expect(db.listeners, 0);
      expect(db.gets, 1);
      expect(db.reads, 3);
    }, skip: _skip);

    testWidgets('a phone: a stock change after the first load updates the strip, Products never opened',
        (tester) async {
      final (db, _) = await _app(tester, _phone);
      await _open(tester);
      expect(_stockCount(tester), 1);
      db.resetCounts();
      await _sellAmoxicillinDown(tester, db);
      expect(_stockCount(tester), 2);
      expect(db.reads, 1, reason: 'only the changed product is read');
    }, skip: _skip);

    testWidgets('a tablet: unchanged, the strip\'s products are today\'s one get', (tester) async {
      final (db, _) = await _app(tester, _tablet);
      await _open(tester);
      expect(_stockCount(tester), 1);
      await _sellAmoxicillinDown(tester, db);
      expect(_stockCount(tester), 1);
    }, skip: _skip);

    testWidgets('a phone: signing out cancels the listener', (tester) async {
      final (db, products) = await _app(tester, _phone);
      final auth = _FakeAuth();
      logoutAuth = () => auth;
      await _open(tester);
      expect(db.listeners, 1);
      await forceLogoutAndShowLogin();
      await _wait(tester);
      expect(auth.signOuts, 1);
      expect(db.listeners, 0);
      await _sellAmoxicillinDown(tester, db);
      expect(products.products, isEmpty);
    }, skip: _skip);

    testWidgets('a phone: opening another facility cancels the first listener and listens to the new one',
        (tester) async {
      final (db, _) = await _app(tester, _phone);
      await _open(tester);
      await _open(tester, _otherFacility);
      expect(db.listeners, 1);
      await _sellAmoxicillinDown(tester, db);
      expect(_stockCount(tester), 1, reason: 'the first facility\'s change is not heard');
      await _sellAmoxicillinDown(tester, db, _otherFacility);
      expect(_stockCount(tester), 2);
    }, skip: _skip);
  });
}
