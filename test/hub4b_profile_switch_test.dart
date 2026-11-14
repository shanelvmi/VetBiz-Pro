// HUB4b (1): Switch facility from the phone profile page goes through the
// facility picker's own activation (activateFacilityAndGoToDashboard), with
// the real providers on the fake Firestore: Home shows the new facility's
// name, RELOAD1's memory holds the new id, the profile page is gone and a
// short message confirms.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/data/fields.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/models/facility_entry.dart';
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
import 'package:vetbiz_pro/services/active_facility_memory.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/ui/feedback/app_feedback.dart';
import 'package:vetbiz_pro/utils/facility_activation.dart';
import 'package:vetbiz_pro/utils/facility_display.dart';
import 'package:vetbiz_pro/utils/navigator_key.dart';

import 'helpers/fake_firestore.dart';

const _skip = false;

const _profile = 'PROFILE PAGE (stand-in)';

Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  tearDown(() {
    ActiveFacilityMemory.store = MemorySessionStore();
    ActiveFacilityMemory.sessionStarted(sameSession: false);
  });

  testWidgets('switching updates Home\'s facility name and the remembered facility; the page closes; a message',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = MemorySessionStore();
    ActiveFacilityMemory.store = store;
    ActiveFacilityMemory.sessionStarted(sameSession: false);

    final fs = newFakeFirestore();
    await facilityDoc(fs).set({'name': 'Kilimo Agrovet', 'type': 'Agrovet'});
    await fs.collection(Collections.facilities).doc('facility2').set({'name': 'Kliniki Arusha', 'type': 'Vet Clinic'});
    await fs.collection(Collections.users).doc(testUserId).set({Fields.role: 'admin'});
    final debts = DebtProvider(firestore: fs);
    // Made before activation, as in the app (made lazily, its own load of the
    // saved facility would land after the activation's).
    final facility = FacilityProvider(firestore: fs);
    // Home stand-in: the facility name as Home's top bar shows it.
    dashboardScreenBuilder = () => Builder(
          builder: (context) => Scaffold(
            body: Text('HOME ${FacilityDisplay.name(context.watch<FacilityProvider>().selectedFacilityName)}'),
          ),
        );

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: facility),
        ChangeNotifierProvider<ClientProvider>(create: (_) => newClientProvider(fs)),
        ChangeNotifierProvider(create: (_) => UiSettingsProvider()),
        ChangeNotifierProvider.value(value: debts),
        ChangeNotifierProvider(create: (_) => UserRoleProvider(firestore: fs, currentUid: () => testUserId)),
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
        scaffoldMessengerKey: AppFeedback.messengerKey,
        theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(body: Text('front door')),
      ),
    ));

    activateFacilityAndGoToDashboard(
      context: navigatorKey.currentContext!,
      facility: {Fields.facilityId: testFacilityId, 'facilityName': 'Kilimo Agrovet', 'facilityType': 'Agrovet'},
    );
    await _wait(tester);
    expect(find.text('HOME Kilimo Agrovet'), findsOneWidget);
    expect(store.values[ActiveFacilityMemory.facilityKey], testFacilityId);

    // The profile page over Home; Switch facility picks the other one.
    navigatorKey.currentState!.push(MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => switchFacilityFromProfile(
            context,
            const FacilityEntry(id: 'facility2', name: 'Kliniki Arusha', type: 'Vet Clinic'),
            role: 'admin',
          ),
          child: const Text(_profile),
        ),
      ),
    ));
    await _wait(tester);
    await tester.tap(find.text(_profile));
    await _wait(tester);

    expect(find.text('HOME Kliniki Arusha'), findsOneWidget, reason: 'Home shows the new facility');
    expect(find.text(_profile), findsNothing, reason: 'back on Home, the page closed');
    expect(store.values[ActiveFacilityMemory.facilityKey], 'facility2', reason: 'RELOAD1 remembers it');
    expect(find.text('Switched to Kliniki Arusha'), findsOneWidget);
  }, skip: _skip);
}
