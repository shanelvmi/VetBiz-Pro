import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get user => _auth.authStateChanges();

  // ✅ Register admin or regular user
  Future<String> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
    required List<Map<String, dynamic>> facilities, // changed to dynamic
    String avatarUrl = '',
    String status = 'active', // default active for admins/users
  }) async {
    UserCredential userCred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    try {
      await userCred.user!.sendEmailVerification();
    } catch (e) {
      // Registration itself already succeeded - a failed verification
      // email (network hiccup, rate limit) shouldn't block the account
      // from being created. They can resend it later from the
      // dashboard reminder.
    }

    await _saveUserToFirestore(
      uid: userCred.user!.uid,
      fullName: fullName,
      email: email,
      phone: phone,
      role: role,
      facilities: facilities,
      avatarUrl: avatarUrl,
      status: status,
    );

    return userCred.user!.uid;
  }

  // ✅ Register assistant via secondary Firebase app
  Future<String> registerAssistantSilently({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required List<Map<String, dynamic>> facilities, // changed to dynamic
    Uint8List? avatarBytes, // optional avatar bytes
  }) async {
    final FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp',
      options: Firebase.app().options,
    );

    final FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    final FirebaseFirestore secondaryFirestore = FirebaseFirestore.instanceFor(app: secondaryApp);

    UserCredential userCred = await secondaryAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    try {
      await userCred.user!.sendEmailVerification();
    } catch (e) {
      // Same reasoning as the admin path - don't let a failed
      // verification email block the registration itself.
    }

    final String newUid = userCred.user!.uid;
    String avatarUrl = '';

    if (avatarBytes != null) {
      final ref = FirebaseStorage.instanceFor(app: secondaryApp).ref().child('avatars/$newUid.jpg');
      await ref.putData(avatarBytes);
      avatarUrl = await ref.getDownloadURL();
    }

    List<String> facilityIds = facilities
        .map((f) => f['facilityId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    await secondaryFirestore.collection('users').doc(newUid).set({
      'uid': newUid,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': 'assistant',
      'status': 'pending',
      'facilities': facilities,
      'facilityIds': facilityIds,
      'avatarUrl': avatarUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await secondaryAuth.signOut();
    await secondaryApp.delete();

    return newUid;
  }

  // ✅ Save user to Firestore (for Admin or regular user)
  Future<void> _saveUserToFirestore({
    required String uid,
    required String fullName,
    required String email,
    required String phone,
    required String role,
    required List<Map<String, dynamic>> facilities, // changed to dynamic
    required String avatarUrl,
    String status = 'active',
  }) async {
    List<String> facilityIds = facilities
        .map((f) => f['facilityId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role.toLowerCase(),
      'status': status,
      'facilities': facilities,
      'facilityIds': facilityIds,
      'avatarUrl': avatarUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
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

    await _firestore.collection('users').doc(user.uid).update({
      'status': 'deactivated',
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
    await _firestore.collection('users').doc(user.uid).delete();

    // Delete Firebase Auth account
    await user.delete();
  }
}
