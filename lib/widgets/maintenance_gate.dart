import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Wraps the entire app (see main.dart's MaterialApp.builder) so a
/// maintenance-mode block applies regardless of which screen or dialog
/// is currently showing, without every individual screen needing its
/// own check.
///
/// Deliberately three layered, live StreamBuilders rather than a
/// one-time check at login:
///   1. Auth state - nobody signed in yet always reaches the login
///      screen untouched, maintenance mode or not. A Platform Admin
///      who isn't already signed in on this device still needs to be
///      able to log in to turn maintenance back off - blocking the
///      login screen itself would lock them out of doing that.
///   2. Platform Admin status - checked per signed-in user, live, so
///      someone granted or revoked Platform Admin access mid-session
///      doesn't need to sign out and back in for it to take effect.
///   3. The maintenance flag itself - live, so an app already open
///      when a Platform Admin flips this on reacts within seconds,
///      not just on next launch.
class MaintenanceGate extends StatelessWidget {
  final Widget child;
  const MaintenanceGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) return child;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('platform_admins')
              .doc(user.uid)
              .snapshots(),
          builder: (context, platformAdminSnapshot) {
            final isPlatformAdmin = platformAdminSnapshot.data?.exists ?? false;
            if (isPlatformAdmin) return child;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('platform_config')
                  .doc('settings')
                  .snapshots(),
              builder: (context, configSnapshot) {
                final data = configSnapshot.data?.data();
                final isMaintenanceMode = data?['maintenanceMode'] as bool? ?? false;
                if (!isMaintenanceMode) return child;

                final customMessage = (data?['maintenanceMessage'] as String?)?.trim();
                return MaintenanceScreen(
                  message: (customMessage != null && customMessage.isNotEmpty)
                      ? customMessage
                      : "We're currently performing scheduled maintenance. "
                          "Please try again shortly.",
                );
              },
            );
          },
        );
      },
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
                    onPressed: () => FirebaseAuth.instance.signOut(),
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
