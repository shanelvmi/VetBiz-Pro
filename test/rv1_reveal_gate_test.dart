// RV1 (docs/design/screen_reveal.md section 2): the gate and its source
// adapters, on a fake clock.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

const _skip = true; // RV1: until the implementation

class _FakeTimer implements Timer {
  bool cancelled = false;
  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
}

class _FakeClock extends RevealClock {
  final timers = <(Duration, VoidCallback, _FakeTimer)>[];

  @override
  Timer start(Duration after, VoidCallback onFire) {
    final t = _FakeTimer();
    timers.add((after, onFire, t));
    return t;
  }

  void fire() {
    final (_, onFire, t) = timers.single;
    if (!t.cancelled) onFire();
  }
}

/// A provider with a spinner flag and a loaded flag, as the app's have.
class _Provider extends ChangeNotifier {
  bool isLoading = false;
  bool loaded = false;
  void set({bool? isLoading, bool? loaded}) {
    this.isLoading = isLoading ?? this.isLoading;
    this.loaded = loaded ?? this.loaded;
    notifyListeners();
  }
}

void main() {
  test('every primary source answered before the first frame: open at once, no timer', () {
    final clock = _FakeClock();
    final gate = RevealGate(primary: [ListenableRevealSource<bool>(ValueNotifier(true), (v) => v)], clock: clock);
    expect(gate.isOpen, isTrue);
    expect(gate.state, RevealState.revealed);
    expect(gate.openedBeforeFirstFrame, isTrue);
    gate.firstFrame();
    expect(clock.timers, isEmpty);
    gate.dispose();
  }, skip: _skip);

  test('two primary sources, one late: the gate opens at 1200 ms, the late one answers after', () {
    final clock = _FakeClock();
    final early = ValueNotifier(false), late = ValueNotifier(false);
    final gate = RevealGate(primary: [
      ListenableRevealSource<bool>(early, (v) => v),
      ListenableRevealSource<bool>(late, (v) => v),
    ], clock: clock);
    var notified = 0;
    gate.addListener(() => notified++);
    gate.firstFrame();
    expect(clock.timers.single.$1, AppTimeouts.revealGate);
    expect(AppTimeouts.revealGate, const Duration(milliseconds: 1200));
    early.value = true;
    expect(gate.isOpen, isFalse);
    clock.fire();
    expect(gate.state, RevealState.timedOut);
    expect(gate.openedBeforeFirstFrame, isFalse);
    late.value = true;
    expect(gate.state, RevealState.timedOut, reason: 'it never changes once open');
    expect(notified, 1);
    gate.dispose();
  }, skip: _skip);

  test('all answered after the first frame: revealed, and the timer is cancelled', () {
    final clock = _FakeClock();
    final a = ValueNotifier(false);
    final gate = RevealGate(primary: [ListenableRevealSource<bool>(a, (v) => v)], clock: clock);
    gate.firstFrame();
    a.value = true;
    expect(gate.state, RevealState.revealed);
    expect(clock.timers.single.$3.cancelled, isTrue);
    gate.firstFrame();
    expect(clock.timers, hasLength(1), reason: 'the wait starts once');
    gate.dispose();
  }, skip: _skip);

  test('an error counts as answered (stream and future)', () async {
    final controller = StreamController<int>();
    final stream = StreamRevealSource<int>(controller.stream);
    final errors = <Object>[];
    stream.stream.listen((_) {}, onError: errors.add);
    final failing = Completer<int>();
    final future = FutureRevealSource<int>(failing.future);
    failing.future.catchError((_) => 0);
    final gate = RevealGate(primary: [stream, future], clock: _FakeClock());
    controller.addError('offline');
    failing.completeError('denied');
    await Future<void>.delayed(Duration.zero);
    expect(errors, ['offline'], reason: 'the error still reaches the screen');
    expect(gate.state, RevealState.revealed);
    gate.dispose();
    await controller.close();
  }, skip: _skip);

  test('an empty result counts as answered (stream and future)', () async {
    final controller = StreamController<List<int>>();
    final stream = StreamRevealSource<List<int>>(controller.stream);
    final seen = <List<int>>[];
    stream.stream.listen(seen.add);
    final gate = RevealGate(primary: [stream, FutureRevealSource(Future.value(<int>[]))], clock: _FakeClock());
    controller.add([]);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [<int>[]]);
    expect(gate.state, RevealState.revealed);
    gate.dispose();
    await controller.close();
  }, skip: _skip);

  test('the stream adapter passes events through on the one subscription', () async {
    final controller = StreamController<int>();
    final source = StreamRevealSource<int>(controller.stream);
    final seen = <int>[];
    source.stream.listen(seen.add);
    controller
      ..add(1)
      ..add(2);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [1, 2]);
    expect(source.answered, isTrue);
    expect(() => controller.stream.listen((_) {}), throwsStateError, reason: 'no second subscription was made');
    await controller.close();
  }, skip: _skip);

  test('a spinner never answers: only the loaded flag does', () {
    final p = _Provider();
    final gate = RevealGate(primary: [SelectorRevealSource<_Provider>(p, (p) => p.loaded)], clock: _FakeClock());
    p.set(isLoading: true);
    expect(gate.isOpen, isFalse);
    p.set(isLoading: false);
    expect(gate.isOpen, isFalse);
    p.set(loaded: true);
    expect(gate.isOpen, isTrue);
    gate.dispose();
  }, skip: _skip);

  test('no primary source at all: open at once (a screen with nothing to wait for)', () {
    final gate = RevealGate(primary: const [], clock: _FakeClock());
    expect(gate.isOpen, isTrue);
    gate.dispose();
  }, skip: _skip);

  test('dispose cancels the wait and stops listening', () {
    final clock = _FakeClock();
    final a = ValueNotifier(false);
    final gate = RevealGate(primary: [ListenableRevealSource<bool>(a, (v) => v)], clock: clock);
    gate.firstFrame();
    gate.dispose();
    expect(clock.timers.single.$3.cancelled, isTrue);
    a.value = true;
    expect(gate.isOpen, isFalse);
  }, skip: _skip);
}
