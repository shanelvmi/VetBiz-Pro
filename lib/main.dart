import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/facilities/facility_picker_screen.dart';
import 'screens/platform_admin/platform_admin_home_screen.dart';
import 'utils/facility_activation.dart';
import 'utils/activity_signal.dart';
import 'utils/presence_heartbeat.dart';
import 'widgets/maintenance_gate.dart';

import 'services/auth_service.dart';

import 'providers/product_provider.dart';
import 'providers/client_provider.dart';
import 'providers/service_provider.dart';
import 'providers/sale_provider.dart';
import 'providers/transaction_provider.dart';
import 'utils/navigator_key.dart';
import 'utils/force_logout.dart';
import 'providers/facility_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/user_role_provider.dart';
import 'providers/debt_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DebtProvider()),
        ChangeNotifierProvider(
          create: (context) => ServiceProvider(
            debtProvider: Provider.of<DebtProvider>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider(create: (_) => SaleProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => ClientProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => FacilityProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => UserRoleProvider()),
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: const VetBizProApp(),
    ),
  );
}

class VetBizProApp extends StatelessWidget {
  const VetBizProApp({super.key});

  // Brand colors, defined once here so the WHOLE app's theme - text field
  // focus borders, the blinking cursor, date picker selections - uses them
  // automatically, instead of every screen needing to remember to override
  // Flutter's default blue individually.
  static const Color primaryDeepGreen = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);
  static const Color offWhite = Color(0xFFFDFDF9);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryDeepGreen,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryDeepGreen,
      secondary: warmAmber,
      surface: offWhite,
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'VetBiz Pro',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: offWhite,
        // The blinking text cursor and the highlighted selection in every
        // text field, app-wide.
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: primaryDeepGreen,
          selectionColor: primaryDeepGreen.withValues(alpha: 0.3),
          selectionHandleColor: primaryDeepGreen,
        ),
        // The outline/underline every text field shows once focused
        // (tapped into), app-wide.
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: primaryDeepGreen, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          floatingLabelStyle: const TextStyle(color: primaryDeepGreen),
        ),
        // The calendar shown by every showDatePicker call, app-wide (header,
        // selected day, "today" outline).
        datePickerTheme: DatePickerThemeData(
          headerBackgroundColor: primaryDeepGreen,
          headerForegroundColor: offWhite,
          todayBorder: const BorderSide(color: primaryDeepGreen),
          todayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return offWhite;
            return primaryDeepGreen;
          }),
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return offWhite;
            return null;
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primaryDeepGreen;
            return null;
          }),
          confirmButtonStyle: TextButton.styleFrom(foregroundColor: primaryDeepGreen),
          cancelButtonStyle: TextButton.styleFrom(foregroundColor: primaryDeepGreen),
        ),
        // Buttons that don't explicitly set their own colors fall back to
        // these, instead of Material's default blue.
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primaryDeepGreen),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryDeepGreen,
            foregroundColor: offWhite,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
      home: const AppEntryPoint(),
      // Wraps the whole app, including every dialog and overlay -
      // this is the one place pointer activity can be caught
      // app-wide, rather than each screen needing (and likely
      // forgetting) its own Listener that would miss activity inside
      // any dialog rendered above it. See activity_signal.dart.
      builder: (context, child) {
        return Listener(
          onPointerDown: (_) => globalActivitySignal.add(null),
          onPointerSignal: (_) => globalActivitySignal.add(null),
          behavior: HitTestBehavior.translucent,
          child: MaintenanceGate(child: child!),
        );
      },
    );
  }
}

