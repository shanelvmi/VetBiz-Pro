// AUTH-1: every NEW launch starts at the login (data protection). Before, on
// web FirebaseAuth kept its default LOCAL persistence, so someone who signed
// in once opened the app straight onto Select Facility or the dashboard for
// ever; "Remember Me" only ever kept the email.
//
// The policy is tested through its seams (the marker, the restored user, the
// sign-out). The start-up sign-out then goes through the real
// forceLogoutAndShowLogin on a front door like PH3's (the real
// SignedInHomeHost and activation over the fake Firestore).
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/data/fields.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
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
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/services/session_policy.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/utils/facility_activation.dart';
import 'package:vetbiz_pro/utils/force_logout.dart';
import 'package:vetbiz_pro/utils/navigator_key.dart';
import 'package:vetbiz_pro/widgets/signed_in_home_host.dart';

import 'helpers/fake_firestore.dart';

const _skip = true;

const _dashboard = 'DASHBOARD (stand-in)';
const _login = 'LOGIN (stand-in)';

class _Marker implements SessionMarker {
  _Marker(this.isSet);
  @override
  bool isSet;
  int writes = 0;
  @override
  void set() {
    isSet = true;
    writes++;
  }
}

/// The policy with every seam recorded in [calls].
SessionPolicy _policy({required bool web, required SessionMarker marker, required bool user, required List<String> calls}) =>
    SessionPolicy(
      isWeb: web,
      marker: marker,
      setSessionPersistence: () async => calls.add('persistence'),
      restoredUserPresent: () async {
        calls.add('user?');
        return user;
      },
      signOut: () async => calls.add('signOut'),
    );

class _FakeUser extends Fake implements User {
  @override
  String get uid => testUserId;
}

class _FakeAuth extends Fake implements FirebaseAuth {
  bool signedIn = true;
  int signOuts = 0;
  @override
  User? get currentUser => signedIn ? _FakeUser() : null;
  @override
  Future<void> signOut() async {
    signOuts++;
    signedIn = false;
  }
}

class _Stack extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  @override
  void didPush(Route route, Route? previousRoute) => routes.add(route);
  @override
  void didPop(Route route, Route? previousRoute) => routes.remove(route);
  @override
  void didRemove(Route route, Route? previousRoute) => routes.remove(route);
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => routes[routes.indexOf(oldRoute!)] = newRoute!;
}

/// AppEntryPoint's part: the first route, the login when nobody is signed in.
class _FrontDoor extends StatefulWidget {
  const _FrontDoor();
  @override
  State<_FrontDoor> createState() => _FrontDoorState();
}

class _FrontDoorState extends State<_FrontDoor> {
  String? _uid = logoutAuth().currentUser?.uid;

  @override
  void initState() {
    super.initState();
    pushAuthUser = (user) => setState(() => _uid = user?.uid);
  }

  @override
  Widget build(BuildContext context) =>
      SignedInHomeHost(signedInUid: _uid, child: Scaffold(body: Text(_uid == null ? _login : 'DECIDING')));
}

Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<_Stack> _app(WidgetTester tester) async {
  final fs = newFakeFirestore();
  await facilityDoc(fs).set({'name': 'Kilimo Agrovet', 'type': 'agrovet'});
  await fs.collection(Collections.users).doc(testUserId).set({Fields.role: 'admin'});
  final debts = DebtProvider(firestore: fs);
  dashboardScreenBuilder = () => const Scaffold(body: Text(_dashboard));
  final stack = _Stack();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => FacilityProvider(firestore: fs)),
      ChangeNotifierProvider(create: (_) => newClientProvider(fs)),
      ChangeNotifierProvider(create: (_) => UiSettingsProvider()),
      ChangeNotifierProvider.value(value: debts),
      ChangeNotifierProvider(create: (_) => UserRoleProvider(firestore: fs, currentUid: () => testUserId)),
      ChangeNotifierProvider(create: (_) => SaleProvider(firestore: fs, currentUserInfo: testUserInfo)),
      ChangeNotifierProvider(
          create: (_) => ServiceProvider(debtProvider: debts, firestore: fs, currentUserInfo: testUserInfo)),
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
  ));
  return stack;
}

Future<void> _signIn(WidgetTester tester, _FakeAuth auth) async {
  auth.signedIn = true;
  pushAuthUser!(_FakeUser());
  await tester.pump();
  activateFacilityAndGoToDashboard(
    context: navigatorKey.currentContext!,
    facility: {Fields.facilityId: testFacilityId, 'facilityName': 'Kilimo Agrovet', 'facilityType': 'agrovet'},
  );
  await _wait(tester);
}

