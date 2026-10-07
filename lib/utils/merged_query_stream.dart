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
Stream<List<LogDoc>> mergedLogStream(List<Query<Map<String, dynamic>>> queries, {int? limit}) {
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

// An entry whose server timestamp hasn't landed yet counts as newest.
int _millis(LogDoc d) {
  final ts = d.data()['timestamp'];
  return ts is Timestamp ? ts.millisecondsSinceEpoch : DateTime.now().millisecondsSinceEpoch;
}