// Extracted so both the initial read and any retry read (see
// _decideScreen's empty-facilities handling below) share the exact
// same parsing logic, rather than duplicating it.
List<Map<String, dynamic>> _parseFacilities(Map<String, dynamic>? data) {
  final raw = (data?['facilities'] as List<dynamic>?) ?? [];
  return raw
      .whereType<Map>()
      .map((f) => {
            'facilityId': f['facilityId'],
            'facilityName': f['name'] ?? '',
            'facilityType': f['type'] ?? '',
          })
      .where((f) => f['facilityId'] != null)
      .toList();
}

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  // Memoized so a rebuild - including the extra ones AnimatedSwitcher
  // triggers mid-animation - never restarts this from scratch. Calling
  // _decideScreen(user) directly inline as FutureBuilder's `future:`
  // creates a brand-new Future on every single rebuild, which resets
  // FutureBuilder back to "waiting" each time - if rebuilds happen
  // faster than this can complete, it can never actually finish,
  // which looks exactly like an endless spinner/circling login.
  String? _decidedForUid;
  String? _heartbeatStartedForUid;
  Future<Widget>? _decideScreenFuture;

  // Tracked manually rather than via StreamBuilder<User?> - a known,
  // documented Flutter-web limitation can leave authStateChanges()
  // failing to emit at all on a sign-in/sign-out transition (most
  // reports describe it happening after a hot restart, but also
  // occasionally during ordinary account switching). _authPollTimer
  // below is the actual fix for that: a periodic check against the
  // always-accurate, synchronous currentUser getter, which
  // self-corrects within a couple of seconds if the stream ever falls
  // out of sync with it - rather than relying solely on a stream that
  // can, in practice, occasionally just stop talking.
  User? _currentUser;
  bool _authInitialized = false;
  StreamSubscription<User?>? _authSubscription;
  Timer? _authPollTimer;

  @override
  void initState() {
    super.initState();
    // Known synchronously and immediately, rather than waiting for the
    // stream's first event - avoids an unnecessary "connecting" flash
    // for someone already signed in from a previous session.
    _currentUser = FirebaseAuth.instance.currentUser;
    _authInitialized = _currentUser != null;
    debugPrint('[AUTH] AppEntryPoint mounted - currentUser=${_currentUser?.uid ?? "none"}');

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      debugPrint('[AUTH] authStateChanges() emitted uid=${user?.uid ?? "null"}');
      _updateAuthUser(user);
    }, onError: (Object e, StackTrace st) {
      debugPrint('[AUTH] authStateChanges() stream error: $e');
    });

    _authPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateAuthUser(FirebaseAuth.instance.currentUser);
    });

    // The direct fix - LoginScreen calls this the instant its own
    // sign-in call succeeds, rather than this widget only ever finding
    // out via the stream or waiting up to 2 seconds for the next poll.
    pushAuthUser = (user) {
      debugPrint('[AUTH] Direct push received for uid=${user.uid}');
      _updateAuthUser(user);
    };
  }

  @override
  void dispose() {
    debugPrint('[AUTH] AppEntryPoint disposing - cancelling subscription/timer, clearing push callback');
    _authSubscription?.cancel();
    _authPollTimer?.cancel();
    // Cleared, not left pointing at a widget that's about to be gone -
    // if LoginScreen somehow called this after disposal, it would be
    // acting on a State object that's no longer valid.
    if (pushAuthUser != null) pushAuthUser = null;
    super.dispose();
  }

  void _updateAuthUser(User? user) {
    if (!mounted) {
      debugPrint('[AUTH] _updateAuthUser(${user?.uid ?? "null"}) called after dispose - ignored');
      return;
    }
    final changed = user?.uid != _currentUser?.uid;
    if (!_authInitialized || changed) {
      debugPrint('[AUTH] Updating auth state: '
          '${_currentUser?.uid ?? "none"} -> ${user?.uid ?? "none"} (was initialized=$_authInitialized)');
      setState(() {
        _currentUser = user;
        _authInitialized = true;
      });
    } else {
      debugPrint('[AUTH] _updateAuthUser(${user?.uid ?? "null"}) - no change, ignored');
    }
  }

  Future<Widget> _decideScreenMemoized(User user) {
    if (_decidedForUid != user.uid || _decideScreenFuture == null) {
      debugPrint('[AUTH] _decideScreenMemoized: starting a fresh decision for uid=${user.uid} '
          '(previously decided for=${_decidedForUid ?? "none"})');
      _decidedForUid = user.uid;
      // A defensive outer bound on the whole decision process, not
      // just the individual reads inside it - regardless of what
      // specifically causes this to hang (a rule denial that doesn't
      // resolve cleanly, a network condition the inner .timeout()
      // calls don't catch, anything not yet anticipated), this
      // guarantees it can never spin forever with no way out.
      _decideScreenFuture = _decideScreen(user).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Could not load your account in time.'),
      );
    } else {
      debugPrint('[AUTH] _decideScreenMemoized: reusing existing decision for uid=${user.uid}');
    }
    return _decideScreenFuture!;
  }

  Future<Widget> _decideScreen(User user) async {
    try {
      final uid = user.uid;
      debugPrint('[AUTH] _decideScreen starting for uid=$uid');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 15));
      debugPrint('[AUTH] users/$uid read complete - exists=${userDoc.exists}');

      if (!userDoc.exists) {
        debugPrint('[AUTH] users/$uid does not exist - showing LoginScreen');
        return const LoginScreen();
      }

      final data = userDoc.data()!;
      final role = (data['role'] ?? '').toString().toLowerCase();
      debugPrint('[AUTH] role=$role status=${data['status']} facilities=${data['facilities']}');

      // Platform Admins are exempt from the deactivation check entirely
      // - checked first, before status, as a backup to the rules-level
      // protection (which stops this from being written in the first
      // place) in case any pre-existing account somehow already has
      // status: deactivated set.
      final platformAdminDoc = await FirebaseFirestore.instance
          .collection('platform_admins')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));
      final isPlatformAdminAccount = platformAdminDoc.exists;
      debugPrint('[AUTH] platform_admins/$uid read complete - isPlatformAdminAccount=$isPlatformAdminAccount');

      // Checked for every role, not just assistants - a deactivated
      // admin account was previously still able to log in freely,
      // which defeated the point of "Deactivate Account" entirely.
      final status = (data['status'] ?? 'active').toString().toLowerCase();
      if (!isPlatformAdminAccount && status == 'deactivated') {
        debugPrint('[AUTH] blocked - deactivated, non-platform-admin account');
        // Not returned as this Future's result - signing out fires its
        // own auth-state change, which can discard this exact
        // FutureBuilder before its return value is ever used. Explicit,
        // independent navigation (via the global key) sidesteps that
        // race entirely, instead of hoping the return value survives.
        forceLogoutAndShowLogin(
          message: 'This account has been deactivated. Ask your facility admin '
              '(or Platform Admin) to reactivate it before signing in again.',
        );
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!isPlatformAdminAccount && role == 'assistant' && status != 'active') {
        debugPrint('[AUTH] blocked - assistant not yet active');
        forceLogoutAndShowLogin(
          message: 'Your account is not active yet. Please wait for admin approval.',
        );
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      // Parsed directly from the same read above - never fetched a
      // second time by a separate screen. That second, independent
      // fetch (in the old SelectFacilityScreen flow) was the actual
      // cause of "second login just spins" - a duplicate read with its
      // own separate failure point, on top of this one.
      var facilities = _parseFacilities(data);
      debugPrint('[AUTH] parsed facilities count=${facilities.length}');

      // Registration triggers sign-in (and this very check) before its
      // own, separate facility-creation sequence has necessarily
      // finished writing to this same document - a real race, not a
      // hypothetical one. A short, bounded retry gives that sequence a
      // real chance to finish before concluding "no facility" at all.
      // Skipped for a Platform Admin specifically - having none of
      // their own is a deliberate, stable setup for that account type,
      // not a race, so waiting here could never change the outcome.
      if (facilities.isEmpty && !isPlatformAdminAccount) {
        debugPrint('[AUTH] facilities empty, not a platform admin - starting retry loop');
        for (var attempt = 0; attempt < 4 && facilities.isEmpty; attempt++) {
          await Future.delayed(const Duration(milliseconds: 800));
          final retryDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get()
              .timeout(const Duration(seconds: 10));
          facilities = _parseFacilities(retryDoc.data());
        }
      }

      if (facilities.isEmpty) {
        // A Platform Admin with no facilities of their own (the
        // deliberate setup - a dedicated account, no shops registered
        // under it) has nowhere else to land, since the Platform Admin
        // panel normally lives inside a facility's own Settings. Sent
        // there directly instead of a dead end.
        if (isPlatformAdminAccount) {
          debugPrint('[AUTH] returning PlatformAdminHomeScreen (no facilities, is platform admin)');
          return const PlatformAdminHomeScreen();
        }
        debugPrint('[AUTH] returning _NoFacilityScreen (no facilities, not a platform admin)');
        return _NoFacilityScreen(role: role);
      }

      if (facilities.length == 1) {
        // Straight to Dashboard - no intermediate screen, no second
        // fetch. This is the common case for every Assistant (always
        // exactly one facility) and the majority of Admins too.
        debugPrint('[AUTH] Single facility - calling activateFacilityAndGoToDashboard for uid=$uid');
        await activateFacilityAndGoToDashboard(
          context: context,
          facility: facilities.first,
          role: role,
        );
        debugPrint('[AUTH] activateFacilityAndGoToDashboard call returned for uid=$uid');
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      // More than one facility - only realistically happens for an
      // Admin managing several. Handed the list directly; the picker
      // does no fetching of its own.
      return FacilityPickerScreen(facilities: facilities, role: role);
    } catch (e) {
      // Whatever went wrong - a timeout, a permission error, anything -
      // this always resolves to a real screen with a real message,
      // never leaves the FutureBuilder hanging on its loading spinner
      // indefinitely. No sign-out happens on this path, so there's no
      // race to worry about - a direct return is fine here.
      debugPrint('Error deciding screen: $e');
      return LoginScreen(
        errorMessage: e is TimeoutException
            ? 'This is taking longer than expected. Check your connection and try again.'
            : 'Something went wrong signing you in: $e',
      );
    }
  }

  void _syncHeartbeat(String? uid) {
    if (uid == _heartbeatStartedForUid) return;
    _heartbeatStartedForUid = uid;
    if (uid != null) {
      PresenceHeartbeat.start();
    } else {
      PresenceHeartbeat.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncHeartbeat(_currentUser?.uid);

    Widget child;
    String key;

    // Still waiting for the very first known auth state.
    if (!_authInitialized) {
      key = 'connecting';
      child = const _AuthLoadingScreen();
    }
    // User logged out or no user - shows the block reason if
    // forceLogoutAndShowLogin() just set one (e.g. "this account
    // was deactivated"), otherwise a plain login screen (a normal
    // logout, or nobody ever signed in yet).
    else if (_currentUser == null) {
      final message = pendingLoginMessage;
      pendingLoginMessage = null;
      // Clear the memo so the next sign-in (even as the same
      // account) starts a genuinely fresh decision, not a stale
      // leftover result from before.
      if (_decidedForUid != null) {
        debugPrint('[AUTH] Clearing decision memo (was for uid=$_decidedForUid) - showing login screen');
      }
      _decidedForUid = null;
      _decideScreenFuture = null;
      key = 'login';
      child = LoginScreen(errorMessage: message);
    }
    // User logged in → decide facility/dashboard
    else {
      key = 'deciding';
      child = FutureBuilder<Widget>(
        future: _decideScreenMemoized(_currentUser!),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError || !snap.hasData) {
            return _DecisionErrorScreen(
              onRetry: () {
                setState(() {
                  _decidedForUid = null;
                  _decideScreenFuture = null;
                });
              },
            );
          }
          return snap.data!;
        },
      );
    }

        // A plain fade rather than any sliding/scaling motion - this is
        // specifically about smoothing the loading-spinner-to-login-
        // screen-with-error transition, not adding a flashy animation.
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: KeyedSubtree(key: ValueKey(key), child: child),
        );
  }
}

