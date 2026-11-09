import 'package:flutter_test/flutter_test.dart';

/// RV2b (the RV2a flake): waits until [ready] with BOTH clocks moving (real
/// time, then the fake timers, without drawing a frame), and
/// fails with [what] instead of hanging.
///
/// A provider made in the test body lives in the fake-async zone: its
/// microtasks run inside runAsync, but its timers (a Future(), a zero-length
/// Timer, a stream that delivers through one) fire only when the fake clock
/// is pumped. The old loops waited inside one runAsync until the provider
/// was ready; when its answer came through such a timer the loop spun until
/// the 10-minute test timeout, and the runAsync left pending made every later
/// test of the file fail with "Reentrant call to runAsync() denied" (one RV2a
/// run: 2 hangs, 13 more failures in the Trash and Facility details files).
Future<void> waitUntil(WidgetTester tester, bool Function() ready, {required String what, int maxRounds = 500}) async {
  for (var round = 0; !ready(); round++) {
    if (round == maxRounds) fail('$what: not ready after $maxRounds rounds');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1)));
    // Fake timers only, no frame: a tree already on screen (a second pump in
    // one test) must not rebuild while the next one is made.
    await tester.binding.delayed(Duration.zero);
  }
}
