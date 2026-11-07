// PH8b-2: every part of Facilities past the list on a phone (P2 the page and
// each tab's page, P3 Add and Edit, P4 each sheet) at 360x740, 390x844 and
// 740x360, in Light, Dark and Kiswahili, with a very long facility name: no
// overflow, 48 px targets, no text under 12 px.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ph8b2_facility_page.dart';
import 'helpers/ph8b_facilities.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

// True until the phone page, forms and sheets are built.
const _skip = true;

/// The part's name, the platform limit it needs and how to open it from the
/// list (labels found by key or icon, the same in both languages).
final _parts = <(String, int, Future<void> Function(WidgetTester))>[
  ('details', 9, (t) => ph8b2OpenDetails(t)),
  for (final i in [1, 2, 3, 4, 5])
    ('tab $i', 9, (t) async {
      await ph8b2OpenDetails(t);
      await ph8b2OpenTab(t, i);
    }),
  ('add', 9, (t) => ph8b2Tap(t, find.byKey(const ValueKey('phoneList-fab')))),
  ('edit', 9, (t) async {
    await ph8b2OpenDetails(t);
    await _menuItem(t, 0);
  }),
  ('limit', 3, (t) => ph8b2Tap(t, find.byKey(const ValueKey('phoneList-fab')))),
  ('delete blocked', 9, (t) async {
    await ph8b2OpenDetails(t, ph8bClinicId);
    await _menuItem(t, -1);
  }),
  ('delete confirm', 9, (t) async {
    await ph8b2OpenDetails(t);
    await _menuItem(t, -1);
  }),
  ('status', 9, (t) => _settingsRow(t, 1)),
  ('retention', 9, (t) => _change(t, 0)),
  ('retention confirm', 9, (t) async {
    await _change(t, 0);
    await ph8b2Tap(t, find.byType(RadioListTile<int>).first);
  }),
  ('overdue', 9, (t) => _change(t, 1)),
];

/// The page's menu, then its [index]th item (-1 the last: Delete).
Future<void> _menuItem(WidgetTester tester, int index) async {
  await ph8b2Tap(tester, find.byKey(ph8b2Menu));
  final items = find.byWidgetPredicate((w) => w is PopupMenuItem<String>);
  await ph8b2Tap(tester, index < 0 ? items.last : items.at(index));
}

Future<void> _toSettings(WidgetTester tester) async {
  await ph8b2OpenDetails(tester);
  await ph8b2OpenTab(tester, 5);
}

/// The Settings page's [index]th action row (0 Edit details, 1 the status, 2
/// Delete).
Future<void> _settingsRow(WidgetTester tester, int index) async {
  await _toSettings(tester);
  await ph8b2Tap(tester, find.byKey(ValueKey('facility-settings-action-$index')));
}

/// The Settings page's [index]th Change button (0 retention, 1 overdue).
Future<void> _change(WidgetTester tester, int index) async {
  await _toSettings(tester);
  await ph8b2Tap(tester, find.byType(OutlinedButton).at(index));
}

void main() {
  for (final size in ph5PhoneSizes) {
    for (final look in MatrixLook.values) {
      for (final (part, limit, open) in _parts) {
        final where = 'Facilities $part ${size.label} ${look.name}';
        ph5TestWidgets('$where, a very long facility name: no overflow, 48 px, 12 px', (tester) async {
          await pumpPh8b2(tester, size: size.size, look: look, longNames: true, maxFacilities: limit);
          await open(tester);
          await checkCase(tester, phone: true, where: where);
          if (part == 'details') {
            expect(find.text(matrixLongFacilityName), findsWidgets);
            expect(find.byKey(ph8b2Header), findsOneWidget);
          }
        }, skip: _skip);
      }
    }
  }
}
