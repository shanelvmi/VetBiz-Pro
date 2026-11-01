// PH3 (1) the root fix (docs/design/phone_shell.md section 1, the owner's
// answer 1): a signed-in stack holds ONLY the dashboard, and every sign-out
// path leaves ONLY the login. Before, the dashboard was pushed over
// AppEntryPoint, so Back on it uncovered the sign-in decision screen while
// still signed in.
//
// The front door below stands in for AppEntryPoint (which needs a configured
// Firebase app): like it, it is the first route, it holds a SignedInHomeHost,
// it hears sign-outs through pushAuthUser and re-decides through
// reDecideAccount. The activation, the sign-out and the host are the real
// ones, on the real providers over the fake Firestore.
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/utils/facility_activation.dart';
import 'package:vetbiz_pro/utils/force_logout.dart';
import 'package:vetbiz_pro/utils/navigator_key.dart';
import 'package:vetbiz_pro/widgets/signed_in_home_host.dart';

import 'helpers/fake_firestore.dart';

const _skip = false;

const _dashboard = 'DASHBOARD (stand-in)';
const _login = 'LOGIN (stand-in)';
const _deciding = 'DECIDING (stand-in)';

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

/// Every route on the root navigator, bottom first.
class _Stack extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  @override
  void didPush(Route route, Route? previousRoute) => routes.add(route);
  @override
  void didPop(Route route, Route? previousRoute) => routes.remove(route);
  @override
  void didRemove(Route route, Route? previousRoute) => routes.remove(route);
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    final i = routes.indexOf(oldRoute!);
    routes[i] = newRoute!;
  }
}

/// AppEntryPoint's part in this, and nothing else.
class _FrontDoor extends StatefulWidget {
  const _FrontDoor();
  @override
  State<_FrontDoor> createState() => _FrontDoorState();
}

class _FrontDoorState extends State<_FrontDoor> {
  String? _uid = testUserId;
  int decisions = 0;

  @override
  void initState() {
    super.initState();
    pushAuthUser = (user) => setState(() => _uid = user?.uid);
    reDecideAccount = () {
      clearSignedInHome?.call();
      setState(() => decisions++);
    };
  }

  @override
  Widget build(BuildContext context) => SignedInHomeHost(
        signedInUid: _uid,
        child: Scaffold(body: Text(_uid == null ? _login : _deciding)),
      );
}

Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<(_Stack, _FakeAuth)> _app(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final fs = newFakeFirestore();
  await facilityDoc(fs).set({'name': 'Kilimo Agrovet', 'type': 'agrovet'});
  await fs.collection(Collections.users).doc(testUserId).set({Fields.role: 'admin'});
  final debts = DebtProvider(firestore: fs);
  final auth = _FakeAuth();
  logoutAuth = () => auth;
  pendingLoginMessage = null;
  dashboardScreenBuilder = () => const Scaffold(body: Text(_dashboard));
  final stack = _Stack();

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
        ChangeNotifierProvider(create: (_) => ProductProvider(firestore: fs, currentUserInfo: testUserInfo)),
        ChangeNotifierProvider(create: (_) => PaymentProvider(firestore: fs)),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider(firestore: fs)),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [stack],
        theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const _FrontDoor(),
      ),
    ),
  );
  return (stack, auth);
}

Future<void> _signIn(WidgetTester tester) async {
  activateFacilityAndGoToDashboard(
    context: navigatorKey.currentContext!,
    facility: {Fields.facilityId: testFacilityId, 'facilityName': 'Kilimo Agrovet', 'facilityType': 'agrovet'},
  );
  await _wait(tester);
}

void _pushDeepScreen() => navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('a deep screen'))),
    );

void main() {
  tearDown(() {
    logoutAuth = () => FirebaseAuth.instance;
    pushAuthUser = null;
    reDecideAccount = null;
  });

  testWidgets('after sign-in the stack holds one route: the dashboard', (tester) async {
    final (stack, _) = await _app(tester);
    await _signIn(tester);
    expect(find.text(_dashboard), findsOneWidget);
    expect(stack.routes, hasLength(1));
  }, skip: _skip);

  testWidgets('opening another facility from a deep screen leaves one route', (tester) async {
    final (stack, _) = await _app(tester);
    await _signIn(tester);
    _pushDeepScreen();
    await _wait(tester);
    expect(stack.routes, hasLength(2));
    await _signIn(tester);
    expect(find.text(_dashboard), findsOneWidget);
    expect(find.text('a deep screen'), findsNothing);
    expect(stack.routes, hasLength(1));
  }, skip: _skip);

  testWidgets('signing out (every path goes through forceLogoutAndShowLogin) leaves only the login', (tester) async {
    final (stack, auth) = await _app(tester);
    await _signIn(tester);
    _pushDeepScreen();
    await _wait(tester);
    forceLogoutAndShowLogin(message: 'deactivated');
    await _wait(tester);
    expect(auth.signOuts, 1);
    expect(find.text(_login), findsOneWidget);
    expect(find.text(_dashboard), findsNothing);
    expect(stack.routes, hasLength(1));
  }, skip: _skip);

  testWidgets('signing in again after signing out shows the dashboard, one route', (tester) async {
    final (stack, _) = await _app(tester);
    await _signIn(tester);
    forceLogoutAndShowLogin();
    await _wait(tester);
    pushAuthUser!(_FakeUser());
    await tester.pump();
    expect(find.text(_deciding), findsOneWidget, reason: 'the front door decides afresh, the old home is gone');
    await _signIn(tester);
    expect(find.text(_dashboard), findsOneWidget);
    expect(stack.routes, hasLength(1));
  }, skip: _skip);

  testWidgets('back to the front door (returnToAccountDecision) drops the home, one route', (tester) async {
    final (stack, _) = await _app(tester);
    await _signIn(tester);
    _pushDeepScreen();
    await _wait(tester);
    returnToAccountDecision();
    await _wait(tester);
    expect(find.text(_deciding), findsOneWidget);
    expect(find.text(_dashboard), findsNothing);
    expect(stack.routes, hasLength(1));
  }, skip: _skip);

  testWidgets('Back on Home leaves the app as the platform does (nothing left to pop)', (tester) async {
    final (stack, _) = await _app(tester);
    await _signIn(tester);
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.binding.handlePopRoute();
    await _wait(tester);
    expect(calls, contains('SystemNavigator.pop'), reason: 'the platform closes the app, or the browser leaves the page');
    expect(find.text(_deciding), findsNothing, reason: 'never the sign-in decision screen while signed in');
    expect(stack.routes, hasLength(1));
  }, skip: _skip);

  test('no sign-in or sign-out path replaces the front door with a route of its own', () {
    String read(String path) => File(path).readAsStringSync();
    expect(read('lib/screens/settings/manage_account_screen.dart'), isNot(contains("'/login'")),
        reason: 'Log out everywhere goes through forceLogoutAndShowLogin');
    expect(read('lib/screens/dashboard/dashboard_screen.dart'), isNot(contains("'/login'")),
        reason: 'the dashboard never replaces the front door with a login of its own');
    expect(read('lib/screens/register_screen.dart'), isNot(contains("'/dashboard'")),
        reason: 'saving Edit Profile closes it instead of pushing a second dashboard');
    expect(read('lib/main.dart'), contains('SignedInHomeHost('));
  }, skip: _skip);
}
