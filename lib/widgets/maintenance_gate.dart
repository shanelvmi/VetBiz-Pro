import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/force_logout.dart';

/// Wraps the entire app (see main.dart's MaterialApp.builder) so a
/// maintenance-mode block applies regardless of which screen or dialog
/// is currently showing, without every individual screen needing its
/// own check.
///
/// Tracks auth state, Platform Admin status, and the maintenance flag
/// itself live - not a one-time check at login - so someone granted or
/// revoked Platform Admin access mid-session, or a Platform Admin
/// flipping maintenance mode on, both take effect within seconds for
/// whoever's already using the app, not just on next launch. Nobody
/// signed in yet always reaches the login screen untouched, maintenance
/// mode or not - blocking the login screen itself would lock a Platform
/// Admin out of the one place they'd need to sign in to turn maintenance
/// back off from a fresh device.
///
/// A StatefulWidget managing its own three subscriptions directly,
/// deliberately not three nested StreamBuilders - build() must always
/// return exactly `child` or `MaintenanceScreen`, nothing else, and
/// nothing in between. A version with nested StreamBuilders instead
/// changes how many wrapper widgets sit between this gate and `child`
/// depending on account type and auth state (a Platform Admin's signed-
/// in tree only 2 levels deep, a regular account's 3, signed-out just
/// 1) - and when that surrounding structure changes shape, Flutter can
/// tear down and rebuild the entire subtree beneath it, including
/// AppEntryPoint buried inside `child`, even though `child` is the same
/// widget instance throughout. That's a real, confirmed failure mode,
/// not a hypothetical one: it explains a logout-then-login-as-someone-
/// else sequence occasionally leaving nothing left listening for auth
/// state at all, with the login screen then spinning forever on the
/// next sign-in - not because that sign-in failed, but because
/// AppEntryPoint itself had already been torn down and never
/// remounted. Keeping this gate's own output shape constant removes
/// that risk at its source.
class MaintenanceGate extends StatefulWidget {
  final Widget child;
  const MaintenanceGate({super.key, required this.child});

  @override
  State<MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends State<MaintenanceGate> {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _platformAdminSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _configSub;

  User? _user;
  bool _isPlatformAdmin = false;
  Map<String, dynamic>? _configData;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    // Known synchronously and immediately, rather than waiting for the
    // stream's first event - avoids a one-frame flash of "signed out"
    // for someone already signed in from a previous session.
    _onAuthChanged(FirebaseAuth.instance.currentUser);
  }

  void _onAuthChanged(User? user) {
    if (!mounted) return;

    _platformAdminSub?.cancel();
    _platformAdminSub = null;
    _configSub?.cancel();
    _configSub = null;

    setState(() {
      _user = user;
      _isPlatformAdmin = false;
      _configData = null;
    });

    if (user == null) return;

    _platformAdminSub = FirebaseFirestore.instance
        .collection('platform_admins')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final isPlatformAdmin = snap.exists;
      setState(() => _isPlatformAdmin = isPlatformAdmin);

      // The maintenance config is only ever relevant for a non-Platform-
      // Admin - a Platform Admin always passes through regardless of it,
      // so there's no reason to keep a live subscription to it for one.
      _configSub?.cancel();
      _configSub = null;
      if (!isPlatformAdmin) {
        _configSub = FirebaseFirestore.instance
            .collection('platform_config')
            .doc('settings')
            .snapshots()
            .listen((configSnap) {
          if (!mounted) return;
          setState(() => _configData = configSnap.data());
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _platformAdminSub?.cancel();
    _configSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return widget.child;
    if (_isPlatformAdmin) return widget.child;

    final isMaintenanceMode = _configData?['maintenanceMode'] as bool? ?? false;
    if (!isMaintenanceMode) return widget.child;

    final customMessage = (_configData?['maintenanceMessage'] as String?)?.trim();
    return MaintenanceScreen(
      message: (customMessage != null && customMessage.isNotEmpty)
          ? customMessage
          : "We're currently performing scheduled maintenance. "
              "Please try again shortly.",
    );
  }
}

/// The full-screen block shown to anyone not a Platform Admin while
/// maintenance mode is on. A gentle, repeating pulse on the icon so
/// this reads as "actively working on it" rather than a static,
/// abandoned-looking error page.
class MaintenanceScreen extends StatefulWidget {
  final String message;
  const MaintenanceScreen({super.key, required this.message});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> with SingleTickerProviderStateMixin {
  static const Color primaryDeepGreen = Color(0xFF2F5D62);
  static const Color offWhite = Color(0xFFFDFDF9);

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: offWhite,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: primaryDeepGreen.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.build_rounded, size: 44, color: primaryDeepGreen),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    "We'll be right back",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryDeepGreen),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, color: Colors.grey[700], height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  TextButton.icon(
                    onPressed: () => forceLogoutAndShowLogin(),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
