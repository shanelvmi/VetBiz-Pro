import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/force_logout.dart';
import '../data/collections.dart';
import '../data/fields.dart';
import '../data/user_role.dart';
import '../data/user_status.dart';
import '../config/app_timeouts.dart';
import '../l10n/l10n.dart';

/// Tracks the signed-in user's own role in real time (admin vs
/// assistant), read from their `users/{uid}` document - the same
/// `role` field the Firestore rules and the Wipe Data Cloud Function
/// already check. This is the single source of truth the whole app uses
/// to decide what to show/hide for the current user.
class UserRoleProvider with ChangeNotifier {
  UserRoleProvider({FirebaseFirestore? firestore, String? Function()? currentUid})
      : _firestore = firestore,
        _currentUid = currentUid;

  // Null: the app's own Firestore and signed-in user. Tests pass an
  // in-memory Firestore and a fixed uid (REFRESH-1).
  final FirebaseFirestore? _firestore;
  final String? Function()? _currentUid;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot>? _subscription;

  String? _role;
  String get role => _role ?? UserRole.assistant.key;
  bool get isAdmin => _role == UserRole.admin.key;
  bool get isAssistant => !isAdmin;

  void listenToCurrentUser() {
    final uid = _currentUid != null ? _currentUid() : FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _subscription?.cancel();
    _subscription = _db
        .collection(Collections.users)
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      _role = snapshot.data()?[Fields.role] as String?;

      // If someone else (an admin) deactivates this account while it's
      // actively in use, this fires the moment that write lands - no
      // need to wait for their next login attempt to find out. Platform
      // Admins are exempt (checked here as a backup - the rules
      // themselves now prevent a Platform Admin's status from ever
      // being set to deactivated in the first place).
      final status = (snapshot.data()?[Fields.status] as String?)?.toLowerCase();
      if (status == UserStatus.deactivated.key) {
        _handlePossibleDeactivation(uid);
        return;
      }

      notifyListeners();
    }, onError: (e) {
      debugPrint('UserRoleProvider listen error: $e');
    });
  }

  Future<void> _handlePossibleDeactivation(String uid) async {
    try {
      final platformAdminDoc = await _db
          .collection(Collections.platformAdmins)
          .doc(uid)
          .get()
          .timeout(AppTimeouts.roleLoad);
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
      message: L10n.current.session_deactivatedByAdmin,
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
