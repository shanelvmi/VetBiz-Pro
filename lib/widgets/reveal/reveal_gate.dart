import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/app_timeouts.dart';

// RV1 (docs/design/screen_reveal.md): when a screen's content may be shown.
// Stubs first: the tests are written against this API and skipped until
// the implementation.

enum RevealState { pending, revealed, timedOut }

abstract class RevealClock {
  const RevealClock();

  Timer start(Duration after, VoidCallback onFire);
}

abstract class RevealSource {
  bool get answered => throw UnimplementedError();

  @protected
  void markAnswered() => throw UnimplementedError();

  void attach(VoidCallback onAnswered) => throw UnimplementedError();

  @mustCallSuper
  void dispose() => throw UnimplementedError();
}

class StreamRevealSource<T> extends RevealSource {
  StreamRevealSource(Stream<T> source);

  Stream<T> get stream => throw UnimplementedError();
}

class FutureRevealSource<T> extends RevealSource {
  FutureRevealSource(Future<T> future);
}

class ListenableRevealSource<T> extends RevealSource {
  ListenableRevealSource(ValueListenable<T> listenable, [bool Function(T value)? isAnswered]);
}

class SelectorRevealSource<P extends Listenable> extends RevealSource {
  SelectorRevealSource(P provider, bool Function(P provider) isAnswered);
}

class RevealGate extends ChangeNotifier {
  RevealGate({required List<RevealSource> primary, RevealClock? clock, this.timeout = AppTimeouts.revealGate});

  final Duration timeout;

  RevealState get state => throw UnimplementedError();
  bool get isOpen => throw UnimplementedError();
  bool get openedBeforeFirstFrame => throw UnimplementedError();

  void firstFrame() => throw UnimplementedError();
}
