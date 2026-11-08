// RELOAD1: a reload in the same session keeps the dashboard of the SAME
// facility, and the phone's tab. The memory is tested through its seams (the
// session store, the session policy's "same session" answer); the phone tab
// on the real PhoneShell with stand-in tabs.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/fields.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_shell.dart';
import 'package:vetbiz_pro/services/active_facility_memory.dart';
import 'package:vetbiz_pro/services/session_policy.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

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

Future<void> _shell(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
    home: PhoneShell(
      home: (_) => const Text('home tab'),
      sales: (_) => const Text('sales tab'),
      products: (_) => const Text('products tab'),
      more: (_) => const Text('more tab'),
      onRecord: () {},
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => _start(sameSession: false));

  group('the memory', () {
    test('the stored value is only an id (and the tab name): no facility name, code or token', () {
      final store = _start(sameSession: false);
      ActiveFacilityMemory.remember('fac-b');
      ActiveFacilityMemory.rememberTab(PhoneTab.sales.name);
      expect(store.values, {ActiveFacilityMemory.facilityKey: 'fac-b', ActiveFacilityMemory.tabKey: 'sales'});
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
      final store = _start(sameSession: false, stored: {ActiveFacilityMemory.facilityKey: 'fac-b', ActiveFacilityMemory.tabKey: 'more'});
      expect(store.values, isEmpty);
      ActiveFacilityMemory.remember('fac-b');
      expect(ActiveFacilityMemory.facilityToResume(_two), isNull, reason: 'a sign-in in this session is not a reload');
    }, skip: _skip);

    test('opening a facility (picked, switched, refreshed) remembers it and opens the phone at Home', () {
      final store = _start(sameSession: false);
      ActiveFacilityMemory.remember('fac-a');
      ActiveFacilityMemory.rememberTab('more');
      ActiveFacilityMemory.remember('fac-b');
      expect(store.values, {ActiveFacilityMemory.facilityKey: 'fac-b'});
    }, skip: _skip);

    test('forget clears the id and the tab', () {
      final store = _start(sameSession: true, stored: {ActiveFacilityMemory.facilityKey: 'fac-b', ActiveFacilityMemory.tabKey: 'more'});
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

  group('the phone tab', () {
    testWidgets('after a resumed reload the shell opens on the remembered tab', (tester) async {
      _start(sameSession: true, stored: {ActiveFacilityMemory.facilityKey: 'fac-b', ActiveFacilityMemory.tabKey: 'products'});
      ActiveFacilityMemory.facilityToResume(_two);
      ActiveFacilityMemory.resumed();
      await _shell(tester);
      expect(find.text('products tab'), findsOneWidget);
      expect(find.text('home tab'), findsNothing, reason: 'Home is not built until it is visited');
    }, skip: _skip);

    for (final stale in ['stale', '7', '']) {
      testWidgets('a stale tab value "$stale" falls back to Home', (tester) async {
        _start(sameSession: true, stored: {ActiveFacilityMemory.facilityKey: 'fac-b', ActiveFacilityMemory.tabKey: stale});
        ActiveFacilityMemory.facilityToResume(_two);
        ActiveFacilityMemory.resumed();
        await _shell(tester);
        expect(find.text('home tab'), findsOneWidget);
      }, skip: _skip);
    }

    testWidgets('not a resume (a sign-in, a switch): Home, whatever is stored', (tester) async {
      _start(sameSession: false);
      ActiveFacilityMemory.remember('fac-a');
      ActiveFacilityMemory.rememberTab('more');
      await _shell(tester);
      expect(find.text('home tab'), findsOneWidget);
    }, skip: _skip);

    testWidgets('choosing a tab remembers it', (tester) async {
      final store = _start(sameSession: false);
      await _shell(tester);
      await tester.tap(find.descendant(of: find.byType(PhoneBottomBar), matching: find.text('Sales')));
      await tester.pumpAndSettle();
      expect(store.values[ActiveFacilityMemory.tabKey], 'sales');
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
