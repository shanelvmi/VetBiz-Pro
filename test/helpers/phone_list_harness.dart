// PH5a: Sales and Services on the real providers over a fake Firestore, at a
// window size and look, with seeded records whose daily summaries match
// them.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/data/payment_status.dart';
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
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/ui/feedback/app_feedback.dart';

import 'fake_firestore.dart';
import 'screen_size_matrix.dart';

class _NoAuth implements AuthService {
  @override
  User? getCurrentUser() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A facility whose subscription is locked (the guard's case).
class LockedSubscription extends SubscriptionProvider {
  LockedSubscription({super.firestore});
  @override
  bool get isLocked => true;
}

const ph5PhoneSizes = [
  MatrixSize('360x740', Size(360, 740), phone: true),
  MatrixSize('390x844', Size(390, 844), phone: true),
  MatrixSize('740x360', Size(740, 360), phone: true),
];

const ph5WideSizes = [Size(768, 1024), Size(1024, 768), Size(1200, 800)];

/// A record [daysAgo] days back, [minutes] minutes after 08:00 that day
/// (today: [minutes] minutes before now, so it is never in the future).
DateTime ph5When(int daysAgo, {int minutes = 0}) {
  final now = DateTime.now();
  if (daysAgo == 0) return now.subtract(Duration(minutes: minutes + 1));
  final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo));
  return day.add(Duration(hours: 8, minutes: minutes));
}

String ph5DayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One seeded sale, as Sale.toMap stores it.
class Ph5Sale {
  final String id;
  final DateTime when;
  final String? client;
  final double amount;
  final double paid;
  final String seller;
  final int receipt;

  const Ph5Sale(this.id, this.when, {this.client, this.amount = 10000, this.paid = 10000, this.seller = 'Asha', this.receipt = 1});
}

/// One seeded service, as Service.toMap stores it.
class Ph5Service {
  final String id;
  final DateTime when;
  final String? client;
  final double amount;
  final double paid;
  final String category;
  final String method;
  final int receipt;

  const Ph5Service(this.id, this.when,
      {this.client, this.amount = 20000, this.paid = 20000, this.category = 'Treatment', this.method = 'cash', this.receipt = 1});
}

/// Writes the sales and their daily summaries and collections (what the
/// Cloud Functions would write), so the cards' figures follow the records.
Future<void> ph5SeedSales(FirebaseFirestore fs, List<Ph5Sale> sales) async {
  final f = fs.collection(Collections.facilities).doc(testFacilityId);
  final days = <String, Map<String, double>>{};
  for (final s in sales) {
    await f.collection(Collections.sales).doc(s.id).set({
      'timestamp': Timestamp.fromDate(s.when),
      'clientName': s.client,
      'clientNameLower': s.client?.toLowerCase(),
      'totalAmount': s.amount,
      'totalPaid': s.paid,
      'paymentStatus': PaymentStatus.of(s.paid, s.amount),
      'soldByName': s.seller,
      'soldById': 'u-${s.seller}',
      'receiptNumber': s.receipt,
      'paymentMethod': 'cash',
      'items': [
        {'productId': 'p1', 'name': 'Albendazole', 'quantity': 2, 'unitPrice': s.amount / 2, 'discount': 0, 'unit': 'pcs'},
      ],
    });
    final d = days.putIfAbsent(ph5DayKey(s.when), () => {'totalAmount': 0, 'totalPaid': 0, 'saleCount': 0});
    d['totalAmount'] = d['totalAmount']! + s.amount;
    d['totalPaid'] = d['totalPaid']! + s.paid;
    d['saleCount'] = d['saleCount']! + 1;
  }
  for (final e in days.entries) {
    await f.collection(Collections.dailySummaries).doc(e.key).set(e.value);
    await f.collection(Collections.dailyCollections).doc(e.key).set({'totalCollected': e.value['totalPaid']});
  }
}

