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
    );
  }
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
  Future<Widget>? _decideScreenFuture;

  Future<Widget> _decideScreenMemoized(User user) {
    if (_decidedForUid != user.uid || _decideScreenFuture == null) {
      _decidedForUid = user.uid;
      _decideScreenFuture = _decideScreen(user);
    }
    return _decideScreenFuture!;
  }

  Future<Widget> _decideScreen(User user) async {
    try {
      final uid = user.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 15));

      if (!userDoc.exists) return const LoginScreen();

      final data = userDoc.data()!;
      final role = (data['role'] ?? '').toString().toLowerCase();

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

      // Checked for every role, not just assistants - a deactivated
      // admin account was previously still able to log in freely,
      // which defeated the point of "Deactivate Account" entirely.
      final status = (data['status'] ?? 'active').toString().toLowerCase();
      if (!isPlatformAdminAccount && status == 'deactivated') {
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
      final rawFacilities = data['facilities'] as List<dynamic>? ?? [];
      final facilities = rawFacilities
          .whereType<Map>()
          .map((f) => {
                'facilityId': f['facilityId'],
                'facilityName': f['name'] ?? '',
                'facilityType': f['type'] ?? '',
              })
          .where((f) => f['facilityId'] != null)
          .toList();

      if (facilities.isEmpty) {
        // A Platform Admin with no facilities of their own (the
        // deliberate setup - a dedicated account, no shops registered
        // under it) has nowhere else to land, since the Platform Admin
        // panel normally lives inside a facility's own Settings. Sent
        // there directly instead of a dead end.
        if (isPlatformAdminAccount) {
          return const PlatformAdminHomeScreen();
        }
        return _NoFacilityScreen(role: role);
      }

      if (facilities.length == 1) {
        // Straight to Dashboard - no intermediate screen, no second
        // fetch. This is the common case for every Assistant (always
        // exactly one facility) and the majority of Admins too.
        await activateFacilityAndGoToDashboard(
          context: context,
          facility: facilities.first,
          role: role,
        );
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        Widget child;
        String key;

        // Still connecting
        if (snapshot.connectionState == ConnectionState.waiting) {
          key = 'connecting';
          child = const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // User logged out or no user - shows the block reason if
        // forceLogoutAndShowLogin() just set one (e.g. "this account
        // was deactivated"), otherwise a plain login screen (a normal
        // logout, or nobody ever signed in yet).
        else if (!snapshot.hasData) {
          final message = pendingLoginMessage;
          pendingLoginMessage = null;
          // Clear the memo so the next sign-in (even as the same
          // account) starts a genuinely fresh decision, not a stale
          // leftover result from before.
          _decidedForUid = null;
          _decideScreenFuture = null;
          key = 'login';
          child = LoginScreen(errorMessage: message);
        }
        // User logged in → decide facility/dashboard
        else {
          key = 'deciding';
          child = FutureBuilder<Widget>(
            future: _decideScreenMemoized(snapshot.data!),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError || !snap.hasData) {
                return const LoginScreen();
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
      },
    );
  }
}

/// Shown for the rare case of a signed-in account (Admin or Assistant)
/// with genuinely no facility on record at all - not a Platform Admin
/// (they're routed to the Platform Admin panel instead), just an
/// account that has nothing to show yet. Offers Logout as the only real
/// action, since there's nothing else this account can do until an
/// admin adds a facility to it.
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
