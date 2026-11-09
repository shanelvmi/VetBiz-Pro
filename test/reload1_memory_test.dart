// RELOAD1: a reload in the same session keeps the dashboard of the SAME
// facility. The memory is tested through its seams (the session store, the
// session policy's "same session" answer). HUB1: the phone's tab is no longer
// remembered (the hub has no tabs); a reload opens Home.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/fields.dart';
import 'package:vetbiz_pro/services/active_facility_memory.dart';
import 'package:vetbiz_pro/services/session_policy.dart';

const _skip = false;

Map<String, dynamic> _facility(String id) => {Fields.facilityId: id, 'facilityName': 'Name of $id', 'facilityType': 'agrovet'};

final _two = [_facility('fac-a'), _facility('fac-b')];

/// A new app start: [sameSession] is a reload in the same tab.
MemorySessionStore _start({required bool sameSession, Map<String, String> stored = const {}}) {
  final store = MemorySessionStore()..values.addAll(stored);
  ActiveFacilityMemory.store = store;
  ActiveFacilityMemory.sessionStarted(sameSession: sameSession);
  return store;
}

void main() {
  tearDown(() => _start(sameSession: false));

  group('the memory', () {
    test('the stored value is only an id: no facility name, code or token (HUB1: no tab)', () {
      final store = _start(sameSession: false);
      ActiveFacilityMemory.remember('fac-b');
      expect(store.values, {ActiveFacilityMemory.facilityKey: 'fac-b'});
    }, skip: _skip);

    test('a reload with a remembered facility that is still one of theirs resumes it, once', () {
      _start(sameSession: true, stored: {ActiveFacilityMemory.facilityKey: 'fac-b'});
      expect(ActiveFacilityMemory.facilityToResume(_two)?[Fields.facilityId], 'fac-b');
      expect(ActiveFacilityMemory.facilityToResume(_two), isNull, reason: 'only the first decision after the reload');
    }, skip: _skip);

    test('a remembered facility no longer theirs (removed, deactivated, deleted) is forgotten: today\'s decision', () {
      final store = _start(sameSession: true, stored: {ActiveFacilityMemory.facilityKey: 'fac-gone'});
      expect(ActiveFacilityMemory.facilityToResume(_two), isNull);
      expect(store.values, isEmpty);
      _start(sameSession: true, stored: {ActiveFacilityMemory.facilityKey: 'fac-a'});
      expect(ActiveFacilityMemory.facilityToResume(const []), isNull, reason: 'no facility left at all');
    }, skip: _skip);

    test('nothing remembered: today\'s decision', () {
      _start(sameSession: true);
      expect(ActiveFacilityMemory.facilityToResume(_two), isNull);
    }, skip: _skip);

    test('a fresh session never resumes, and starts with nothing remembered', () {
      final store = _start(sameSession: false, stored: {ActiveFacilityMemory.facilityKey: 'fac-b'});
      expect(store.values, isEmpty);
      ActiveFacilityMemory.remember('fac-b');
      expect(ActiveFacilityMemory.facilityToResume(_two), isNull, reason: 'a sign-in in this session is not a reload');
    }, skip: _skip);

    test('opening a facility (picked, switched, refreshed) remembers it, the last one wins', () {
      final store = _start(sameSession: false);
      ActiveFacilityMemory.remember('fac-a');
      ActiveFacilityMemory.remember('fac-b');
      expect(store.values, {ActiveFacilityMemory.facilityKey: 'fac-b'});
    }, skip: _skip);

    test('forget clears the id', () {
      final store = _start(sameSession: true, stored: {ActiveFacilityMemory.facilityKey: 'fac-b'});
      ActiveFacilityMemory.forget();
      expect(store.values, isEmpty);
      expect(ActiveFacilityMemory.facilityToResume(_two), isNull);
    }, skip: _skip);

    test('the session policy tells the memory whether this start is the same session', () async {
      for (final markerSet in [true, false]) {
        bool? told;
        final policy = SessionPolicy(
          isWeb: true,
          marker: _Marker(markerSet),
          setSessionPersistence: () async {},
          restoredUserPresent: () async => true,
          signOut: () async {},
          onSessionKnown: (same) => told = same,
        );
        await policy.applyAtStart();
        expect(told, markerSet);
      }
    }, skip: _skip);
  });

}

class _Marker implements SessionMarker {
  _Marker(this.isSet);
  @override
  bool isSet;
  @override
  void set() => isSet = true;
}
