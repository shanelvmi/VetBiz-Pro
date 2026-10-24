// DASH-1: a cached stream is listened to again when its widget is rebuilt
// somewhere else. shareLatest (and mergedLogStream, built on it) must give
// every listener, early or late, the latest value at once.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/utils/merged_query_stream.dart';

void main() {
  group('shareLatest', () {
    test('a listener that comes late gets the latest value at once, then the next ones', () async {
      final source = StreamController<int>();
      final shared = shareLatest(() => source.stream);
      final first = <int>[];
      final sub1 = shared.listen(first.add);
      source.add(1);
      await pumpEventQueue();

      final late = <int>[];
      final sub2 = shared.listen(late.add);
      await pumpEventQueue();
      expect(late, [1]);

      source.add(2);
      await pumpEventQueue();
      expect(first, [1, 2]);
      expect(late, [1, 2]);
      await sub1.cancel();
      await sub2.cancel();
    });

    test('when everyone has left the source is cancelled; the next listener opens it again and gets the latest first',
        () async {
      var opened = 0;
      var cancelled = 0;
      late StreamController<int> source;
      final shared = shareLatest(() {
        opened++;
        source = StreamController<int>(onCancel: () => cancelled++);
        return source.stream;
      });
      final sub = shared.listen((_) {});
      source.add(7);
      await pumpEventQueue();
      await sub.cancel();
      expect((opened, cancelled), (1, 1));

      final again = <int>[];
      final sub2 = shared.listen(again.add);
      await pumpEventQueue();
      expect(opened, 2);
      expect(again, [7]);
      source.add(8);
      await pumpEventQueue();
      expect(again, [7, 8]);
      await sub2.cancel();
    });

    test('a listener that comes after an error gets the error', () async {
      final source = StreamController<int>();
      final shared = shareLatest(() => source.stream);
      final sub = shared.listen((_) {}, onError: (_) {});
      source.addError(StateError('no access'));
      await pumpEventQueue();

      final errors = <Object>[];
      final sub2 = shared.listen((_) {}, onError: errors.add);
      await pumpEventQueue();
      expect(errors.single, isA<StateError>());
      await sub.cancel();
      await sub2.cancel();
    });
  });

  test('mergedLogStream: two listeners at the same time both get the merged list', () async {
    final fs = FakeFirebaseFirestore();
    final logs = fs.collection('logs');
    await logs.add({'userId': 'u1', 'timestamp': Timestamp.fromDate(DateTime(2026, 10, 1, 9))});
    await logs.add({'targetUserId': 'u1', 'timestamp': Timestamp.fromDate(DateTime(2026, 10, 1, 10))});
    final merged = mergedLogStream([
      logs.where('userId', isEqualTo: 'u1'),
      logs.where('targetUserId', isEqualTo: 'u1'),
    ]);

    final first = merged.first;
    final second = merged.first;
    expect((await first).length, 2);
    expect((await second).length, 2);
  });
}
