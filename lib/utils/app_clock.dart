import 'package:flutter/foundation.dart';

/// HUB3 (7): the seam for "now" in code whose tests must not depend on the
/// real date. It is DateTime.now unless a test fixes it, so the app behaves
/// exactly as before; a test sets a fixed moment with [fix] and puts it back
/// with [reset] (test/helpers/test_clock.dart does both).
///
/// Code reads [now] where a test pins its date (the list date groups, the
/// "this week" and "last 30 days" ranges, report and payment dates). Other
/// code may keep DateTime.now: the source test only guards test files.
class AppClock {
  AppClock._();

  static DateTime Function() _now = DateTime.now;

  static DateTime now() => _now();

  /// Today at midnight, by [now].
  static DateTime today() {
    final at = _now();
    return DateTime(at.year, at.month, at.day);
  }

  @visibleForTesting
  static void fix(DateTime Function() now) => _now = now;

  @visibleForTesting
  static void reset() => _now = DateTime.now;
}
