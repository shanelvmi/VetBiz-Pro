import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/services/support_contact_store.dart';
import 'package:vetbiz_pro/services/updates_store.dart';

// Runs around every test file. G6, AN6: the support contact and the Updates
// store live for the whole app (a session), so each test starts
// with fresh ones instead of what an earlier test left behind. RV2b: so do
// the mock preferences. A test that reached SharedPreferences before setting
// its own values worked only after a test that had (its static platform
// store); run first, it asked the real platform channel, which never
// answers in a test (an6's "persisted copy" test hung with seed 4242).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SupportContactStore.debugReset();
    UpdatesStore.debugReset();
  });
  await testMain();
}
