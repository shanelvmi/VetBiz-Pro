import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_timeouts.dart';

/// UX8: a live list's first answer, whole.
///
/// Firestore answers a listener twice when it opens: first from the local
/// cache (often only the few rows this device saw last time), then from the
/// server. Drawn as they came, a list showed a short half-list and then
/// jumped to the full one (the "bounce" on Activity Log and Recent
/// Submissions). Here a cache-only first answer is held back until the
/// server confirms one; the screen keeps its skeleton meanwhile. Offline,
/// the latest cached answer is let through after [offlineAfter], so the list
/// never hangs on its skeleton. After the first answer everything passes as
/// it comes. Errors pass at once.
Stream<S> holdCacheUntilServer<S>(
  Stream<S> source, {
  required bool Function(S event) isFromCache,
  Duration offlineAfter = AppTimeouts.cacheFallback,
}) {
  late final StreamController<S> controller;
  StreamSubscription<S>? subscription;
  Timer? fallback;
  var released = false;
  S? held;
  var holding = false;

  void release(S event) {
    released = true;
    holding = false;
    held = null;
    fallback?.cancel();
    controller.add(event);
  }

  controller = StreamController<S>(
    onListen: () {
      fallback = Timer(offlineAfter, () {
        if (!released && holding) release(held as S);
      });
      subscription = source.listen(
        (event) {
          if (released || !isFromCache(event)) {
            if (!released) {
              release(event);
            } else {
              controller.add(event);
            }
            return;
          }
          // A cache answer before the server's: kept, the latest one wins.
          held = event;
          holding = true;
          // The offline wait is over already: nothing to wait for.
          if (!(fallback?.isActive ?? false)) release(event);
        },
        onError: controller.addError,
        onDone: () {
          if (!released && holding) release(held as S);
          controller.close();
        },
      );
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () async {
      fallback?.cancel();
      await subscription?.cancel();
    },
  );
  return controller.stream;
}

/// [query]'s snapshots, through [holdCacheUntilServer]. Metadata changes are
/// asked for (no extra reads) so the server's confirmation arrives even when
/// the rows did not change.
Stream<QuerySnapshot<T>> serverFirstSnapshots<T>(Query<T> query, {Duration offlineAfter = AppTimeouts.cacheFallback}) =>
    holdCacheUntilServer(
      query.snapshots(includeMetadataChanges: true),
      isFromCache: (s) => s.metadata.isFromCache,
      offlineAfter: offlineAfter,
    );
