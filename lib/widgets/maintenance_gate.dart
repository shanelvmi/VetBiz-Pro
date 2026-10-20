import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/l10n.dart';
import '../utils/force_logout.dart';
import '../theme/app_dimens.dart';
import '../theme/app_motion.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';
import '../data/collections.dart';
import '../config/app_info.dart';
import '../utils/app_version.dart';
import 'update_required_screen.dart';

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
///
/// The same config document also holds the minimum app version (P1):
/// `minimumVersion`, a dotted version like "1.0.0". A running
/// [AppInfo.version] lower than it shows [UpdateRequiredScreen] instead,
/// on the same terms as maintenance (signed out and Platform Admins pass;
/// an absent or unreadable value blocks nobody). It is checked before
/// maintenance: an old app stays blocked after maintenance ends.
class MaintenanceGate extends StatefulWidget {
  final Widget child;

  /// Test seams (P1); the app passes none of them. [uidChanges] and
  /// [initialUid] stand in for FirebaseAuth, [firestore] for the database,
  /// [appVersion] for [AppInfo.version].
  final Stream<String?>? uidChanges;
  final String? initialUid;
  final FirebaseFirestore? firestore;
  final String appVersion;

  const MaintenanceGate({
    super.key,
    required this.child,
    this.uidChanges,
    this.initialUid,
    this.firestore,
    this.appVersion = AppInfo.version,
  });

  @override
  State<MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends State<MaintenanceGate> {
  StreamSubscription<String?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _platformAdminSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _configSub;

  String? _uid;
  bool _isPlatformAdmin = false;
  Map<String, dynamic>? _configData;

  @override
  void initState() {
    super.initState();
    final uidChanges = widget.uidChanges ?? FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
    _authSub = uidChanges.listen(_onAuthChanged);
    // Known synchronously and immediately, rather than waiting for the
    // stream's first event - avoids a one-frame flash of "signed out"
    // for someone already signed in from a previous session.
    _onAuthChanged(widget.uidChanges != null ? widget.initialUid : FirebaseAuth.instance.currentUser?.uid);
  }

  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  void _onAuthChanged(String? uid) {
    if (!mounted) return;

    _platformAdminSub?.cancel();
    _platformAdminSub = null;
    _configSub?.cancel();
    _configSub = null;

    setState(() {
      _uid = uid;
      _isPlatformAdmin = false;
      _configData = null;
    });

    if (uid == null) return;

    _platformAdminSub = _db
        .collection(Collections.platformAdmins)
        .doc(uid)
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
        _configSub = _db
            .collection(Collections.platformConfig)
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
    if (_uid == null) return widget.child;
    if (_isPlatformAdmin) return widget.child;

    final minimumVersion = _configData?['minimumVersion'];
    if (AppVersion.isBelowMinimum(widget.appVersion, minimumVersion)) {
      return UpdateRequiredScreen(
        currentVersion: widget.appVersion,
        minimumVersion: (minimumVersion as String).trim(),
      );
    }

    final isMaintenanceMode = _configData?['maintenanceMode'] as bool? ?? false;
    if (!isMaintenanceMode) return widget.child;

    final customMessage = (_configData?['maintenanceMessage'] as String?)?.trim();
    return MaintenanceScreen(
      message: (customMessage != null && customMessage.isNotEmpty)
          ? customMessage
          : context.l10n.maintenance_defaultMessage,
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
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: AppMotion.pulseSlow,
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
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSizes.dialogSm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: AppAlpha.a10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.build_rounded, size: AppIconSize.i48, color: context.colors.primary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s28),
                  Text(
                    context.l10n.maintenance_title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: AppFontSize.f22, fontWeight: AppFontWeight.bold, color: context.colors.primary),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: AppFontSize.f14_5, color: context.colors.textSoft, height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.s32),
                  TextButton.icon(
                    onPressed: () => forceLogoutAndShowLogin(),
                    icon: const Icon(Icons.logout, size: AppIconSize.i18),
                    label: Text(context.l10n.common_signOut),
                    style: TextButton.styleFrom(foregroundColor: context.colors.textMuted),
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
