import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

typedef LogDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Several queries, seen as ONE live list: newest first, each document once.
///
/// An assistant reads the activity log through two questions - "what did I do"
/// (userId) and "what is about me" (targetUserId). Firestore can't OR two
/// different fields in one query, and the security rule can only vouch for a
/// query that pins one of them down, so the app asks both and joins the
/// answers here.
///
/// Nothing is emitted until EVERY query has answered at least once, so the
/// list never shows half of itself and then jumps.
///
/// Safe to listen to more than once (DASH-1): a cached stream is listened to
/// again whenever its widget is rebuilt somewhere else (a resize moves the
/// dashboard's feed to another layout branch), so the result is
/// [shareLatest].
Stream<List<LogDoc>> mergedLogStream(List<Query<Map<String, dynamic>>> queries, {int? limit}) =>
    shareLatest(() => _mergeOnce(queries, limit));

Stream<List<LogDoc>> _mergeOnce(List<Query<Map<String, dynamic>>> queries, int? limit) {
  late final StreamController<List<LogDoc>> controller;
  final latest = <int, List<LogDoc>>{};
  final subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

  void emit() {
    // The same entry can match both questions (something you did that is also
    // about you): once.
    final byId = <String, LogDoc>{};
    for (final docs in latest.values) {
      for (final d in docs) {
        byId[d.id] = d;
      }
    }
    final merged = byId.values.toList()..sort((a, b) => _millis(b).compareTo(_millis(a)));
    controller.add(limit == null ? merged : merged.take(limit).toList());
  }

  controller = StreamController<List<LogDoc>>(
    onListen: () {
      for (var i = 0; i < queries.length; i++) {
        subscriptions.add(
          queries[i].snapshots().listen(
            (snapshot) {
              latest[i] = snapshot.docs;
              if (latest.length == queries.length) emit();
            },
            onError: controller.addError,
          ),
        );
      }
    },
    onCancel: () async {
      for (final s in subscriptions) {
        await s.cancel();
      }
    },
  );
  return controller.stream;
}

/// One live source shared by every listener, at any time (DASH-1).
///
/// A plain stream fails a widget that is rebuilt in another place with the
/// same cached stream: a single-subscription stream refuses the second
/// listener ("Stream has already been listened to"), and cloud_firestore's
/// own snapshots stream (a broadcast) gives the new listener nothing until
/// the data next changes, so the spinner never stops. Here each new listener
/// gets the latest value (or error) at once, then every later one. [open]
/// is called on the first listener, and again after all listeners have left
/// (the source is cancelled meanwhile, so nothing is read for nobody); the
/// latest value is still given first while the new answer comes.
Stream<T> shareLatest<T>(Stream<T> Function() open) {
  final listeners = <MultiStreamController<T>>{};
  StreamSubscription<T>? source;
  late T latest;
  var hasLatest = false;
  Object? error;
  StackTrace? errorStack;

  void forEach(void Function(MultiStreamController<T> l) send) {
    for (final l in [...listeners]) {
      send(l);
    }
  }

  return Stream<T>.multi((listener) {
    if (hasLatest) {
      listener.add(latest);
    } else if (error != null) {
      listener.addError(error!, errorStack);
    }
    listeners.add(listener);
    source ??= open().listen(
      (value) {
        latest = value;
        hasLatest = true;
        error = null;
        forEach((l) => l.add(value));
      },
      onError: (Object e, StackTrace st) {
        error = e;
        errorStack = st;
        hasLatest = false;
        forEach((l) => l.addError(e, st));
      },
      onDone: () {
        source = null;
        final done = [...listeners];
        listeners.clear();
        for (final l in done) {
          l.close();
        }
      },
    );
    listener.onCancel = () {
      listeners.remove(listener);
      if (listeners.isEmpty) {
        final s = source;
        source = null;
        return s?.cancel();
      }
      return null;
    };
  }, isBroadcast: true);
}

// An entry whose server timestamp hasn't landed yet counts as newest.
int _millis(LogDoc d) {
  final ts = d.data()['timestamp'];
  return ts is Timestamp ? ts.millisecondsSinceEpoch : DateTime.now().millisecondsSinceEpoch;
}
