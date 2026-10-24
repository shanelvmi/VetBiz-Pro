// REFRESH-1 (RUNBOOK2 ledger): System Refresh, in UI Settings, reloads all
// the app's data and opens the dashboard, still signed in - with the real
// providers on the fake Firestore, driven through the dialog's own buttons.
//
// Signed in: every sign-out path in the app (forceLogoutAndShowLogin) hands
// AppEntryPoint a null user through pushAuthUser, and sets
// pendingLoginMessage when it says why; neither may happen here.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/data/fields.dart';
import 'package:vetbiz_pro/data/ui_theme_mode.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/providers/client_provider.dart';
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
import 'package:vetbiz_pro/screens/settings/ui_settings_dialog.dart';
import 'package:vetbiz_pro/ui/feedback/app_feedback.dart';
import 'package:vetbiz_pro/utils/facility_activation.dart';
import 'package:vetbiz_pro/utils/navigator_key.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

import 'helpers/fake_firestore.dart';

// Until the fix: today's refresh goes to the front door and leaves every list open.
const _skipUntilFix = true;

const _dashboard = 'DASHBOARD (stand-in)';
const _clientsScreen = 'CLIENTS SCREEN (stand-in)';

/// The server can't be reached (the phone is offline).
class _OfflineFacility extends FacilityProvider {
  _OfflineFacility(FirebaseFirestore fs) : super(firestore: fs);
  bool offline = false;

  @override
  Future<void> checkServerReachable() async {
    if (offline) throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    return super.checkServerReachable();
  }
}

/// AppEntryPoint's place at the bottom of the stack.
class _FrontDoor extends StatelessWidget {
  const _FrontDoor();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('front door'));
}

class _App {
  final FakeFirebaseFirestore fs;
  final _OfflineFacility facility;
  final ClientProvider clients;
  final UiSettingsProvider ui;
  final List<User?> pushedUsers;
  _App(this.fs, this.facility, this.clients, this.ui, this.pushedUsers);

  /// Opens the Clients list as the Clients screen does: a no-op when a
  /// session for the same filters is already open.
  Future<void> openClientsList() async {
    final signature = clients.updateClientsListFilters(
      facilityId: testFacilityId,
      searchTerm: '',
      typeFilter: 'All',
      statusFilter: 'All',
    );
    await clients.clientsListController.openSession(signature);
  }

  List<String> clientNames() => [for (final c in clients.clientsListController.items) c.name];
}

Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<_App> _signedInOnClientsScreen(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final fs = newFakeFirestore();
  await facilityDoc(fs).set({'name': 'Kilimo Agrovet', 'type': 'agrovet'});
  await fs.collection(Collections.users).doc(testUserId).set({Fields.role: 'admin'});
  await facilityCollection(fs, Collections.clients).doc('c1').set({
    'name': 'Juma',
    'nameLower': 'juma',
    'phone': '0712000000',
    'balance': 0,
    Fields.createdAt: Timestamp.fromDate(DateTime(2026, 10, 1)),
  });

  final facility = _OfflineFacility(fs);
  final clients = newClientProvider(fs);
  final ui = UiSettingsProvider();
  final debts = DebtProvider(firestore: fs);
  final role = UserRoleProvider(firestore: fs, currentUid: () => testUserId);
  final pushedUsers = <User?>[];
  pushAuthUser = pushedUsers.add;
  pendingLoginMessage = null;
  dashboardScreenBuilder = () => const Scaffold(body: Text(_dashboard));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FacilityProvider>.value(value: facility),
        ChangeNotifierProvider.value(value: clients),
        ChangeNotifierProvider.value(value: ui),
        ChangeNotifierProvider.value(value: debts),
        ChangeNotifierProvider.value(value: role),
        ChangeNotifierProvider(create: (_) => SaleProvider(firestore: fs, currentUserInfo: testUserInfo)),
        ChangeNotifierProvider(
          create: (_) => ServiceProvider(debtProvider: debts, firestore: fs, currentUserInfo: testUserInfo),
        ),
        ChangeNotifierProvider(create: (_) => TransactionProvider(firestore: fs, currentUserInfo: testUserInfo)),
        ChangeNotifierProvider(create: (_) => ProductProvider(firestore: fs, currentUserInfo: testUserInfo)),
        ChangeNotifierProvider(create: (_) => PaymentProvider(firestore: fs)),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider(firestore: fs)),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
        scaffoldMessengerKey: AppFeedback.messengerKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const _FrontDoor(),
      ),
    ),
  );
  await ui.setLayoutFixed(true);
  await ui.setThemeMode(UiThemeMode.dark);

  // Signed in to the facility, as the app does, then on to the Clients screen.
  activateFacilityAndGoToDashboard(
    context: navigatorKey.currentContext!,
    facility: {Fields.facilityId: testFacilityId, 'facilityName': 'Kilimo Agrovet', 'facilityType': 'agrovet'},
  );
  await _wait(tester);
  expect(find.text(_dashboard), findsOneWidget);
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      builder:
          (context) => Scaffold(
            body: Column(
              children: [
                const Text(_clientsScreen),
                TextButton(onPressed: () => showUiSettingsDialog(context), child: const Text('open UI Settings')),
              ],
            ),
          ),
    ),
  );
  await _wait(tester);

  final app = _App(fs, facility, clients, ui, pushedUsers);
  await app.openClientsList();
  await tester.pump();
  expect(app.clientNames(), ['Juma']);
  return app;
}

