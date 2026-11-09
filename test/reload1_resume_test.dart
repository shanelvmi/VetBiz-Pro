// RELOAD1: the decision after a reload. The front door below stands in for
// AppEntryPoint (which needs a configured Firebase app), like PH3's and
// AUTH-1's: it runs the end of AppEntryPoint's decision (a remembered
// facility first, then one facility straight in, else the picker). The
// memory, the activation, the sign-out and the host are the real ones, on the
// real providers over the counting fake Firestore.
import 'dart:io';

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
import 'package:vetbiz_pro/services/active_facility_memory.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/utils/facility_activation.dart';
import 'package:vetbiz_pro/utils/force_logout.dart';
import 'package:vetbiz_pro/utils/navigator_key.dart';
import 'package:vetbiz_pro/widgets/signed_in_home_host.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/fake_firestore.dart';

const _skip = false;

const _dashboard = 'DASHBOARD (stand-in)';
const _picker = 'PICKER (stand-in)';
const _login = 'LOGIN (stand-in)';

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

class _Stack extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  @override
  void didPush(Route route, Route? previousRoute) => routes.add(route);
  @override
  void didPop(Route route, Route? previousRoute) => routes.remove(route);
  @override
  void didRemove(Route route, Route? previousRoute) => routes.remove(route);
}

int _pickerBuilds = 0;

class _Picker extends StatelessWidget {
  const _Picker();
  @override
  Widget build(BuildContext context) {
    _pickerBuilds++;
    return const Scaffold(body: Text(_picker));
  }
}

Map<String, dynamic> _facility(String id) => {Fields.facilityId: id, 'facilityName': 'Name of $id', 'facilityType': 'agrovet'};

/// AppEntryPoint's decision once the account checks passed, and nothing else.
class _FrontDoor extends StatefulWidget {
  final List<Map<String, dynamic>> facilities;
  const _FrontDoor(this.facilities);
  @override
  State<_FrontDoor> createState() => _FrontDoorState();
}

class _FrontDoorState extends State<_FrontDoor> {
  String? _uid = testUserId;
  bool _showPicker = false;

  @override
  void initState() {
    super.initState();
    pushAuthUser = (user) => setState(() => _uid = user?.uid);
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final resume = ActiveFacilityMemory.facilityToResume(widget.facilities);
    if (resume != null) {
      await activateFacilityAndGoToDashboard(context: context, facility: resume, role: 'admin', resume: true);
    } else if (widget.facilities.length == 1) {
      await activateFacilityAndGoToDashboard(context: context, facility: widget.facilities.first, role: 'admin');
    } else {
      setState(() => _showPicker = true);
    }
  }

  @override
  Widget build(BuildContext context) => SignedInHomeHost(
        signedInUid: _uid,
        child: _uid == null
            ? const Scaffold(body: Text(_login))
            : _showPicker
                ? const _Picker()
                : const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
}

Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A start of the app: [sameSession] is a reload in the same tab, [stored]
/// what the session store held before it.
Future<(_Stack, CountingFirestore, MemorySessionStore)> _start(
  WidgetTester tester, {
  required bool sameSession,
  required List<Map<String, dynamic>> facilities,
  Map<String, String> stored = const {},
}) async {
  // A new app: the previous start's providers go, or the same tree shape
  // would keep them (and their Firestore) instead of creating these.
  await tester.pumpWidget(const SizedBox());
  SharedPreferences.setMockInitialValues({});
  final fs = newFakeFirestore();
  for (final f in facilities) {
    await fs.collection(Collections.facilities).doc(f[Fields.facilityId] as String).set({'name': f['facilityName']});
  }
  await fs.collection(Collections.users).doc(testUserId).set({Fields.role: 'admin', 'defaultFacilityId': 'fac-a'});
  final db = CountingFirestore(fs);
  final store = MemorySessionStore()..values.addAll(stored);
  ActiveFacilityMemory.store = store;
  ActiveFacilityMemory.sessionStarted(sameSession: sameSession);
  final debts = DebtProvider(firestore: db);
  final auth = _FakeAuth();
  logoutAuth = () => auth;
  pendingLoginMessage = null;
  dashboardScreenBuilder = () => const Scaffold(body: Text(_dashboard));
  _pickerBuilds = 0;
  final stack = _Stack();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FacilityProvider(firestore: db)),
        ChangeNotifierProvider(create: (_) => newClientProvider(db)),
        ChangeNotifierProvider(create: (_) => UiSettingsProvider()),
        ChangeNotifierProvider.value(value: debts),
        ChangeNotifierProvider(create: (_) => UserRoleProvider(firestore: db, currentUid: () => testUserId)),
        ChangeNotifierProvider(create: (_) => SaleProvider(firestore: db, currentUserInfo: testUserInfo)),
        ChangeNotifierProvider(
          create: (_) => ServiceProvider(debtProvider: debts, firestore: db, currentUserInfo: testUserInfo),
        ),
        ChangeNotifierProvider(create: (_) => TransactionProvider(firestore: db, currentUserInfo: testUserInfo)),
        ChangeNotifierProvider(create: (_) => ProductProvider(firestore: db, currentUserInfo: testUserInfo)),
        ChangeNotifierProvider(create: (_) => PaymentProvider(firestore: db)),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider(firestore: db)),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [stack],
        theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: _FrontDoor(facilities),
      ),
    ),
  );
  await _wait(tester);
  return (stack, db, store);
}

