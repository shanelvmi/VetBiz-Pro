// PH8b (2) P1 (docs/design/phone_facilities.md): the list of the person's
// facilities on phones, on the PH5a list: a pushed page with a back arrow,
// search (name or code), the status chips, Add Facility floating with today's
// limit guard, rows with a 40 px logo or initials, the name alone and the type
// only as its small tag with the status chip, no buttons; pull to refresh;
// the states; the size matrix with a very long facility name.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/screens/facilities/facility_screen.dart';
import 'package:vetbiz_pro/widgets/facility_type_tag.dart';
import 'package:vetbiz_pro/widgets/phone_list/record_tile.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/fake_storage.dart';
import 'helpers/ph8b_facilities.dart';
import 'helpers/ph8b_team.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

// True until Facilities has its phone list.
const _skip = true;

final _en = lookupAppLocalizations(const Locale('en'));
const _names = ['Kilimo Agrovet', 'Mifugo Clinic', 'Shamba Hub'];
const _ids = [testFacilityId, ph8bClinicId, ph8bOtherId];

Future<Ph5App> _pump(WidgetTester tester,
        {Size size = const Size(390, 844),
        MatrixLook look = MatrixLook.light,
        Future<void> Function(FirebaseFirestore fs)? seed,
        bool settle = true}) =>
    pumpPh5(tester, (fs) => FacilityScreen(firestore: fs, auth: Ph8bAuth(), storage: FakeStorage()),
        size: size, look: look, pushed: true, seed: seed ?? ph8bSeedFacilities, settle: settle);

Finder _row(String id) => find.byKey(ValueKey('phoneList-row-$id'));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  unawaited(Scrollable.ensureVisible(tester.element(f.first), alignment: 0.5));
  await tester.pump();
  await tester.tap(f.first);
  await _settle(tester);
}

/// The facilities the phone list shows, in order.
List<String> _phoneIds() => [for (final id in _ids) if (_row(id).evaluate().isNotEmpty) id];

/// The facilities today's list panel shows: each row is the InkWell holding
/// a name and its type tag.
List<String> _panelIds() => [
      for (final (i, name) in _names.indexed)
        if (find
            .ancestor(of: find.byType(FacilityTypeTag), matching: find.byType(InkWell))
            .evaluate()
            .any((row) => find.descendant(of: find.byWidget(row.widget), matching: find.text(name)).evaluate().isNotEmpty))
          _ids[i],
    ];

Future<void> _limit(FirebaseFirestore fs, int max) async {
  await ph8bSeedFacilities(fs);
  await fs.collection(Collections.platformConfig).doc('settings').set({'maxFacilitiesPerAdmin': max});
}

