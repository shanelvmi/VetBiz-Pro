import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Writes a "last active" heartbeat to the current user's own document
/// every couple of minutes while they're signed in - the basis for the
/// Users tab's online/offline indicator.
///
/// Not a true, instant connect/disconnect presence system - this app
/// has no Realtime Database, which is what that would actually
/// require (its onDisconnect() hook). This is a heartbeat-and-timeout
/// approximation instead: "online" means a heartbeat landed recently,
/// not "currently has an open connection". Good enough for "is this
/// person roughly active right now", not suitable for anything that
/// needs to react the instant someone actually disconnects.
class PresenceHeartbeat {
  static Timer? _timer;
  static const Duration interval = Duration(minutes: 2);

  // Comfortably longer than [interval] - a single missed or delayed
  // beat (a brief network hiccup, the app briefly backgrounded)
  // shouldn't flip someone to "offline" and back within the same
  // ongoing session.
  static const Duration onlineWindow = Duration(minutes: 5);

  static void start() {
    _sendHeartbeat();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _sendHeartbeat());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _sendHeartbeat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // update(), not set(..., merge: true) - the latter creates the
      // document if it doesn't exist yet, which is exactly the trap:
      // right after sign-in, before the registration flow's own write
      // of the real profile has necessarily run, this heartbeat could
      // otherwise win that race and originate the user's document
      // itself, containing nothing but this one field. update() only
      // ever succeeds against a document that already exists, so a
      // missing profile simply means this beat fails harmlessly - the
      // same as any other missed heartbeat - rather than silently
      // creating a broken, real-profile-less account.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'lastActiveAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // A missed heartbeat just means this one user briefly reads as
      // offline until the next beat succeeds - not worth surfacing as
      // an error over what's a purely cosmetic indicator elsewhere.
    }
  }
}