/// UI Settings, System Refresh, then Refresh in the confirmation.
Future<void> _pressSystemRefresh(WidgetTester tester) async {
  await tester.tap(find.text('open UI Settings'));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Refresh'));
  await tester.tap(find.widgetWithText(OutlinedButton, 'Refresh'));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.widgetWithText(ElevatedButton, 'Refresh'));
  await _wait(tester);
}

void main() {
  tearDown(() {
    pushAuthUser = null;
    pendingLoginMessage = null;
  });

  testWidgets(
    'a name changed elsewhere shows after a refresh; the dashboard opens; still signed in; UI settings kept',
    (tester) async {
      final app = await _signedInOnClientsScreen(tester);
      // Changed from another tab or the Firebase Console: the app is not told.
      await facilityCollection(
        app.fs,
        Collections.clients,
      ).doc('c1').update({'name': 'Juma Mpya', 'nameLower': 'juma mpya'});
      await app.openClientsList();
      expect(app.clientNames(), ['Juma'], reason: 'the open list is a snapshot until something starts it over');

      await _pressSystemRefresh(tester);

      expect(find.text(_dashboard), findsOneWidget, reason: 'the refresh opens the dashboard');
      expect(find.text(_clientsScreen), findsNothing);
      expect(find.text('Your data is up to date.'), findsOneWidget);

      // Every list starts over from the server, so the Clients screen, opened
      // again, shows the new name.
      await app.openClientsList();
      await tester.pump();
      expect(app.clientNames(), ['Juma Mpya']);

      expect(app.pushedUsers, isEmpty, reason: 'nobody is signed out');
      expect(pendingLoginMessage, isNull);
      expect(app.facility.selectedFacilityId, testFacilityId);
      expect((app.ui.layoutFixed, app.ui.themeMode), (true, UiThemeMode.dark));
    },
    skip: _skipUntilFix,
  );

  testWidgets('every list session is started over, Payments included', (tester) async {
    final app = await _signedInOnClientsScreen(tester);
    final context = navigatorKey.currentContext!;
    final payments = context.read<PaymentProvider>();
    final sales = context.read<SaleProvider>();
    final services = context.read<ServiceProvider>();
    final transactions = context.read<TransactionProvider>();
    // Each opened as its screen does.
    await app.clients.debtorsListController.openSession(
      app.clients.updateDebtorsListFilters(
        facilityId: testFacilityId,
        searchTerm: '',
        statusFilter: 'All',
        overdueRangeFilter: 'All',
        overdueDays: 30,
      ),
    );
    await sales.salesListController.openSession(
      sales.updateSalesListFilters(searchTerm: '', statusFilter: 'All', sellerFilter: 'All', dateFilter: 'All'),
    );
    await services.servicesListController.openSession(
      services.updateServicesListFilters(searchTerm: '', statusFilter: 'All', categoryFilter: 'All', dateFilter: 'All'),
    );
    await transactions.transactionsListController.openSession(
      transactions.updateTransactionsListFilters(facilityId: testFacilityId, searchTerm: '', typeFilter: null),
    );
    await payments.ledgerController.openSession(
      querySignature: payments.updateLedgerFilters(
        facilityId: testFacilityId,
        searchTerm: '',
        typeFilter: null,
        methodFilter: null,
        initialClientId: null,
      ),
      rangeStart: DateTime(2026, 10, 1),
      rangeEnd: DateTime(2026, 10, 31),
    );
    await tester.pump();
    final before = [
      app.clients.clientsListController.hasOpenSession,
      app.clients.debtorsListController.hasOpenSession,
      sales.salesListController.hasOpenSession,
      services.servicesListController.hasOpenSession,
      transactions.transactionsListController.hasOpenSession,
      payments.ledgerController.hasOpenSession,
    ];
    expect(before, everyElement(isTrue));

    await _pressSystemRefresh(tester);

    expect(app.clients.clientsListController.hasOpenSession, isFalse);
    expect(app.clients.debtorsListController.hasOpenSession, isFalse);
    expect(sales.salesListController.hasOpenSession, isFalse);
    expect(services.servicesListController.hasOpenSession, isFalse);
    expect(transactions.transactionsListController.hasOpenSession, isFalse);
    expect(payments.ledgerController.hasOpenSession, isFalse);
  }, skip: _skipUntilFix);

  testWidgets('offline: a friendly error, and the screen stays as it was', (tester) async {
    final app = await _signedInOnClientsScreen(tester);
    app.facility.offline = true;

    await _pressSystemRefresh(tester);

    expect(find.text(_clientsScreen), findsOneWidget);
    expect(find.text(_dashboard), findsNothing);
    expect(find.text("Couldn't refresh your data."), findsOneWidget);
    expect(find.text('No connection. Check your internet and try again.'), findsOneWidget);
    expect(app.clientNames(), ['Juma'], reason: 'nothing was cleared');
    expect(app.pushedUsers, isEmpty);
  }, skip: _skipUntilFix);
}