void main() {
  ph5TestWidgets('a pushed list: back arrow, title only, search, Add Facility floating, the status chips', (tester) async {
    await _pump(tester);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text(_en.facilities_subtitle), findsNothing);
    expect(find.byTooltip(_en.common_search), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('phoneList-fab')), matching: find.text(_en.facilities_addTitle)),
        findsOneWidget);
    for (final chip in [_en.common_all, 'Active', 'Inactive']) {
      expect(find.widgetWithText(ChoiceChip, chip), findsOneWidget, reason: chip);
    }
    // The 360 px list box and the details beside or under it are gone.
    expect(find.text(_en.facilities_moreActions), findsNothing);
    expect(_phoneIds(), _ids);
  }, skip: _skip);

  ph5TestWidgets('rows: a 40 px leading, the name alone, the type only as the tag, the status; no buttons', (tester) async {
    await _pump(tester);
    for (final (i, id) in _ids.indexed) {
      final row = _row(id);
      final tile = find.descendant(of: row, matching: find.byType(RecordTile));
      expect(tester.getSize(find.byKey(ValueKey('facility-leading-$id'))), const Size(40, 40));
      // Line 1 is the name exactly as typed, never joined with the type.
      final title = (tester.widget<RecordTile>(tile)).title;
      expect(title, _names[i]);
      final tag = find.descendant(of: row, matching: find.byType(FacilityTypeTag));
      expect(tag, findsOneWidget);
      final typeText = find.descendant(of: tag, matching: find.byType(Text));
      final typeLabel = (tester.widget<Text>(typeText)).data!;
      // The type's words appear only inside the tag.
      expect(find.descendant(of: row, matching: find.textContaining(typeLabel)).evaluate().length, 1, reason: id);
      expect(find.descendant(of: row, matching: find.byType(ButtonStyleButton)), findsNothing);
    }
    expect(find.descendant(of: _row(ph8bOtherId), matching: find.text('Kituo cha mafunzo')), findsOneWidget);
    expect(find.descendant(of: _row(ph8bOtherId), matching: find.text('Inactive')), findsOneWidget);
    expect(find.descendant(of: _row(testFacilityId), matching: find.text('Active')), findsOneWidget);
  }, skip: _skip);

  group('the chips and search equal today\'s list panel on the same data', () {
    final cases = <(String, Future<void> Function(WidgetTester) phone, Future<void> Function(WidgetTester) wide)>[
      ('All', (t) async {}, (t) async {}),
      for (final chip in ['Active', 'Inactive'])
        (chip, (t) => _tap(t, find.widgetWithText(ChoiceChip, chip)), (t) => _tap(t, find.text(chip).first)),
      for (final query in ['shamba', 'vbp-002'])
        (
          'search "$query"',
          (t) async {
            await _tap(t, find.byTooltip(_en.common_search));
            await t.enterText(find.byKey(const ValueKey('phoneList-searchField')), query);
            await _settle(t);
          },
          (t) async {
            await t.enterText(find.byType(TextField).first, query);
            await _settle(t);
          },
        ),
    ];
    for (final (name, phone, wide) in cases) {
      ph5TestWidgets(name, (tester) async {
        await _pump(tester, size: const Size(1200, 1600));
        await wide(tester);
        final expected = _panelIds();
        await _pump(tester);
        await phone(tester);
        expect(_phoneIds(), expected);
      }, skip: _skip);
    }
  });

  ph5TestWidgets('Add Facility keeps today\'s guard: at the limit, the limit message', (tester) async {
    await _pump(tester, seed: (fs) => _limit(fs, 3));
    await tester.tap(find.byKey(const ValueKey('phoneList-fab')));
    await _settle(tester);
    expect(find.text(_en.facilities_limitTitle), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('Add Facility with room opens the Add form', (tester) async {
    await _pump(tester, seed: (fs) => _limit(fs, 9));
    await tester.tap(find.byKey(const ValueKey('phoneList-fab')));
    await _settle(tester);
    expect(find.text(_en.facilities_limitTitle), findsNothing);
    expect(find.text(_en.facilities_addTitle), findsWidgets);
    expect(find.byType(TextField), findsWidgets);
  }, skip: _skip);

  ph5TestWidgets('a row opens that facility\'s details as a page, and back returns to the list', (tester) async {
    await _pump(tester);
    await _tap(tester, _row(ph8bClinicId));
    expect(find.byKey(const ValueKey('facility-details')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('facility-details')), matching: find.text('Mifugo Clinic')), findsWidgets);
    await tester.pageBack();
    await _settle(tester);
    expect(_phoneIds(), _ids);
  }, skip: _skip);

  group('states', () {
    ph5TestWidgets('six skeleton rows while loading', (tester) async {
      await _pump(tester, settle: false);
      expect(find.byKey(const ValueKey('phoneList-skeleton')), findsOneWidget);
    }, skip: _skip);

    ph5TestWidgets('none: today\'s sentence, and Add Facility', (tester) async {
      await _pump(tester, seed: (fs) => fs.collection(Collections.users).doc(testUserId).set({'role': 'admin', 'facilities': []}));
      expect(find.text(_en.facilities_noneFound), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('phoneList-empty')), matching: find.text(_en.facilities_addTitle)),
          findsOneWidget);
    }, skip: _skip);

    ph5TestWidgets('no match: today\'s sentence', (tester) async {
      await _pump(tester);
      await _tap(tester, find.byTooltip(_en.common_search));
      await tester.enterText(find.byKey(const ValueKey('phoneList-searchField')), 'nothing like this');
      await _settle(tester);
      expect(find.text(_en.facilities_noMatchFilter), findsOneWidget);
    }, skip: _skip);

    ph5TestWidgets('pull to refresh reads the facilities again (the old Refresh button)', (tester) async {
      final app = await _pump(tester);
      await tester.runAsync(() => app.fs.collection(Collections.users).doc(testUserId).update({
            'facilities': FieldValue.arrayUnion([
              {'facilityId': 'facility4', 'name': 'Mpya Vet', 'type': 'Vet Clinic', 'typeDetail': null},
            ]),
          }));
      expect(_row('facility4'), findsNothing);
      await tester.fling(find.byKey(const ValueKey('phoneList-scroll')), const Offset(0, 400), 1000);
      await _settle(tester);
      expect(_row('facility4'), findsOneWidget);
    }, skip: _skip);
  });

  for (final size in ph5PhoneSizes) {
    for (final look in MatrixLook.values) {
      final where = 'Facilities ${size.label} ${look.name}';
      ph5TestWidgets('$where, a very long facility name: the list; no overflow, 48 px, 12 px', (tester) async {
        await _pump(tester, size: size.size, look: look, seed: (fs) => ph8bSeedFacilities(fs, longNames: true));
        await checkCase(tester, phone: true, where: where);
        expect(find.text(matrixLongFacilityName), findsOneWidget);
      }, skip: _skip);
    }
  }
}
