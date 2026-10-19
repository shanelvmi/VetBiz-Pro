import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../config/money.dart';
import '../../l10n/l10n.dart';
import '../../models/admin_only_refusal.dart';
import '../../models/client_delete_refusal.dart';
import '../../models/restore_outcome.dart';
import 'auth_error_messages.dart';

/// Turns an error into one sentence a person can read, and keeps the
/// technical detail for the Details action (PHASE2_FEEDBACK_SPEC section 5).
///
/// Raw exception text never reaches the screen: anything that still looks
/// technical after the mapping falls back to the generic sentence.
class FriendlyError {
  FriendlyError._();

  // In the current language (L10n.current): these are often read after an
  // await, with no BuildContext. The English texts are in lib/l10n/app_en.arb.
  static String get fallback => L10n.current.error_generic;
  static String get noPermission => L10n.current.error_noPermission;
  static String get noConnection => L10n.current.error_noConnection;
  static String get tooSlow => L10n.current.error_tooSlow;
  static String get notFound => L10n.current.error_notFound;
  static String get alreadyExists => L10n.current.error_alreadyExists;
  static String get tooManyRequests => L10n.current.error_rateLimited;

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
    if (error is RestoreRefusedException) return _restoreRefusal(error);
    // E3, owner decision: a client who still owes money is not deleted.
    if (error is ClientDeleteRefusedException) {
      return L10n.current.clients_deleteRefusedOwes(Money.format(error.owed));
    }
    // E4d-2, owner decision: Edit Service, Edit Transaction and deleting a
    // transaction are admin-only.
    if (error is AdminOnlyException) return L10n.current.error_adminOnly;
    return fallback;
  }

  // Why a restore from Trash was refused (docs/design/delete_restore.md,
  // owner conditions 1, 2 and 4). The product is the name stored on the line.
  static String _restoreRefusal(RestoreRefusedException e) {
    final product = e.productName ?? '';
    return switch (e.reason) {
      RestoreRefusal.notEnoughStock =>
        L10n.current.trash_restoreNotEnoughStock(product, e.needed ?? 0, e.available ?? 0),
      RestoreRefusal.clientGone => L10n.current.trash_restoreClientGone,
      RestoreRefusal.productGone => L10n.current.trash_restoreProductGone(product),
    };
  }

  // firebase_storage reports its own codes on a plain FirebaseException:
  // 'unauthorized' is its permission-denied, and 'retry-limit-exceeded'
  // means the upload or download gave up after its retry window.
  static String _forCode(String code) => switch (code) {
        'permission-denied' || 'unauthorized' => noPermission,
        'unavailable' || 'network-request-failed' => noConnection,
        'deadline-exceeded' || 'retry-limit-exceeded' => tooSlow,
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