class _WrongPassword implements AuthService {
  @override
  Future<UserCredential> login(String email, String password) async =>
      throw FirebaseAuthException(code: 'wrong-password');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final sw = lookupAppLocalizations(const Locale('sw'));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MemorySessionMarker.resetForTest();
  });
  tearDown(() {
    logoutAuth = () => FirebaseAuth.instance;
    pushAuthUser = null;
    pendingLoginMessage = null;
  });

  group('the policy at start', () {
    test('web, marker missing, a user restored: signed out once, then the marker is written', () async {
      final calls = <String>[];
      final marker = _Marker(false);
      await _policy(web: true, marker: marker, user: true, calls: calls).applyAtStart();
      expect(calls.where((c) => c == 'signOut'), hasLength(1));
      expect(marker.isSet, isTrue);
    }, skip: _skip);

    test('web, marker present, a user restored (a reload): no sign-out', () async {
      final calls = <String>[];
      await _policy(web: true, marker: _Marker(true), user: true, calls: calls).applyAtStart();
      expect(calls, isNot(contains('signOut')));
    }, skip: _skip);

    test('web, marker missing, nobody restored: nothing happens, the marker is written', () async {
      final calls = <String>[];
      final marker = _Marker(false);
      await _policy(web: true, marker: marker, user: false, calls: calls).applyAtStart();
      expect(calls, isNot(contains('signOut')));
      expect(marker.writes, 1);
    }, skip: _skip);

    test('web: SESSION persistence is set first, before the restored user is looked at', () async {
      final calls = <String>[];
      await _policy(web: true, marker: _Marker(false), user: true, calls: calls).applyAtStart();
      expect(calls, ['persistence', 'user?', 'signOut']);
    }, skip: _skip);

    test('web: persistence failing still signs a leftover user out', () async {
      final calls = <String>[];
      final policy = SessionPolicy(
        isWeb: true,
        marker: _Marker(false),
        setSessionPersistence: () async => throw StateError('not supported'),
        restoredUserPresent: () async => true,
        signOut: () async => calls.add('signOut'),
      );
      await policy.applyAtStart();
      expect(calls, ['signOut']);
    }, skip: _skip);

    test('not web: every cold start signs out (in-memory flag), the same process does not again', () async {
      final calls = <String>[];
      await _policy(web: false, marker: MemorySessionMarker(), user: true, calls: calls).applyAtStart();
      expect(calls, ['user?', 'signOut'], reason: 'no persistence call off the web');
      calls.clear();
      await _policy(web: false, marker: MemorySessionMarker(), user: true, calls: calls).applyAtStart();
      expect(calls, isNot(contains('signOut')));
      MemorySessionMarker.resetForTest(); // the next cold start
      await _policy(web: false, marker: MemorySessionMarker(), user: true, calls: calls).applyAtStart();
      expect(calls, contains('signOut'));
    }, skip: _skip);

    test('main.dart applies the policy before runApp, so before AppEntryPoint listens; SESSION on web', () {
      final main = File('lib/main.dart').readAsStringSync();
      final apply = main.indexOf('.applyAtStart()');
      expect(apply, greaterThan(0));
      expect(apply, lessThan(main.indexOf('runApp(')));
      expect(apply, lessThan(main.indexOf('authStateChanges().listen')));
      final policy = File('lib/services/session_policy.dart').readAsStringSync();
      expect(policy, contains('setPersistence(Persistence.SESSION)'));
      expect(policy, contains('forceLogoutAndShowLogin'), reason: 'the one sign-out path, stack and providers cleaned');
    }, skip: _skip);
  });

  testWidgets('a leftover user: the login shows; sign in, sign out, sign in again: one route; a reload keeps it',
      (tester) async {
    final auth = _FakeAuth();
    logoutAuth = () => auth;
    final marker = _Marker(false);
    Future<void> start() => SessionPolicy(
          isWeb: true,
          marker: marker,
          setSessionPersistence: () async {},
          restoredUserPresent: () async => auth.currentUser != null,
          signOut: forceLogoutAndShowLogin,
        ).applyAtStart();

    await start();
    expect(auth.signOuts, 1);
    expect(marker.isSet, isTrue);
    final stack = await _app(tester);
    expect(find.text(_login), findsOneWidget);
    expect(find.text(_dashboard), findsNothing);

    await _signIn(tester, auth);
    expect(find.text(_dashboard), findsOneWidget);
    expect(stack.routes, hasLength(1));

    forceLogoutAndShowLogin();
    await _wait(tester);
    expect(find.text(_login), findsOneWidget);
    expect(stack.routes, hasLength(1));

    await _signIn(tester, auth);
    expect(find.text(_dashboard), findsOneWidget);
    expect(stack.routes, hasLength(1));

    await start(); // a reload in the same tab: the marker is there
    expect(auth.signOuts, 2, reason: 'only the one sign-out pressed above');
  }, skip: _skip);

  group('Remember my email', () {
    test('the checkbox says what it does', () {
      expect(en.login_rememberMe, 'Remember my email');
      expect(sw.login_rememberMe, 'Kumbuka barua pepe yangu');
    }, skip: _skip);

    testWidgets('it stores the email only: no password, no token', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: LoginScreen(authService: _WrongPassword(), firestore: newFakeFirestore()),
      ));
      await tester.pumpAndSettle();
      expect(find.text(en.login_rememberMe), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'amina@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'S3cret-pass!');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(seconds: 1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'remembered_email'});
      expect(prefs.getString('remembered_email'), 'amina@example.com');
      for (final key in prefs.getKeys()) {
        expect('${prefs.get(key)}', isNot(contains('S3cret')));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    }, skip: _skip);
  });
}