String? _open(WidgetTester tester) =>
    Provider.of<FacilityProvider>(navigatorKey.currentContext!, listen: false).selectedFacilityId;

final _two = [_facility('fac-a'), _facility('fac-b')];

void main() {
  tearDown(() {
    logoutAuth = () => FirebaseAuth.instance;
    pushAuthUser = null;
    ActiveFacilityMemory.store = MemorySessionStore();
    ActiveFacilityMemory.sessionStarted(sameSession: false);
  });

  testWidgets('a reload with the non-default facility remembered: its dashboard, one route, the picker never built',
      (tester) async {
    final (stack, _, store) =
        await _start(tester, sameSession: true, facilities: _two, stored: {ActiveFacilityMemory.facilityKey: 'fac-b'});
    expect(find.text(_dashboard), findsOneWidget);
    expect(_open(tester), 'fac-b');
    expect(_pickerBuilds, 0);
    expect(stack.routes, hasLength(1));
    expect(store.values[ActiveFacilityMemory.facilityKey], 'fac-b');
  }, skip: _skip);

  testWidgets('a reload whose remembered facility was removed or deactivated: the picker, the memory forgotten',
      (tester) async {
    final (_, _, store) = await _start(tester,
        sameSession: true, facilities: _two, stored: {ActiveFacilityMemory.facilityKey: 'fac-removed'});
    expect(find.text(_picker), findsOneWidget);
    expect(find.text(_dashboard), findsNothing);
    expect(store.values, isEmpty);
  }, skip: _skip);

  testWidgets('two facilities and nothing remembered: the picker, as today', (tester) async {
    await _start(tester, sameSession: true, facilities: _two);
    expect(find.text(_picker), findsOneWidget);
  }, skip: _skip);

  testWidgets('a fresh sign-in keeps today\'s rules: the default facility is still picked from the picker',
      (tester) async {
    await _start(tester, sameSession: false, facilities: _two, stored: {ActiveFacilityMemory.facilityKey: 'fac-b'});
    expect(find.text(_picker), findsOneWidget);
    expect(_pickerBuilds, greaterThan(0));
  }, skip: _skip);

  testWidgets('a fresh sign-in with a single facility goes straight in, and remembers it', (tester) async {
    final (stack, _, store) = await _start(tester, sameSession: false, facilities: [_facility('fac-a')]);
    expect(find.text(_dashboard), findsOneWidget);
    expect(_open(tester), 'fac-a');
    expect(stack.routes, hasLength(1));
    expect(store.values, {ActiveFacilityMemory.facilityKey: 'fac-a'});
  }, skip: _skip);

  testWidgets('switching facility updates the memory', (tester) async {
    final (_, _, store) = await _start(tester, sameSession: false, facilities: [_facility('fac-a')]);
    activateFacilityAndGoToDashboard(context: navigatorKey.currentContext!, facility: _facility('fac-b'), role: 'admin');
    await _wait(tester);
    expect(_open(tester), 'fac-b');
    expect(store.values, {ActiveFacilityMemory.facilityKey: 'fac-b'});
  }, skip: _skip);

  testWidgets('every sign-out (forceLogoutAndShowLogin, with or without a reason) and the account decision clear it',
      (tester) async {
    for (final message in [null, 'deactivated', 'session timed out', 'account deleted']) {
      final (_, _, store) = await _start(tester, sameSession: false, facilities: [_facility('fac-a')]);
      forceLogoutAndShowLogin(message: message);
      await _wait(tester);
      expect(store.values, isEmpty, reason: 'message: $message');
    }
    final (_, _, store) = await _start(tester, sameSession: false, facilities: [_facility('fac-a')]);
    returnToAccountDecision();
    await _wait(tester);
    expect(store.values, isEmpty, reason: 'the last facility deleted: nothing is open');
  }, skip: _skip);

  testWidgets('the reload costs no new listener or read: the same as opening that facility today', (tester) async {
    final (_, today, _) = await _start(tester, sameSession: false, facilities: [_facility('fac-b')]);
    final todayCounts = [today.listeners, today.reads, today.gets];
    final (_, reload, _) =
        await _start(tester, sameSession: true, facilities: _two, stored: {ActiveFacilityMemory.facilityKey: 'fac-b'});
    expect([reload.listeners, reload.reads, reload.gets], todayCounts, reason: 'listeners, reads, gets');
  }, skip: _skip);

  test('AppEntryPoint resumes after every account check and before one-facility-or-picker; sign-outs forget', () {
    final main = File('lib/main.dart').readAsStringSync();
    final resume = main.indexOf('ActiveFacilityMemory.facilityToResume(');
    expect(resume, greaterThan(main.indexOf('entry_notActiveYet')));
    expect(resume, lessThan(main.indexOf('facilities.length == 1')));
    expect(main, contains('resume: true'));
    expect(main, contains('if (_currentUser != null && user == null) ActiveFacilityMemory.forget();'),
        reason: 'any sign-out seen by the front door forgets, a reload\'s first null does not');
    expect(File('lib/utils/force_logout.dart').readAsStringSync(), contains('ActiveFacilityMemory.forget()'));
    final policy = File('lib/services/session_policy.dart').readAsStringSync();
    expect(policy, contains('ActiveFacilityMemory.sessionStarted'));
  }, skip: _skip);
}
