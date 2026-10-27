import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/services/support_contact_store.dart';
import 'package:vetbiz_pro/services/updates_last_known.dart';
import 'package:vetbiz_pro/services/updates_store.dart';

// Runs around every test file. G6: the support contact and the Updates'
// last-known state live for the whole app (a session), so each test starts
// with fresh ones instead of what an earlier test left behind.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    SupportContactStore.debugReset();
    UpdatesLastKnown.debugReset();
    UpdatesStore.debugReset();
  });
  await testMain();
}
