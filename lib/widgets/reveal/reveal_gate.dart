import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/app_timeouts.dart';

// RV1 (docs/design/screen_reveal.md): when a screen's content may be shown.
// A source answers on its first data, an empty result or an error, never on
// a spinner; the gate opens when every primary source has answered, or
// [AppTimeouts.revealGate] after the first frame. A source adds no Firestore
// listener or read: it watches something the screen already has.

enum RevealState { pending, revealed, timedOut }

/// The gate's one timer, behind a seam so a test can fire it by hand.
abstract class RevealClock {
  const RevealClock();

  Timer start(Duration after, VoidCallback onFire);
}

class _RealClock extends RevealClock {
  const _RealClock();

  @override
  Timer start(Duration after, VoidCallback onFire) => Timer(after, onFire);
}

/// Something the reveal waits for. [answered] turns true once and stays.
abstract class RevealSource {
  bool _answered = false;
  VoidCallback? _onAnswered;

  bool get answered => _answered;

  @protected
  void markAnswered() {
    if (_answered) return;
    _answered = true;
    _onAnswered?.call();
  }

  /// Called by the gate; [onAnswered] runs once, when it answers.
  void attach(VoidCallback onAnswered) => _onAnswered = onAnswered;

  @mustCallSuper
  void dispose() => _onAnswered = null;
}

/// A stream the screen listens to anyway: listen to [stream] instead of the
/// original (the same events, passed through), so there is no second
/// subscription. Its first event, error or end answers.
class StreamRevealSource<T> extends RevealSource {
  StreamRevealSource(Stream<T> source) {
    stream = source.transform(StreamTransformer<T, T>.fromHandlers(
      handleData: (data, sink) {
        markAnswered();
        sink.add(data);
      },
      handleError: (error, stack, sink) {
        markAnswered();
        sink.addError(error, stack);
      },
      handleDone: (sink) {
        markAnswered();
        sink.close();
      },
    ));
  }

  late final Stream<T> stream;
}

/// A future the screen already awaits: its value or its error answers.
class FutureRevealSource<T> extends RevealSource {
  FutureRevealSource(Future<T> future) {
    future.then<void>((_) => markAnswered(), onError: (Object _, StackTrace __) => markAnswered());
  }
}

/// A notifier the screen sets: answered once [isAnswered] holds for its
/// value (by default, once the value is not null).
class ListenableRevealSource<T> extends RevealSource {
  ListenableRevealSource(this._listenable, [bool Function(T value)? isAnswered])
      : _isAnswered = isAnswered ?? ((v) => v != null) {
    _check();
    if (!answered) _listenable.addListener(_check);
  }

  final ValueListenable<T> _listenable;
  final bool Function(T value) _isAnswered;

  void _check() {
    if (!_isAnswered(_listenable.value)) return;
    _listenable.removeListener(_check);
    markAnswered();
  }

  @override
  void dispose() {
    _listenable.removeListener(_check);
    super.dispose();
  }
}

/// A provider (any Listenable) the screen already reads: answered once
/// [isAnswered] holds for it, for example `(p) => p.loaded`.
class SelectorRevealSource<P extends Listenable> extends RevealSource {
  SelectorRevealSource(this._provider, this._isAnswered) {
    _check();
    if (!answered) _provider.addListener(_check);
  }

  final P _provider;
  final bool Function(P provider) _isAnswered;

  void _check() {
    if (!_isAnswered(_provider)) return;
    _provider.removeListener(_check);
    markAnswered();
  }

  @override
  void dispose() {
    _provider.removeListener(_check);
    super.dispose();
  }
}

/// Owns a screen's primary sources and decides when its content shows.
/// Secondary sources are never given to it: they fill late slots.
class RevealGate extends ChangeNotifier {
  RevealGate({
    required List<RevealSource> primary,
    RevealClock clock = const _RealClock(),
    this.timeout = AppTimeouts.revealGate,
  })  : _primary = List.unmodifiable(primary),
        _clock = clock {
    for (final s in _primary) {
      s.attach(_onAnswered);
    }
    if (_allAnswered) {
      _state = RevealState.revealed;
      _openedBeforeFirstFrame = true;
    }
  }

  final List<RevealSource> _primary;
  final RevealClock _clock;
  final Duration timeout;

  RevealState _state = RevealState.pending;
  bool _openedBeforeFirstFrame = false;
  Timer? _timer;
  bool _disposed = false;

  RevealState get state => _state;
  bool get isOpen => _state != RevealState.pending;

  /// Every primary source had answered when the gate was made: the content
  /// shows at once, with no skeleton and no rise.
  bool get openedBeforeFirstFrame => _openedBeforeFirstFrame;

  bool get _allAnswered => _primary.every((s) => s.answered);

  /// The screen's first frame (with the skeleton drawn): starts the
  /// [timeout], once.
  void firstFrame() {
    if (_disposed || isOpen || _timer != null) return;
    _timer = _clock.start(timeout, () => _open(RevealState.timedOut));
  }

  void _onAnswered() {
    if (_allAnswered) _open(RevealState.revealed);
  }

  void _open(RevealState to) {
    if (_disposed || isOpen) return;
    _timer?.cancel();
    _state = to;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final s in _primary) {
      s.dispose();
    }
    super.dispose();
  }
}
