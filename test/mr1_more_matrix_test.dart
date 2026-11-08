// MR1, written before the change: the redesigned More page at every size in
// Light, Dark and Kiswahili (and 360 at text 1.3), with a very long person
// and facility name, plus the phone held sideways (740 x 360): no overflow,
// 48 px targets, no text under 12 px. The page exists only in the phone
// shell; the wider sizes are the screen itself, as PH3's matrix did.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/more_screen.dart';

import 'helpers/screen_size_matrix.dart';

const _skip = true;

/// Through Function.apply until MR1's parameters exist.
Widget _page() => Function.apply(MoreScreen.new, const [], {
      #isAdmin: true,
      #isPlatformAdmin: true,
      #onOpen: (BuildContext _, MoreItem __) async {},
      #profileName: 'Mr. $matrixLongClientName',
      #profileAvatarUrl: null,
      #profileRoleLabel: 'Co-admin',
      #profileFacilityName: matrixLongFacilityName,
      #onProfile: () {},
    }) as Widget;

void main() {
  final stub = {for (final s in matrixSizes) for (final l in MatrixLook.values) matrixCase(s, l): 'MR1 not built yet', matrixTextScaleCase: 'MR1 not built yet'};
  screenSizeMatrix('More page MR1 (admin, platform, long names)', screen: _page, skip: _skip ? stub : const {});

  group('More page MR1 at 740x360 (a phone held sideways)', () {
    for (final look in MatrixLook.values) {
      testWidgets(look.name, (tester) async {
        await pumpAtSize(tester, screen: _page(), size: const Size(740, 360), look: look);
        await checkCase(tester, phone: true, where: '740x360 ${look.name}');
      }, skip: _skip);
    }
  });
}
