import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/facility_provider.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/providers/user_role_provider.dart';
import 'package:vetbiz_pro/screens/products/stock_alerts_screen.dart';
import 'package:vetbiz_pro/screens/reports/past_reports_screen.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/screen_size_matrix.dart';

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

/// The case names at the given sizes, in every look, and the text at 1.3 when
/// 360 is among them, all with one [reason].
Map<String, String> _cases(List<String> sizes, String reason) => {
      for (final s in matrixSizes.where((s) => sizes.contains(s.label)))
        for (final look in MatrixLook.values) matrixCase(s, look): reason,
      if (sizes.contains('360x740')) matrixTextScaleCase: reason,
    };

void main() {
  screenSizeMatrix(
    'Settings',
    screen: () => const SettingsScreen(),
    skip: {
      ..._cases(['360x740', '390x844'], 'the section headers are 11 px, under 12 on a phone (S3; PH8)'),
      ..._cases(['1024x768', '1200x800'],
          'the two-pane view opens Subscription first for an admin, and SubscriptionScreen reads FirebaseFirestore.instance (no seam yet; PH8)'),
    },
    prepare: (tester) async {
      final fs = newFakeFirestore();
      final ui = await _loadedUi(tester);
      final role = await _admin(tester, fs);
      return (app) => MultiProvider(providers: [
            ChangeNotifierProvider.value(value: ui),
            ChangeNotifierProvider.value(value: role),
          ], child: app);
    },
  );

  screenSizeMatrix(
    'Stock alerts',
    screen: () => const StockAlertsScreen(),
    skip: _cases(['360x740', '390x844'],
        'the pager row (stock_alerts_screen.dart:1111, rows per page and the page buttons) overflows by 35 to 153 px on a phone (PH7)'),
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
    skip: {
      ..._cases(['360x740', '390x844'],
          "the summary cards' labels (Reports generated, Loaded period, Latest) are 11 px, under 12 on a phone (S3; PH7)"),
      '360x740 kiswahili': 'the time filter dropdown (as wide as its longest Kiswahili label, past_reports_screen.dart:266) squeezes the search field to 18 px (a 48 px tap target fails), and the summary labels are 11 px (PH7)',
    },
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
