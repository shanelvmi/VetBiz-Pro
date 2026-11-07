// AUTH-1: every NEW launch starts at the login (data protection). Before, on
// web FirebaseAuth kept its default LOCAL persistence, so someone who signed
// in once opened the app straight onto Select Facility or the dashboard for
// ever; "Remember Me" only ever kept the email.
//
// The policy is tested through its seams (the marker, the restored user, the
// sign-out). The start-up sign-out then goes through the real
// forceLogoutAndShowLogin on a front door like PH3's (the real
// SignedInHomeHost and activation over the fake Firestore).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/services/session_policy.dart';

const _skip = true;

class _Marker implements SessionMarker {
  _Marker(this.isSet);
  @override
  bool isSet;
  int writes = 0;
  @override
  void set() {
    isSet = true;
    writes++;
  }
}

/// The policy with every seam recorded in [calls].
SessionPolicy _policy({required bool web, required SessionMarker marker, required bool user, required List<String> calls}) =>
    SessionPolicy(
      isWeb: web,
      marker: marker,
      setSessionPersistence: () async => calls.add('persistence'),
      restoredUserPresent: () async {
        calls.add('user?');
        return user;
      },
      signOut: () async => calls.add('signOut'),
    );

void main() {
  setUp(MemorySessionMarker.resetForTest);

  group('the policy at start', () {
    test('web, marker missing, a user restored: signed out once, then the marker is written', () async {
      final calls = <String>[];
      final marker = _Marker(false);
      await _policy(web: true, marker: marker, user: true, calls: calls).applyAtStart();
      expect(calls.where((c) => c == 'signOut'), hasLength(1));
      expect(marker.isSet, isTrue);
    }, skip: _skip);

    test('web, marker present, a user restored (a reload): no sign-out', () async {
      final calls = <String>[];
      await _policy(web: true, marker: _Marker(true), user: true, calls: calls).applyAtStart();
      expect(calls, isNot(contains('signOut')));
    }, skip: _skip);

    test('web, marker missing, nobody restored: nothing happens, the marker is written', () async {
      final calls = <String>[];
      final marker = _Marker(false);
      await _policy(web: true, marker: marker, user: false, calls: calls).applyAtStart();
      expect(calls, isNot(contains('signOut')));
      expect(marker.writes, 1);
    }, skip: _skip);

    test('web: SESSION persistence is set first, before the restored user is looked at', () async {
      final calls = <String>[];
      await _policy(web: true, marker: _Marker(false), user: true, calls: calls).applyAtStart();
      expect(calls, ['persistence', 'user?', 'signOut']);
    }, skip: _skip);

    test('web: persistence failing still signs a leftover user out', () async {
      final calls = <String>[];
      final policy = SessionPolicy(
        isWeb: true,
        marker: _Marker(false),
        setSessionPersistence: () async => throw StateError('not supported'),
        restoredUserPresent: () async => true,
        signOut: () async => calls.add('signOut'),
      );
      await policy.applyAtStart();
      expect(calls, ['signOut']);
    }, skip: _skip);

    test('not web: every cold start signs out (in-memory flag), the same process does not again', () async {
      final calls = <String>[];
      await _policy(web: false, marker: MemorySessionMarker(), user: true, calls: calls).applyAtStart();
      expect(calls, ['user?', 'signOut'], reason: 'no persistence call off the web');
      calls.clear();
      await _policy(web: false, marker: MemorySessionMarker(), user: true, calls: calls).applyAtStart();
      expect(calls, isNot(contains('signOut')));
      MemorySessionMarker.resetForTest(); // the next cold start
      await _policy(web: false, marker: MemorySessionMarker(), user: true, calls: calls).applyAtStart();
      expect(calls, contains('signOut'));
    }, skip: _skip);

    test('main.dart applies the policy before runApp, so before AppEntryPoint listens; SESSION on web', () {
      final main = File('lib/main.dart').readAsStringSync();
      final apply = main.indexOf('.applyAtStart()');
      expect(apply, greaterThan(0));
      expect(apply, lessThan(main.indexOf('runApp(')));
      expect(apply, lessThan(main.indexOf('authStateChanges().listen')));
      final policy = File('lib/services/session_policy.dart').readAsStringSync();
      expect(policy, contains('setPersistence(Persistence.SESSION)'));
      expect(policy, contains('forceLogoutAndShowLogin'), reason: 'the one sign-out path, stack and providers cleaned');
    }, skip: _skip);
  });
}
