import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/facility_provider.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';
import 'package:vetbiz_pro/providers/subscription_provider.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/providers/user_role_provider.dart';
import 'package:vetbiz_pro/screens/products/stock_alerts_screen.dart';
import 'package:vetbiz_pro/screens/reports/past_reports_screen.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/screen_size_matrix.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;

// PH2a: the size matrix applied to three screens as proof
// (phone_foundations.md section 10). A case that fails for a real layout
// reason is skipped here with that reason, and listed in the RUNBOOK2
// ledger for PH5 to PH8; it is not fixed in PH2a.

/// UiSettingsProvider loads from the device first.
Future<UiSettingsProvider> _loadedUi(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  return (await tester.runAsync(() async {
    final p = UiSettingsProvider();
    while (!p.loaded) {
      await Future<void>.delayed(Duration.zero);
    }
    return p;
  }))!;
}

/// An admin, so every row and action shows.
Future<UserRoleProvider> _admin(WidgetTester tester, FirebaseFirestore fs) async {
  await tester.runAsync(() => fs.collection(Collections.users).doc(testUserId).set({'role': 'admin'}));
  return UserRoleProvider(firestore: fs, currentUid: () => testUserId)..listenToCurrentUser();
}

/// Products for every alert kind, with long Kiswahili names and an 8-digit price.
Future<void> _seedAlertProducts(FirebaseFirestore fs) async {
  final products = facilityCollection(fs, Collections.products);
  final soon = Timestamp.fromDate(DateTime.now().add(const Duration(days: 10)));
  final past = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 10)));
  final base = {
    'unit': 'pcs',
    'category': 'Dawa za Mifugo na Chanjo za Kuku',
    'buyPrice': matrixBigAmount,
    'sellPrice': matrixBigAmount,
    'hasEverHadStock': true,
  };
  await products.doc('a').set({...base, 'name': matrixLongProductName, 'sellableQty': 0, 'stockQty': 0});
  await products.doc('b').set({...base, 'name': '$matrixLongProductName B', 'sellableQty': 2, 'stockQty': 0, 'lowStockThreshold': 10});
  await products.doc('c').set({...base, 'name': '$matrixLongProductName C', 'sellableQty': 50, 'stockQty': 5, 'expiry': soon});
  await products.doc('d').set({...base, 'name': '$matrixLongProductName D', 'sellableQty': 7, 'stockQty': 0, 'expiry': past});
}

void main() {
  // PH8a: the section headers are 12 px on a phone, and the wide view's
  // Subscription pane takes the fake Firestore (the seam): every case runs.
  late FirebaseFirestore settingsFs;
  screenSizeMatrix(
    'Settings',
    screen: () => SettingsScreen(firestore: settingsFs, auth: Ph8Auth()),
    prepare: (tester) async {
      final fs = settingsFs = newFakeFirestore();
      final ui = await _loadedUi(tester);
      final role = await _admin(tester, fs);
      return (app) => MultiProvider(providers: [
            ChangeNotifierProvider.value(value: ui),
            ChangeNotifierProvider.value(value: role),
            ChangeNotifierProvider(create: (_) => FacilityProvider(firestore: fs)),
            ChangeNotifierProvider(create: (_) => SubscriptionProvider(firestore: fs)),
          ], child: app);
    },
  );

  screenSizeMatrix(
    'Stock alerts',
    screen: () => const StockAlertsScreen(),
    prepare: (tester) async {
      final fs = newFakeFirestore();
      await tester.runAsync(() => _seedAlertProducts(fs));
      final ui = await _loadedUi(tester);
      final role = await _admin(tester, fs);
      final products = ProductProvider(firestore: fs, currentUserInfo: testUserInfo)..listenToProducts(testFacilityId);
      return (app) => MultiProvider(providers: [
            ChangeNotifierProvider.value(value: ui),
            ChangeNotifierProvider.value(value: role),
            ChangeNotifierProvider.value(value: products),
          ], child: app);
    },
  );

  // No facility chosen: the screen shows its empty state (PH7 seeds reports).
  screenSizeMatrix(
    'Past reports',
    screen: () => PastReportsScreen(firestore: newFakeFirestore()),
    prepare: (tester) async {
      final ui = await _loadedUi(tester);
      final facility = FacilityProvider(firestore: newFakeFirestore());
      return (app) => MultiProvider(providers: [
            ChangeNotifierProvider.value(value: ui),
            ChangeNotifierProvider<FacilityProvider>.value(value: facility),
          ], child: app);
    },
  );
}
