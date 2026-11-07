// PH8b (3): the facility picker and Select Facility on phones. The picker's
// card (360 px ideal) lost its room at 360: a 24 px page gutter on top of the
// card's own 14 px padding, a staff-and-status row that overflows in
// Kiswahili, the header's tagline and the footer under 12 px and a 32 px
// account menu. On a phone: the 16 px gutter, the card's padding kept, the
// row wrapping, 12 px text and a 48 px menu. Select Facility already passes
// the size matrix (it runs here, so it stays that way). Wider windows keep
// today's picker: the ph8b-picker- fingerprints.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/facilities/facility_picker_screen.dart';
import 'package:vetbiz_pro/screens/facilities/select_facility_screen.dart';

import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

// Was true until the picker's phone fixes existed.
const _skipPicker = false;

const _items = <Map<String, dynamic>>[
  {'facilityId': 'f1', 'facilityName': matrixLongFacilityName, 'facilityType': 'Agrovet', 'facilityTypeDetail': null},
  {'facilityId': 'f2', 'facilityName': 'Mifugo Clinic', 'facilityType': 'Vet Clinic', 'facilityTypeDetail': null},
  {'facilityId': 'f3', 'facilityName': 'Shamba Hub', 'facilityType': 'Other', 'facilityTypeDetail': 'Kituo cha mafunzo'},
];

Future<void> _picker(WidgetTester tester, Size size, MatrixLook look) =>
    pumpPh5(tester, (_) => FacilityPickerScreen(facilities: _items, role: 'admin'), size: size, look: look);

void main() {
  for (final size in ph5PhoneSizes) {
    for (final look in MatrixLook.values) {
      final where = '${size.label} ${look.name}';
      ph5TestWidgets('the picker at $where, several facilities and a very long name: no overflow, 48 px, 12 px',
          (tester) async {
        await _picker(tester, size.size, look);
        await checkCase(tester, phone: true, where: 'picker $where');
      }, skip: _skipPicker);

      ph5TestWidgets('Select Facility at $where: no overflow, 48 px, 12 px', (tester) async {
        final app = await pumpPh5(tester, (_) => const Scaffold(body: Text('UNDER')), size: size.size, look: look, settle: false);
        app.navigator.currentState!.push(MaterialPageRoute<void>(
          settings: RouteSettings(arguments: {
            'facilities': [
              for (final f in _items)
                {'facilityId': f['facilityId'], 'name': f['facilityName'], 'type': f['facilityType'], 'typeDetail': f['facilityTypeDetail']},
            ],
            'role': 'admin',
          }),
          builder: (_) => const SelectFacilityScreen(),
        ));
        await ph5Settle(tester);
        await checkCase(tester, phone: true, where: 'select $where');
      });
    }
  }

  ph5TestWidgets('at 360 the card keeps its room: a 16 px gutter and its own 14 px padding', (tester) async {
    await _picker(tester, const Size(360, 740), MatrixLook.light);
    final card = find.ancestor(of: find.text('Mifugo Clinic'), matching: find.byType(Stack)).first;
    final rect = tester.getRect(card);
    // The 16 px gutter, then the card's 1 px border.
    expect(rect.left, 16 + 1);
    expect(rect.right, 360 - 16 - 1);
    final name = tester.getRect(find.text('Mifugo Clinic'));
    // 14 px padding, the 56 px logo and its 12 px gap before the name.
    expect(name.left - rect.left, 14 + 56 + 12);
  }, skip: _skipPicker);
}
