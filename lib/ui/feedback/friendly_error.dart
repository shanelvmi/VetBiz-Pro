import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_error_messages.dart';

/// Turns an error into one sentence a person can read, and keeps the
/// technical detail for the Details action (PHASE2_FEEDBACK_SPEC section 5).
///
/// Raw exception text never reaches the screen: anything that still looks
/// technical after the mapping falls back to the generic sentence.
class FriendlyError {
  FriendlyError._();

  static const String fallback = 'Something went wrong. Try again.';
  static const String noPermission = "You don't have permission to do that.";
  static const String noConnection = 'No connection. Check your internet and try again.';
  static const String tooSlow = 'That took too long. Try again.';
  static const String notFound = 'That item no longer exists.';
  static const String alreadyExists = 'That already exists.';
  static const String tooManyRequests = 'Too many requests. Wait a moment and try again.';

  /// One sentence for [error].
  static String messageFor(Object error) => _clean(_map(error));

  /// What the Details action shows: the code and the message, as given.
  static String detailsFor(Object error) {
    if (error is FirebaseException) {
      final message = (error.message ?? '').trim();
      return message.isEmpty ? error.code : '${error.code}: $message';
    }
    if (error is TimeoutException) {
      return 'timeout: ${error.message ?? error.duration ?? ''}'.trim();
    }
    return error.toString();
  }

  static String _map(Object error) {
    // Order matters: both of these are also FirebaseExceptions.
    if (error is FirebaseAuthException) return authErrorMessage(error);
    if (error is FirebaseFunctionsException) {
      // Our own functions (functions/membership.js) throw HttpsErrors whose
      // messages are written for people, so those are shown as they are.
      // 'internal' carries no useful text, and the transport codes never
      // come from our HttpsErrors, so those use the code's sentence.
      const transport = {'internal', 'unavailable', 'deadline-exceeded'};
      final message = (error.message ?? '').trim();
      if (!transport.contains(error.code) && message.isNotEmpty) return message;
      return _forCode(error.code);
    }
    if (error is FirebaseException) return _forCode(error.code);
    if (error is TimeoutException) return tooSlow;
    return fallback;
  }

  static String _forCode(String code) => switch (code) {
        'permission-denied' => noPermission,
        'unavailable' || 'network-request-failed' => noConnection,
        'deadline-exceeded' => tooSlow,
        'not-found' => notFound,
        'already-exists' => alreadyExists,
        'resource-exhausted' => tooManyRequests,
        _ => fallback,
      };

  // A last guard: a message that still carries exception names, bracketed
  // plugin tags ("[cloud_firestore/...]") or stack-trace lines is replaced.
  static String _clean(String message) {
    final looksTechnical = message.contains('Exception') ||
        message.contains('[') ||
        message.contains('cloud_firestore') ||
        RegExp(r'#\d+\s|\.dart:\d+|\n\s*at ').hasMatch(message);
    return looksTechnical || message.trim().isEmpty ? fallback : message;
  }
}