Future<void> ph5SeedServices(FirebaseFirestore fs, List<Ph5Service> services) async {
  final f = fs.collection(Collections.facilities).doc(testFacilityId);
  for (final s in services) {
    await f.collection(Collections.services).doc(s.id).set({
      'serviceDate': Timestamp.fromDate(s.when),
      'updatedAt': Timestamp.fromDate(s.when),
      'name': '${s.category} visit',
      'description': '',
      'category': s.category,
      'clientName': s.client,
      'clientNameLower': s.client?.toLowerCase(),
      'providedByName': 'Dr. Asha',
      'totalAmount': s.amount,
      'totalPaid': s.paid,
      'paymentStatus': PaymentStatus.of(s.paid, s.amount),
      'paymentMethod': s.method,
      'receiptNumber': s.receipt,
      'itemsUsed': const [],
    });
  }
}

/// What a test holds after pumping.
class Ph5App {
  final FirebaseFirestore fs;
  final GlobalKey<NavigatorState> navigator;
  Ph5App(this.fs, this.navigator);
}

/// Pumps [screen] (pushed over a first page when [pushed], as from More or
/// the sidebar; as the home otherwise, as a tab is) at [size] in [look].
Future<Ph5App> pumpPh5(
  WidgetTester tester,
  Widget Function(FirebaseFirestore fs) screen, {
  Size size = const Size(390, 844),
  MatrixLook look = MatrixLook.light,
  bool admin = true,
  bool locked = false,
  bool pushed = false,
  FirebaseFirestore? firestore,
  Future<void> Function(FirebaseFirestore fs)? seed,
  bool settle = true,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final locale = Locale(look == MatrixLook.kiswahili ? 'sw' : 'en');
  final before = L10n.locale;
  L10n.setLocale(locale);
  addTearDown(() => L10n.setLocale(before));
  SharedPreferences.setMockInitialValues({'facilityId': testFacilityId, 'facilityName': 'Kilimo Agrovet'});
  final fs = firestore ?? newFakeFirestore();
  await tester.runAsync(() async {
    await facilityDoc(fs).set({'name': 'Kilimo Agrovet'});
    await fs.collection(Collections.users).doc(testUserId).set({'role': admin ? 'admin' : 'assistant'});
    if (seed != null) await seed(fs);
  });
  final facility = FacilityProvider(firestore: fs);
  final ui = UiSettingsProvider();
  final role = UserRoleProvider(firestore: fs, currentUid: () => testUserId)..listenToCurrentUser();
  await tester.runAsync(() async {
    while (facility.selectedFacilityId == null || !ui.loaded || role.isAdmin != admin) {
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
      ChangeNotifierProvider.value(value: role),
      ChangeNotifierProvider(create: (_) => newClientProvider(fs)),
      ChangeNotifierProvider(create: (_) => newSaleProvider(fs)),
      ChangeNotifierProvider(create: (_) => ServiceProvider(debtProvider: debts, firestore: fs, currentUserInfo: testUserInfo)),
      ChangeNotifierProvider(create: (_) => TransactionProvider(firestore: fs, currentUserInfo: testUserInfo)),
      ChangeNotifierProvider(create: (_) => ProductProvider(firestore: fs, currentUserInfo: testUserInfo)),
      ChangeNotifierProvider(create: (_) => PaymentProvider(firestore: fs)),
      ChangeNotifierProvider<SubscriptionProvider>(
          create: (_) => locked ? LockedSubscription(firestore: fs) : SubscriptionProvider(firestore: fs)),
    ],
    child: MaterialApp(
      navigatorKey: navigator,
      scaffoldMessengerKey: AppFeedback.messengerKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.build(AppColorTheme.pasture, look == MatrixLook.dark ? Brightness.dark : Brightness.light),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
      home: pushed ? const Scaffold(body: Text('UNDER')) : screen(fs),
    ),
  ));
  if (pushed) navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => screen(fs)));
  if (settle) await ph5Settle(tester);
  return Ph5App(fs, navigator);
}

/// Lets the fake Firestore's answers and the providers arrive.
Future<void> ph5Settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

