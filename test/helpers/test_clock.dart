// HUB3 (7): the one place a test may read the real clock. Tests use the fixed
// [testNow] for dates, and [fixTestClock] to make the app's AppClock read it
// too, so a test's dates and the code's "today" are the same day whatever
// the real date is. [wallClock] is the real time, only for what is not a
// date a test checks (a server-time stand-in in the fake Firestore, a
// "written after this moment" bound): test/no_wall_clock_test.dart refuses
// the real clock anywhere else under test/.
// ignore: depend_on_referenced_packages
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/utils/app_clock.dart';

/// Wednesday 11 November 2026, 10:30: a mid-week, mid-month, mid-morning
/// moment, so this week, this month and today all hold earlier days and
/// hours.
final testNow = DateTime(2026, 11, 11, 10, 30);

/// [testNow]'s day at midnight.
final testToday = DateTime(testNow.year, testNow.month, testNow.day);

/// [testToday] at [hour]:[minute].
DateTime testAt(int hour, [int minute = 0]) => DateTime(testNow.year, testNow.month, testNow.day, hour, minute);

/// Makes AppClock read [at] (default [testNow]) for the rest of the test.
/// (flutter_test_config.dart already fixes it at [testNow] before each test.)
void fixTestClock([DateTime? at]) {
  final fixed = at ?? testNow;
  AppClock.fix(() => fixed);
  addTearDown(() => AppClock.fix(() => testNow));
}

/// The real time. Never for a date a test compares.
DateTime wallClock() => DateTime.now();

/// The fake Firestore's server clock, reading AppClock (newFakeFirestore).
final testFirestoreClock = Clock(AppClock.now);
