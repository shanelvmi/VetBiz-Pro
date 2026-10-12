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
import 'l10n/l10n.dart';

import 'services/auth_service.dart';
import 'services/membership_service.dart';
import 'constants/facility_types.dart';

import 'providers/product_provider.dart';
import 'providers/client_provider.dart';
import 'providers/service_provider.dart';
import 'providers/sale_provider.dart';
import 'providers/transaction_provider.dart';
import 'utils/navigator_key.dart';
import 'utils/force_logout.dart';
import 'providers/facility_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/ui_settings_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/user_role_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/payment_provider.dart';
import 'widgets/vetbiz_loading_indicator.dart';
import 'theme/app_palette.dart';
import 'theme/app_theme.dart';
import 'data/collections.dart';
import 'data/fields.dart';
import 'data/user_role.dart';
import 'data/user_status.dart';
import 'config/app_limits.dart';
import 'config/app_timeouts.dart';
import 'config/app_rules.dart';
import 'config/app_info.dart';
import 'ui/feedback/app_feedback.dart';
import 'theme/app_text.dart';
import 'theme/app_dimens.dart';
import 'theme/theme_context.dart';
import 'theme/app_motion.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DebtProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
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
        ChangeNotifierProvider(create: (_) => UiSettingsProvider()),
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

  // The brand colours, kept here as names for the default theme (the widget
  // test checks they still come from AppPalette). The theme itself is built
  // by AppTheme.build, from the colour theme chosen in UI Settings.
  static const Color primaryDeepGreen = AppPalette.primary;
  static const Color warmAmber = AppPalette.accent;
  static const Color offWhite = AppPalette.background;

  @override
  Widget build(BuildContext context) {
    // Watched so a colour-theme or language change in Settings rebuilds the app.
    final uiSettings = context.watch<UiSettingsProvider>();
    final colorTheme = uiSettings.colorTheme;

    return MaterialApp(
      navigatorKey: navigatorKey,
      // Lets AppFeedback show messages without a BuildContext (after an
      // await, or after the screen that asked is gone).
      scaffoldMessengerKey: AppFeedback.messengerKey,
      title: AppInfo.name,
      theme: AppTheme.build(colorTheme, Brightness.light),
      debugShowCheckedModeBanner: false,
      // Our texts plus Flutter's own (date picker, OK/Cancel, tooltips).
      // Dates and amounts we format ourselves stay fixed (AppDateFormat, Money).
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: uiSettings.locale,
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
            Fields.facilityId: f[Fields.facilityId],
            'facilityName': f['name'] ?? '',
            'facilityType': f['type'] ?? '',
          })
      .where((f) => f[Fields.facilityId] != null)
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

    _authPollTimer = Timer.periodic(AppTimeouts.authPoll, (_) {
      _updateAuthUser(FirebaseAuth.instance.currentUser);
    });

    // The direct fix - LoginScreen calls this the instant its own
    // sign-in call succeeds, rather than this widget only ever finding
    // out via the stream or waiting up to 2 seconds for the next poll.
    pushAuthUser = (user) {
      debugPrint('[AUTH] Direct push received for uid=${user?.uid ?? "null"}');
      _updateAuthUser(user);
    };

    // See reDecideAccount in navigator_key.dart.
    reDecideAccount = () {
      if (!mounted) return;
      debugPrint('[AUTH] Asked to decide afresh for uid=${_currentUser?.uid ?? "none"}');
      setState(() {
        _decidedForUid = null;
        _decideScreenFuture = null;
      });
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
    if (reDecideAccount != null) reDecideAccount = null;
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
        AppTimeouts.decideFirstScreen,
        onTimeout: () => throw TimeoutException('Could not load your account in time.'),
      );
    } else {
      debugPrint('[AUTH] _decideScreenMemoized: reusing existing decision for uid=${user.uid}');
    }
    return _decideScreenFuture!;
  }

  // Firestore's web SDK has a known cold-start race: the very first
  // query issued right after a fresh page load can spuriously report
  // itself as "unavailable"/offline before the underlying connection
  // has actually finished establishing - even though the identical
  // query succeeds moments later with nothing else changed. A plain
  // browser reload already proved this resolves itself; this retries
  // the same way automatically instead of leaving someone to
  // rediscover that fix by hand.
  Future<DocumentSnapshot<Map<String, dynamic>>> _getWithRetry(
    DocumentReference<Map<String, dynamic>> ref, {
    required Duration timeout,
    int maxAttempts = 3,
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await ref.get().timeout(timeout);
      } on FirebaseException catch (e) {
        final isLastAttempt = attempt == maxAttempts;
        if (e.code != 'unavailable' || isLastAttempt) rethrow;
        debugPrint('[AUTH] ${ref.path} attempt $attempt hit "unavailable" - retrying');
        await Future.delayed(AppTimeouts.unavailableRetryStep * attempt);
      }
    }
    // Unreachable - the loop above always either returns or rethrows.
    throw StateError('_getWithRetry exhausted attempts without returning or rethrowing');
  }

  Future<Widget> _decideScreen(User user) async {
    try {
      final uid = user.uid;
      debugPrint('[AUTH] _decideScreen starting for uid=$uid');

      var userDoc = await _getWithRetry(
        FirebaseFirestore.instance.collection(Collections.users).doc(uid),
        timeout: AppTimeouts.profileRead,
      );
      debugPrint('[AUTH] users/$uid read complete - exists=${userDoc.exists}');

      // A profile that isn't there yet gets a short second look before
      // concluding it never will be.
      for (var attempt = 0; attempt < 2 && !userDoc.exists; attempt++) {
        await Future.delayed(AppTimeouts.profileRecheckDelay);
        userDoc = await _getWithRetry(
          FirebaseFirestore.instance.collection(Collections.users).doc(uid),
          timeout: AppTimeouts.profileRecheck,
        );
        debugPrint('[AUTH] users/$uid re-checked - exists=${userDoc.exists}');
      }

      if (!userDoc.exists) {
        // A sign-in that has no profile behind it: registration stopped part
        // way (the account was made, the profile never was), or the profile
        // was removed. This used to return a bare LoginScreen WITHOUT signing
        // out and WITHOUT a word. Two things made that a trap:
        //  - the person stayed signed in, so signing in again pushed the same
        //    user, which _updateAuthUser ignores as "no change"; and
        //  - this decision is memoized per user, so the same answer was
        //    reused every time.
        // Every further attempt then just spun for six seconds and bounced
        // back, silently, until the page was reloaded. Signing out clears
        // both, and the message says what's actually wrong.
        debugPrint('[AUTH] users/$uid does not exist - signing out with a message');
        forceLogoutAndShowLogin(
          message: L10n.current.entry_noProfile,
        );
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final data = userDoc.data()!;
      final role = (data[Fields.role] ?? '').toString().toLowerCase();
      debugPrint('[AUTH] role=$role status=${data[Fields.status]} facilities=${data['facilities']}');

      // Platform Admins are exempt from the deactivation check entirely
      // - checked first, before status, as a backup to the rules-level
      // protection (which stops this from being written in the first
      // place) in case any pre-existing account somehow already has
      // status: deactivated set.
      final platformAdminDoc = await _getWithRetry(
        FirebaseFirestore.instance.collection(Collections.platformAdmins).doc(uid),
        timeout: AppTimeouts.platformAdminRead,
      );
      final isPlatformAdminAccount = platformAdminDoc.exists;
      debugPrint('[AUTH] platform_admins/$uid read complete - isPlatformAdminAccount=$isPlatformAdminAccount');

      // Checked for every role, not just assistants - a deactivated
      // admin account was previously still able to log in freely,
      // which defeated the point of "Deactivate Account" entirely.
      final status = (data[Fields.status] ?? UserStatus.active.key).toString().toLowerCase();

      // An assistant who is in NO facility - removed from theirs - has nothing
      // left to be blocked from: every rule that opens data checks facility
      // membership, and they have none. Blocking them on "deactivated" was a
      // dead end, because removal leaves their status alone and their old
      // admin can no longer see them to reactivate them. They get through to
      // the screen that lets them join another facility with an invite code.
      final facilitiesOnRecord = _parseFacilities(data);
      final removedAssistant = role == UserRole.assistant.key && facilitiesOnRecord.isEmpty;

      if (!isPlatformAdminAccount && !removedAssistant && status == UserStatus.deactivated.key) {
        debugPrint('[AUTH] blocked - deactivated, non-platform-admin account');
        // Not returned as this Future's result - signing out fires its
        // own auth-state change, which can discard this exact
        // FutureBuilder before its return value is ever used. Explicit,
        // independent navigation (via the global key) sidesteps that
        // race entirely, instead of hoping the return value survives.
        forceLogoutAndShowLogin(
          message: L10n.current.entry_deactivated,
        );
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!isPlatformAdminAccount && !removedAssistant && role == UserRole.assistant.key && status != UserStatus.active.key) {
        debugPrint('[AUTH] blocked - assistant not yet active');
        forceLogoutAndShowLogin(
          message: L10n.current.entry_notActiveYet,
        );
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      // Parsed directly from the same read above - never fetched a
      // second time by a separate screen. That second, independent
      // fetch (in the old SelectFacilityScreen flow) was the actual
      // cause of "second login just spins" - a duplicate read with its
      // own separate failure point, on top of this one.
      var facilities = facilitiesOnRecord;
      debugPrint('[AUTH] parsed facilities count=${facilities.length}');

      // Registration triggers sign-in (and this very check) before its
      // own, separate facility-creation sequence has necessarily
      // finished writing to this same document - a real race, not a
      // hypothetical one. A short, bounded retry gives that sequence a
      // real chance to finish before concluding "no facility" at all.
      // Skipped for a Platform Admin specifically - having none of
      // their own is a deliberate, stable setup for that account type,
      // not a race, so waiting here could never change the outcome.
      // (Not when the account's lists are WRITTEN and empty - which is what
      // registration, removal and deleting a facility all leave: that means
      // "none", not "still being written". Registration now creates the
      // profile and its facilities together, so this only still guards a
      // profile that has no lists at all.)
      final facilityListsWritten = data['facilities'] is List && data['facilityIds'] is List;
      if (facilities.isEmpty && !isPlatformAdminAccount && !removedAssistant && !facilityListsWritten) {
        debugPrint('[AUTH] facilities empty, not a platform admin - starting retry loop');
        for (var attempt = 0; attempt < 4 && facilities.isEmpty; attempt++) {
          await Future.delayed(AppTimeouts.facilityListRetryDelay);
          final retryDoc = await _getWithRetry(
            FirebaseFirestore.instance.collection(Collections.users).doc(uid),
            timeout: AppTimeouts.facilityListRetry,
          );
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
        // An assistant who was REJECTED is told so, and by which facility - then
        // offered the invite-code box like anyone else with no facility.
        String? notice;
        final rejection = data['lastRejection'];
        if (role == UserRole.assistant.key && rejection is Map) {
          final from = (rejection['facilityName'] ?? '').toString().trim();
          notice = from.isEmpty ? L10n.current.entry_requestNotApproved : L10n.current.entry_requestNotApprovedFrom(from);
        }
        return _NoFacilityScreen(role: role, notice: notice);
      }

      if (facilities.length == 1) {
        // Straight to Dashboard - no intermediate screen, no second
        // fetch. This is the common case for every Assistant (always
        // exactly one facility) and the majority of Admins too.
        debugPrint('[AUTH] Single facility - calling activateFacilityAndGoToDashboard for uid=$uid');
        // Only while this screen is still mounted: the helper aborts in that
        // case anyway, and this context must not be used across the reads above.
        if (mounted) {
          await activateFacilityAndGoToDashboard(
            context: context,
            facility: facilities.first,
            role: role,
          );
        }
        debugPrint('[AUTH] activateFacilityAndGoToDashboard call returned for uid=$uid');
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      // More than one facility - only realistically happens for an
      // Admin managing several. Handed the list directly; the picker
      // does no fetching of its own.
      return FacilityPickerScreen(facilities: facilities, role: role);
    } catch (e) {
      // Whatever went wrong - a timeout, a connection blip, a refused read -
      // it must end on a screen that can RECOVER. This used to return a
      // LoginScreen while the person was still signed in, and that was a dead
      // end: the failed answer was memoized for this user, and signing in
      // again pushes the same user, which is ignored as "no change". So ONE
      // hiccup (a dropped connection while the account was loading) meant
      // every later attempt spun for six seconds and bounced back silently,
      // even once the connection was fine, until the page was reloaded.
      //
      // Rethrowing hands it to the FutureBuilder, which shows
      // _DecisionErrorScreen: Try Again (clears the memo and decides afresh)
      // or Logout. That screen already existed - this path just never reached
      // it.
      debugPrint('Error deciding screen: $e');
      rethrow;
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
          Widget inner;
          String innerKey;
          if (snap.connectionState == ConnectionState.waiting) {
            innerKey = 'spinner';
            inner = const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snap.hasError || !snap.hasData) {
            innerKey = 'error';
            inner = _DecisionErrorScreen(
              error: snap.error,
              onRetry: () {
                setState(() {
                  _decidedForUid = null;
                  _decideScreenFuture = null;
                });
              },
            );
          } else {
            innerKey = 'resolved';
            inner = snap.data!;
          }
          return AnimatedSwitcher(
            duration: AppMotion.normal,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(key: ValueKey(innerKey), child: inner),
          );
        },
      );
    }

        // A plain fade rather than any sliding/scaling motion - this is
        // specifically about smoothing the loading-spinner-to-login-
        // screen-with-error transition, not adding a flashy animation.
        return AnimatedSwitcher(
          duration: AppMotion.normal,
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
    _timer = Timer(AppTimeouts.startupRecoveryOffer, () {
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
      backgroundColor: VetBizLoadingIndicator.backgroundColor,
      body: SafeArea(
        child: VetBizLoadingIndicator(
          style: VetBizLoadingStyle.full,
          recoveryAction: _showRecovery
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
                      child: Text(
                        context.l10n.entry_slowLoad,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.textSoft),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    OutlinedButton.icon(
                      // The same explicit, navigatorKey-based navigation this
                      // app already relies on elsewhere for stuck-state
                      // recovery - it doesn't depend on the auth stream
                      // itself reacting, so it works regardless of whether
                      // that's the thing currently stuck.
                      onPressed: () => forceLogoutAndShowLogin(),
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.common_tryAgain),
                    ),
                  ],
                )
              : null,
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
  final Object? error;
  const _DecisionErrorScreen({required this.onRetry, this.error});

  // Plain words for what went wrong, and a short technical tag underneath so
  // it can be reported accurately.
  String _explanation(AppLocalizations l10n) {
    final e = error;
    if (e is TimeoutException) {
      return l10n.entry_timeoutExplanation;
    }
    if (e is FirebaseException) {
      if (e.code == 'unavailable') {
        return l10n.entry_unreachable;
      }
      if (e.code == 'permission-denied') {
        return l10n.entry_accessRefused;
      }
    }
    return l10n.entry_loadFailed;
  }

  String? get _tag {
    final e = error;
    if (e is FirebaseException) return '${e.plugin}/${e.code}';
    if (e is TimeoutException) return 'timeout';
    return e?.runtimeType.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: AppIconSize.i48, color: context.colors.textHint),
              const SizedBox(height: AppSpacing.s16),
              Text(context.l10n.entry_couldNotLoadTitle,
                  style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f17)),
              const SizedBox(height: AppSpacing.s8),
              Text(
                _explanation(context.l10n),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSoft),
              ),
              if (_tag != null) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(_tag!, style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textHint)),
              ],
              const SizedBox(height: AppSpacing.s24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.common_tryAgain),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  OutlinedButton.icon(
                    onPressed: () => forceLogoutAndShowLogin(),
                    icon: const Icon(Icons.logout),
                    label: Text(context.l10n.common_logout),
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

class _NoFacilityScreen extends StatefulWidget {
  final String? role;
  // Something to tell the person first - e.g. that their request was rejected.
  final String? notice;
  const _NoFacilityScreen({this.role, this.notice});

  @override
  State<_NoFacilityScreen> createState() => _NoFacilityScreenState();
}

class _NoFacilityScreenState extends State<_NoFacilityScreen> {
  static const Color _deepGreen = AppPalette.primary;

  final MembershipService _membership = MembershipService();
  final TextEditingController _codeController = TextEditingController();
  Timer? _debounce;

  InviteCheck? _found; // the facility a valid code leads to
  String? _codeProblem; // why the code can't be used
  String? _error; // why asking to join failed
  bool _checking = false;
  bool _joining = false;

  bool get _isAssistant => widget.role == UserRole.assistant.key;

  // ---- an admin with no facility: add one, or delete the account ----
  final TextEditingController _facilityNameController = TextEditingController();
  String? _facilityType;
  bool _adding = false;
  String? _addError;

  @override
  void dispose() {
    _debounce?.cancel();
    _codeController.dispose();
    _facilityNameController.dispose();
    super.dispose();
  }

  Future<void> _addFacility() async {
    if (_adding) return;
    final name = _facilityNameController.text.trim();
    final type = _facilityType;
    if (name.isEmpty || type == null) {
      setState(() => _addError = name.isEmpty ? L10n.current.noFacility_enterName : L10n.current.noFacility_chooseType);
      return;
    }
    setState(() {
      _adding = true;
      _addError = null;
    });
    try {
      // The server checks the limit, starts the trial and tells the admin.
      await _membership.addFacility(name: name, type: type);
      // The profile lists it now: decide afresh, which lands on the dashboard.
      reDecideAccount?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _adding = false;
        _addError = MembershipService.errorMessage(e);
      });
    }
  }

  String _deleteAccountError(Object e) {
    if (e is FirebaseAuthException) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') return L10n.current.noFacility_wrongPassword;
      if (e.code == 'too-many-requests') return L10n.current.noFacility_tooManyAttempts;
      if (e.code == 'network-request-failed') return L10n.current.noFacility_unreachable;
      return e.message ?? L10n.current.noFacility_deleteFailed;
    }
    return L10n.current.noFacility_deleteFailedWith('$e');
  }

  // Deleting the account used to live only inside Settings - which needs a
  // facility to open. The advice "delete your facilities first, then you can
  // delete your account" therefore ended here with no way to do the last step.
  Future<void> _confirmDeleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Account deletion is refused while the account still OWNS a facility - it
    // would leave one that nobody could manage or delete. Normally that can't
    // be the case here, but a facility missing from the profile would be
    // exactly that.
    try {
      final owned = await FirebaseFirestore.instance
          .collection(Collections.facilities)
          .where('createdBy', isEqualTo: user.uid)
          .limit(AppLimits.single)
          .get();
      if (owned.docs.isNotEmpty && mounted) {
        final name = (owned.docs.first.data()['name'] ?? L10n.current.noFacility_aFacility).toString();
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.l10n.noFacility_cantDeleteTitle),
            content: SizedBox(
              width: 340,
              child: Text(ctx.l10n.noFacility_stillOwns(name)),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.common_ok))],
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('[ACCOUNT] ownership check failed, continuing: $e');
    }
    if (!mounted) return;

    // Not disposed: they live exactly as long as the dialog, and disposing
    // while it animates closed can trip a "used after dispose" error.
    final emailController = TextEditingController(text: user.email ?? '');
    final passwordController = TextEditingController();
    var deleting = false;
    String? dialogError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(ctx.l10n.noFacility_deleteTitle),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ctx.l10n.noFacility_deleteWarning,
                  style: const TextStyle(fontSize: AppFontSize.f13),
                ),
                const SizedBox(height: AppSpacing.s14),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(labelText: ctx.l10n.common_email, prefixIcon: const Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: AppSpacing.s8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: ctx.l10n.common_password, prefixIcon: const Icon(Icons.lock_outline)),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: AppSpacing.s10),
                  Text(dialogError!, style: TextStyle(color: context.colors.dangerAccent, fontSize: AppFontSize.f12_5)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: deleting ? null : () => Navigator.pop(ctx), child: Text(ctx.l10n.common_cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.dangerAccent, foregroundColor: context.colors.onPrimary),
              onPressed: deleting
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        setDialogState(() => dialogError = L10n.current.noFacility_enterPasswordToConfirm);
                        return;
                      }
                      setDialogState(() {
                        deleting = true;
                        dialogError = null;
                      });
                      try {
                        await AuthService().deleteAccount(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await forceLogoutAndShowLogin(message: L10n.current.noFacility_accountDeleted);
                      } catch (e) {
                        if (!ctx.mounted) return;
                        setDialogState(() {
                          deleting = false;
                          dialogError = _deleteAccountError(e);
                        });
                      }
                    },
              child: deleting
                  ? SizedBox(
                      width: AppIconSize.i18,
                      height: AppIconSize.i18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                    )
                  : Text(ctx.l10n.noFacility_deleteAccount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.s22),
        TextField(
          controller: _facilityNameController,
          enabled: !_adding,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() => _addError = null),
          decoration: InputDecoration(
            labelText: context.l10n.common_facilityName,
            hintText: context.l10n.common_facilityNameHint,
            prefixIcon: const Icon(Icons.storefront_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r14)),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        DropdownButtonFormField<String>(
          initialValue: _facilityType,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.l10n.common_type,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r14)),
          ),
          items: kFacilityTypes.map((t) => DropdownMenuItem(value: t, child: Text(context.l10n.facilityTypeLabel(t)))).toList(),
          onChanged: _adding
              ? null
              : (value) => setState(() {
                    _facilityType = value;
                    _addError = null;
                  }),
        ),
        if (_addError != null) ...[
          const SizedBox(height: AppSpacing.s10),
          Text(_addError!, textAlign: TextAlign.center, style: TextStyle(color: context.colors.dangerAccent, fontSize: AppFontSize.f12_5)),
        ],
        const SizedBox(height: AppSpacing.s16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _adding ? null : _addFacility,
            style: ElevatedButton.styleFrom(
              backgroundColor: _deepGreen,
              foregroundColor: context.colors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r14)),
            ),
            child: _adding
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: AppIconSize.i18, height: AppIconSize.i18, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary)),
                      SizedBox(width: AppSpacing.s10),
                      Text(context.l10n.noFacility_adding),
                    ],
                  )
                : Text(context.l10n.noFacility_addFacility),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        TextButton(
          onPressed: _adding ? null : _confirmDeleteAccount,
          style: TextButton.styleFrom(foregroundColor: context.colors.dangerAccent),
          child: Text(context.l10n.noFacility_deleteInstead),
        ),
      ],
    );
  }

  // Same approach as the register screen: wait for a pause in typing, then ask
  // the server - so the person sees which facility a code leads to BEFORE they
  // send anything.
  void _onCodeChanged(String value) {
    _debounce?.cancel();
    final code = value.trim();
    final letters = code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    setState(() {
      _found = null;
      _codeProblem = null;
      _error = null;
      _checking = letters.length >= AppRules.inviteCodeLength;
    });
    if (letters.length < AppRules.inviteCodeLength) return;

    _debounce = Timer(AppTimeouts.inviteCodeLookupDebounce, () async {
      try {
        final check = await _membership.checkInviteCode(code);
        // They've typed on since - this answer is about an older code.
        if (!mounted || _codeController.text.trim() != code) return;
        setState(() {
          _checking = false;
          _found = check;
          _codeProblem = check == null ? L10n.current.noFacility_codeInvalid : null;
        });
      } catch (e) {
        if (!mounted || _codeController.text.trim() != code) return;
        setState(() {
          _checking = false;
          _codeProblem = MembershipService.errorMessage(e);
        });
      }
    });
  }

  Future<void> _join() async {
    final found = _found;
    if (found == null || _joining) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await _membership.joinFacilityWithInvite(code: _codeController.text.trim());
      // They're "pending" now, so the sign-in check would turn them away
      // anyway. Sign out with a plain message rather than leave them here.
      await forceLogoutAndShowLogin(
        message: L10n.current.noFacility_requestSent(found.facilityName),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _error = MembershipService.errorMessage(e);
      });
    }
  }

  Widget _logoutButton() {
    return OutlinedButton.icon(
      onPressed: (_joining || _adding) ? null : () => forceLogoutAndShowLogin(),
      icon: const Icon(Icons.logout),
      label: Text(context.l10n.common_logout),
    );
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_outlined, size: AppIconSize.i48, color: context.colors.textHint),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  _isAssistant ? context.l10n.noFacility_titleAssistant : context.l10n.noFacility_titleAdmin,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f17),
                ),
                if (widget.notice != null) ...[
                  const SizedBox(height: AppSpacing.s14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: context.colors.warning.withValues(alpha: AppAlpha.a10),
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                      border: Border.all(color: context.colors.warning.withValues(alpha: AppAlpha.a40)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: AppIconSize.i18, color: context.colors.warningStrong),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Text(
                            context.l10n.noFacility_noticeMistake(widget.notice!),
                            style: TextStyle(fontSize: AppFontSize.f13, color: Colors.orange.shade900, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s8),
                Text(
                  _isAssistant
                      ? context.l10n.noFacility_bodyAssistant
                      : context.l10n.noFacility_bodyAdmin,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textSoft, height: 1.4),
                ),
                if (_isAssistant) ...[
                  const SizedBox(height: AppSpacing.s22),
                  TextField(
                    controller: _codeController,
                    enabled: !_joining,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: _onCodeChanged,
                    decoration: InputDecoration(
                      labelText: context.l10n.common_inviteCode,
                      hintText: context.l10n.noFacility_inviteHint,
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      suffixIcon: _checking
                          ? const Padding(
                              padding: EdgeInsets.all(AppSpacing.s12),
                              child: SizedBox(width: AppIconSize.i18, height: AppIconSize.i18, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : (found != null ? Icon(Icons.check_circle, color: context.colors.success) : null),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r14)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  if (found != null)
                    Text(
                      found.facilityType.isEmpty
                          ? context.l10n.noFacility_askingToJoin(found.facilityName)
                          : context.l10n.noFacility_askingToJoinWithType(
                              found.facilityName, context.l10n.facilityTypeLabel(found.facilityType)),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.success, fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13),
                    )
                  else if (_codeProblem != null)
                    Text(_codeProblem!,
                        textAlign: TextAlign.center, style: TextStyle(color: context.colors.dangerAccent, fontSize: AppFontSize.f12_5)),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.s8),
                    Text(_error!,
                        textAlign: TextAlign.center, style: TextStyle(color: context.colors.dangerAccent, fontSize: AppFontSize.f12_5)),
                  ],
                  const SizedBox(height: AppSpacing.s16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: (found != null && !_joining) ? _join : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _deepGreen,
                        foregroundColor: context.colors.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r14)),
                      ),
                      child: _joining
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: AppIconSize.i18,
                                  height: AppIconSize.i18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                                ),
                                SizedBox(width: AppSpacing.s10),
                                Text(context.l10n.noFacility_sending),
                              ],
                            )
                          : Text(context.l10n.noFacility_requestToJoin),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  Text(
                    context.l10n.noFacility_approvalNote,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f12, height: 1.4),
                  ),
                ],
                if (!_isAssistant) _adminSection(),
                const SizedBox(height: AppSpacing.s20),
                _logoutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