/// Shown for the rare case of a signed-in account (Admin or Assistant)
/// with genuinely no facility on record at all - not a Platform Admin
/// (they're routed to the Platform Admin panel instead), just an
/// account that has nothing to show yet. Offers Logout as the only real
/// action, since there's nothing else this account can do until an
/// admin adds a facility to it.
/// Shown while waiting for Firebase to report the current sign-in
/// state. Normally resolves in well under a second. A known
/// Flutter-web plugin limitation can occasionally leave
/// authStateChanges() never emitting at all - no error, no timeout of
/// its own, just silence - most commonly after a hot restart during
/// development, but also occasionally during ordinary use. Rather than
/// leave someone staring at an unexplained spinner forever, a real way
/// out appears after a reasonable wait.
class _AuthLoadingScreen extends StatefulWidget {
  const _AuthLoadingScreen();

  @override
  State<_AuthLoadingScreen> createState() => _AuthLoadingScreenState();
}

class _AuthLoadingScreenState extends State<_AuthLoadingScreen> {
  bool _showRecovery = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _showRecovery = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDF9),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (_showRecovery) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Taking longer than expected to load.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                // The same explicit, navigatorKey-based navigation this
                // app already relies on elsewhere for stuck-state
                // recovery - it doesn't depend on the auth stream
                // itself reacting, so it works regardless of whether
                // that's the thing currently stuck.
                onPressed: () => forceLogoutAndShowLogin(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown if the decision process itself fails or times out, for any
/// reason - a genuine retry (clearing the memoized future so a fresh
/// attempt actually re-reads everything, not just re-displaying the
/// same failure) rather than silently dropping back to a login form
/// while the person is still actually signed in.
class _DecisionErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _DecisionErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDF9),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Could Not Load Your Account',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 8),
              Text(
                'Something went wrong while loading your account details. '
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => forceLogoutAndShowLogin(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoFacilityScreen extends StatelessWidget {
  final String? role;
  const _NoFacilityScreen({this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDF9),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No Facility Assigned', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 8),
              Text(
                role == 'assistant'
                    ? 'Your account isn\'t linked to a facility yet. Ask your admin to add you to one.'
                    : 'This account has no facility on record. Register one, or ask your Platform Admin for help.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => forceLogoutAndShowLogin(),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
