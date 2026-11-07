// PH8b: tablets and computers keep today's screens exactly. At 768x1024,
// 1024x768 and 1200x800 the whole window (the page and anything open over it)
// is compared with the fingerprint recorded from the code before PH8b
// (test/fixtures/ph5a_wide_fingerprints.json, the ph8b- names): Team Members
// (the list, the details, every confirmation and picker), Facilities (the
// list with the details, each tab, every dialog) and the facility picker and
// Select Facility. Today's overflows in the square test font are part of the
// fingerprint, so they must not change either.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/screens/facilities/facility_picker_screen.dart';
import 'package:vetbiz_pro/screens/facilities/facility_screen.dart';
import 'package:vetbiz_pro/screens/facilities/select_facility_screen.dart';

import 'helpers/fake_storage.dart';
import 'helpers/ph8b_facilities.dart';
import 'helpers/ph8b_team.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/tree_fingerprint.dart';

final _en = lookupAppLocalizations(const Locale('en'));

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

/// The whole window: the page and every route, dialog and sheet over it.
void _expect(WidgetTester tester, String name, GlobalKey<NavigatorState> navigator) =>
    expectSameFingerprint(name, '${_errors(tester)}${treeFingerprint(tester, find.byKey(navigator))}');

Future<void> _tap(WidgetTester tester, Finder f) async {
  // Centred: a plain ensureVisible can leave it under the app bar.
  unawaited(Scrollable.ensureVisible(tester.element(f.first), alignment: 0.5));
  await tester.pump();
  await tester.tap(f.first, warnIfMissed: false);
  // Longer than ph5Settle: Delete Facility first asks the database afresh
  // who is still in the facility.
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The row (wide) or card (narrow) of one team member.
Finder _member(String id, String text) => find.descendant(of: find.byKey(ValueKey(id)), matching: find.text(text));

Widget _facilityScreen(FirebaseFirestore fs) => FacilityScreen(firestore: fs, auth: Ph8bAuth(), storage: FakeStorage());

Future<void> _limitedTo3(FirebaseFirestore fs) async {
  await ph8bSeedFacilities(fs);
  await fs.collection(Collections.platformConfig).doc('settings').set({'maxFacilitiesPerAdmin': 3});
}

Future<void> _roomFor9(FirebaseFirestore fs) async {
  await ph8bSeedFacilities(fs);
  await fs.collection(Collections.platformConfig).doc('settings').set({'maxFacilitiesPerAdmin': 9});
}

const _pickerItems = <Map<String, dynamic>>[
  {'facilityId': 'f1', 'facilityName': 'Kilimo Agrovet', 'facilityType': 'Agrovet', 'facilityTypeDetail': null},
  {'facilityId': 'f2', 'facilityName': 'Mifugo Clinic', 'facilityType': 'Vet Clinic', 'facilityTypeDetail': null},
  {'facilityId': 'f3', 'facilityName': 'Shamba Hub', 'facilityType': 'Other', 'facilityTypeDetail': 'Kituo cha mafunzo'},
];

void main() {
  for (final size in ph5WideSizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';

    // ==================== TEAM MEMBERS ====================

    final team = <(String, Future<void> Function(WidgetTester))>[
      ('list', (_) async {}),
      ('details', (t) => _tap(t, _member('a2', 'Neema Active'))),
      ('reject', (t) => _tap(t, _member('a1', _en.team_reject))),
      ('remove', (t) async {
        // The sixth person: below the fold of the lazy list.
        await t.scrollUntilVisible(_member('a3', _en.team_removeFromFacility), 60,
            scrollable: find.ancestor(of: find.byKey(const ValueKey('a2')), matching: find.byType(Scrollable)).first);
        await _tap(t, _member('a3', _en.team_removeFromFacility));
      }),
      ('reassign', (t) => _tap(t, _member('a2', _en.team_reassign))),
      ('coadmin-deactivate', (t) => _tap(t, _member(ph8bCoAdminId, _en.team_deactivate))),
      ('invite-to', (t) => _tap(t, find.text(_en.team_inviteAssistant))),
    ];
    for (final (name, open) in team) {
      ph5TestWidgets('ph8b-team-$name-$at: as before PH8b', (tester) async {
        final app = await pumpPh5(tester, (fs) => ph8bTeamScreen(fs), size: size, pushed: true, seed: ph8bSeedTeam);
        await open(tester);
        _expect(tester, 'ph8b-team-$name-$at', app.navigator);
      });
    }

    ph5TestWidgets('ph8b-team-coadmin-view-$at: what a Co-admin sees, as before PH8b', (tester) async {
      final app = await pumpPh5(tester, (fs) => ph8bTeamScreen(fs, uid: ph8bCoAdminId), size: size, pushed: true, seed: ph8bSeedTeam);
      _expect(tester, 'ph8b-team-coadmin-view-$at', app.navigator);
    });

    // ==================== FACILITIES ====================

    Future<void> settingsTab(WidgetTester t) => _tap(t, find.text(_en.settings_title));
    final facility = <(String, Future<void> Function(FirebaseFirestore), Future<void> Function(WidgetTester))>[
      ('list', ph8bSeedFacilities, (_) async {}),
      ('tab-team', ph8bSeedFacilities, (t) => _tap(t, find.text(_en.team_title))),
      ('tab-inventory', ph8bSeedFacilities, (t) => _tap(t, find.text(_en.facilities_tabInventory))),
      ('tab-sales', ph8bSeedFacilities, (t) => _tap(t, find.text(_en.facilities_tabSales))),
      ('tab-activity', ph8bSeedFacilities, (t) => _tap(t, find.text(_en.export_activityLog))),
      ('tab-settings', ph8bSeedFacilities, settingsTab),
      ('more-menu', ph8bSeedFacilities, (t) => _tap(t, find.text(_en.facilities_moreActions))),
      ('add', _roomFor9, (t) => _tap(t, find.text(_en.facilities_addTitle))),
      ('add-limit', _limitedTo3, (t) => _tap(t, find.text(_en.facilities_addTitle))),
      ('edit', ph8bSeedFacilities, (t) async {
        await _tap(t, find.text(_en.facilities_moreActions));
        await _tap(t, find.text(_en.facilities_editTitle).last);
      }),
      ('delete-confirm', ph8bSeedFacilities, (t) async {
        await _tap(t, find.text(_en.facilities_moreActions));
        await _tap(t, find.text(_en.facilities_deleteTitle).last);
      }),
      ('delete-blocked', ph8bSeedFacilities, (t) async {
        await _tap(t, find.text('Mifugo Clinic'));
        await _tap(t, find.text(_en.facilities_moreActions));
        await _tap(t, find.text(_en.facilities_deleteTitle).last);
      }),
      ('status', ph8bSeedFacilities, (t) async {
        await settingsTab(t);
        await _tap(t, find.text(_en.facilities_deactivateThis));
      }),
      ('retention', ph8bSeedFacilities, (t) async {
        await settingsTab(t);
        await _tap(t, find.text(_en.common_change));
      }),
      ('retention-confirm', ph8bSeedFacilities, (t) async {
        await settingsTab(t);
        await _tap(t, find.text(_en.common_change));
        await _tap(t, find.byType(RadioListTile<int>));
      }),
      ('overdue', ph8bSeedFacilities, (t) async {
        await settingsTab(t);
        await _tap(t, find.text(_en.common_change).last);
      }),
    ];
    for (final (name, seed, open) in facility) {
      ph5TestWidgets('ph8b-facilities-$name-$at: as before PH8b', (tester) async {
        final app = await pumpPh5(tester, _facilityScreen, size: size, pushed: true, seed: seed);
        await open(tester);
        _expect(tester, 'ph8b-facilities-$name-$at', app.navigator);
      });
    }

    // ==================== THE PICKERS ====================

    ph5TestWidgets('ph8b-picker-$at: the facility picker, as before PH8b', (tester) async {
      final app = await pumpPh5(tester, (_) => FacilityPickerScreen(facilities: _pickerItems, role: 'admin'), size: size);
      _expect(tester, 'ph8b-picker-$at', app.navigator);
    });

    ph5TestWidgets('ph8b-select-$at: Select Facility, as before PH8b', (tester) async {
      final app = await pumpPh5(tester, (_) => const Scaffold(body: Text('UNDER')), size: size, settle: false);
      app.navigator.currentState!.push(MaterialPageRoute<void>(
        settings: RouteSettings(arguments: {
          'facilities': [
            for (final f in _pickerItems)
              {'facilityId': f['facilityId'], 'name': f['facilityName'], 'type': f['facilityType'], 'typeDetail': f['facilityTypeDetail']},
          ],
          'role': 'admin',
        }),
        builder: (_) => const SelectFacilityScreen(),
      ));
      await ph5Settle(tester);
      _expect(tester, 'ph8b-select-$at', app.navigator);
    });
  }
}
