import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

import 'membership_service.dart';
import '../data/collections.dart';
import '../data/fields.dart';
import '../data/user_status.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get user => _auth.authStateChanges();

  // ======================================================================
  // REGISTRATION
  // ======================================================================
  //
  // Both kinds of account are created the same way, and the app never writes
  // the person's profile itself (role, status, which facilities they belong
  // to): it creates the Firebase account on a SEPARATE, temporary app session,
  // then asks the server to build the profile (MembershipService), which
  // decides all of that.
  //
  // The separate session matters. The main session only signs in once the
  // profile is complete, so the app never sees a signed-in person with no
  // profile yet - which is what it used to paper over with a retry loop.

  // The secondary app is created ONCE and reused for the life of the page -
  // it is never deleted.
  //
  // It used to be deleted and re-created around every registration. That works
  // exactly once: FirebaseAuth.instanceFor() keeps one cached instance per app
  // NAME, and in the firebase_auth version this app uses nothing clears that
  // cache when an app is deleted. So the second registration in a session was
  // handed the Auth object of the app that no longer existed, and failed with
  // a network-style error (timeout / unreachable / interrupted connection).
  // The first registration worked; every later one broke.
  Future<FirebaseApp> _secondaryApp() async {
    try {
      return Firebase.app('SecondaryApp');
    } catch (_) {
      // Not created yet - the normal case on first use.
      return Firebase.initializeApp(name: 'SecondaryApp', options: Firebase.app().options);
    }
  }

  // Signed out before use as well as after: an interrupted earlier attempt
  // could have left someone signed in on it.
  Future<FirebaseAuth> _cleanSecondaryAuth(FirebaseApp app) async {
    final auth = FirebaseAuth.instanceFor(app: app);
    try {
      await auth.signOut();
    } catch (_) {}
    return auth;
  }

  Future<void> _closeSecondary(FirebaseAuth auth) async {
    try {
      await auth.signOut();
    } catch (_) {}
  }

  // Which step failed, in the console - registration spans an account, an
  // email, a photo and a server call, and "something went wrong" alone
  // doesn't say which.
  Future<UserCredential> _createAccount(FirebaseAuth auth, String email, String password) async {
    try {
      debugPrint('[REGISTER] creating the account');
      return await auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      debugPrint('[REGISTER] creating the account FAILED: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Registers a new owner (Admin) with their first facility or facilities
  /// ([facilities]: name and type each), then signs them in. Returns the
  /// facilities with the ids the server gave them.
  ///
  /// If the server can't create the profile, the bare account is removed again,
  /// so the person can simply try again - not be told the email is "already
  /// registered" with nothing behind it.
  Future<List<Map<String, dynamic>>> registerOwnerAccount({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required List<Map<String, dynamic>> facilities,
  }) async {
    final secondaryApp = await _secondaryApp();
    final secondaryAuth = await _cleanSecondaryAuth(secondaryApp);
    late List<Map<String, dynamic>> created;

    try {
      final cred = await _createAccount(secondaryAuth, email, password);

      try {
        await cred.user!.sendEmailVerification();
      } catch (_) {
        // Registration itself already succeeded - a failed verification
        // email (network hiccup, rate limit) shouldn't block the account.
        // They can resend it later from the dashboard reminder.
      }

      try {
        debugPrint('[REGISTER] asking the server to create the profile and facilities');
        created = await MembershipService(functions: FirebaseFunctions.instanceFor(app: secondaryApp, region: kMembershipFunctionsRegion))
            .registerOwner(fullName: fullName, phone: phone, facilities: facilities);
      } catch (e) {
        debugPrint('[REGISTER] the server step FAILED: $e');
        try {
          await cred.user?.delete();
        } catch (_) {}
        rethrow;
      }
    } finally {
      await _closeSecondary(secondaryAuth);
    }

    // The profile is complete now, so this is the first the main session
    // sees of the account.
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (_) {
      throw AccountCreatedException(
          'Your account was created, but we could not sign you in automatically. '
          'Please log in with your email and password.');
    }
    return created;
  }

  /// Registers an assistant with an invite code. The server puts them in the
  /// facility the invite was made for, as "pending" until an admin approves
  /// them, and uses the invite up in the same step - the person chooses none
  /// of that. They are NOT signed in: they wait for approval.
  Future<void> registerAssistantWithInvite({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String inviteCode,
    Uint8List? avatarBytes,
  }) async {
    final secondaryApp = await _secondaryApp();
    final secondaryAuth = await _cleanSecondaryAuth(secondaryApp);

    try {
      final cred = await _createAccount(secondaryAuth, email, password);

      try {
        await cred.user!.sendEmailVerification();
      } catch (_) {
        // Same reasoning as the owner path.
      }

      var avatarUrl = '';
      if (avatarBytes != null) {
        try {
          final ref = FirebaseStorage.instanceFor(app: secondaryApp).ref().child('avatars/${cred.user!.uid}.jpg');
          await ref.putData(avatarBytes);
          avatarUrl = await ref.getDownloadURL();
        } catch (_) {
          // The photo is optional - registering without it beats failing here.
        }
      }

      try {
        debugPrint('[REGISTER] asking the server to join the facility with the invite');
        await MembershipService(functions: FirebaseFunctions.instanceFor(app: secondaryApp, region: kMembershipFunctionsRegion)).joinWithInvite(
          code: inviteCode,
          fullName: fullName,
          phone: phone,
          avatarUrl: avatarUrl,
        );
      } catch (e) {
        debugPrint('[REGISTER] the server step FAILED: $e');
        // No profile was created (the code may have just been used, or has
        // expired): remove the bare account so the person can retry.
        try {
          await cred.user?.delete();
        } catch (_) {}
        rethrow;
      }
    } finally {
      await _closeSecondary(secondaryAuth);
    }
  }

  // ✅ Login
  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // ✅ Password reset
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ✅ Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ✅ Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // 🔹 Resend the verification email - used by the dashboard reminder
  Future<void> resendEmailVerification() async {
    final user = getCurrentUser();
    if (user == null) throw Exception('No user logged in');
    await user.sendEmailVerification();
  }

  // 🔹 Refresh the cached emailVerified flag - Firebase doesn't update
  // this automatically once the user clicks the link in their email,
  // it has to be explicitly re-fetched.
  Future<bool> refreshEmailVerifiedStatus() async {
    final user = getCurrentUser();
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // 🔹 Deactivate account
  Future<void> deactivateAccount() async {
    final user = getCurrentUser();
    if (user == null) throw Exception('No user logged in');

    await _firestore.collection(Collections.users).doc(user.uid).update({
      Fields.status: UserStatus.deactivated.key,
    });

    await logout(); // Immediately log out user
  }

  // 🔹 Delete account permanently
  Future<void> deleteAccount({required String email, required String password}) async {
    final user = getCurrentUser();
    if (user == null) throw Exception('No user logged in');

    // Reauthenticate
    final credential = EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(credential);

    // Delete Firestore user doc
    await _firestore.collection(Collections.users).doc(user.uid).delete();

    // Delete Firebase Auth account
    await user.delete();
  }
}

/// The account WAS created, but something afterwards failed - so the person
/// should be told to log in, not to register again. Its message is meant to be
/// shown as it is.
class AccountCreatedException implements Exception {
  final String message;
  AccountCreatedException(this.message);

  @override
  String toString() => message;
}
