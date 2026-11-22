// PH8b (3): the facility picker on phones. The picker's
// card (360 px ideal) lost its room at 360: a 24 px page gutter on top of the
// card's own 14 px padding, a staff-and-status row that overflows in
// Kiswahili, the header's tagline and the footer under 12 px and a 32 px
// account menu. On a phone: the 16 px gutter, the card's padding kept, the
// row wrapping, 12 px text and a 48 px menu. Wider windows keep today's
// picker: the ph8b-picker- fingerprints. (FIN1: Select Facility, which
// nothing routed to, was removed with its case here.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/facilities/facility_picker_screen.dart';

import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

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
      });

    }
  }

  // UX9: the redesigned card (lib/widgets/facility_pick_card.dart) keeps the
  // 16 px gutter; its own padding is 16 and its tile 48.
  ph5TestWidgets('at 360 the card keeps its room: a 16 px gutter and its own 16 px padding', (tester) async {
    await _picker(tester, const Size(360, 740), MatrixLook.light);
    final rect = tester.getRect(find.byKey(const ValueKey('facilityPickCard-f2')));
    expect(rect.left, 16);
    expect(rect.right, 360 - 16);
    final name = tester.getRect(find.text('Mifugo Clinic'));
    // 16 px padding, the 48 px tile and its 12 px gap before the name.
    expect(name.left - rect.left, 16 + 48 + 12);
  });
}
