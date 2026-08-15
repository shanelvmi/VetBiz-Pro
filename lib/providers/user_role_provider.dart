import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/force_logout.dart';

/// Tracks the signed-in user's own role in real time (admin vs
/// assistant), read from their `users/{uid}` document - the same
/// `role` field the Firestore rules and the Wipe Data Cloud Function
/// already check. This is the single source of truth the whole app uses
/// to decide what to show/hide for the current user.
class UserRoleProvider with ChangeNotifier {
  StreamSubscription<DocumentSnapshot>? _subscription;

  String? _role;
  String get role => _role ?? 'assistant';
  bool get isAdmin => _role == 'admin';
  bool get isAssistant => !isAdmin;

  void listenToCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      _role = snapshot.data()?['role'] as String?;

      // If someone else (an admin) deactivates this account while it's
      // actively in use, this fires the moment that write lands - no
      // need to wait for their next login attempt to find out. Platform
      // Admins are exempt (checked here as a backup - the rules
      // themselves now prevent a Platform Admin's status from ever
      // being set to deactivated in the first place).
      final status = (snapshot.data()?['status'] as String?)?.toLowerCase();
      if (status == 'deactivated') {
        _handlePossibleDeactivation(user.uid);
        return;
      }

      notifyListeners();
    }, onError: (e) {
      debugPrint('UserRoleProvider listen error: $e');
    });
  }

  Future<void> _handlePossibleDeactivation(String uid) async {
    try {
      final platformAdminDoc = await FirebaseFirestore.instance
          .collection('platform_admins')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));
      if (platformAdminDoc.exists) {
        // Exempt - this account is a Platform Admin, so this status
        // value is ignored entirely regardless of how it got set.
        notifyListeners();
        return;
      }
    } catch (e) {
      // Couldn't determine Platform Admin status (a timeout, a network
      // issue) - proceed with the logout below rather than leave this
      // hanging indefinitely. Failing toward still enforcing
      // deactivation is the safer default than silently doing nothing.
      debugPrint('UserRoleProvider: platform admin check failed, proceeding with logout: $e');
    }

    clear();
    forceLogoutAndShowLogin(
      message: 'Your account has been deactivated by an admin.',
    );
  }

  void clear() {
    _subscription?.cancel();
    _subscription = null;
    _role = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
