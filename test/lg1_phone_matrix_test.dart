import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/login_harness.dart';
import 'helpers/screen_size_matrix.dart';

// LG1, written before the change: the flat phone login at 360x740, 390x844
// and 740x360 (a phone turned sideways), in Light, Dark and Kiswahili, with
// no Updates, one and several: no overflow, no bright box in Dark, 48 px tap
// targets and no text under 12 px (the size matrix's checks).
const _skip = false;

const _sizes = [Size(360, 740), Size(390, 844), Size(740, 360)];

void main() {
  for (final size in _sizes) {
    for (final look in MatrixLook.values) {
      for (final count in [0, 1, 3]) {
        final where = '${size.width.toInt()}x${size.height.toInt()} ${look.name} $count';
        testWidgets(where, (tester) async {
          await pumpLogin(
            tester,
            await dbWithUpdates(count),
            width: size.width,
            height: size.height,
            brightness: look == MatrixLook.dark ? Brightness.dark : Brightness.light,
            locale: Locale(look == MatrixLook.kiswahili ? 'sw' : 'en'),
          );
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          await checkCase(tester, phone: true, where: 'login $where');
        }, skip: _skip);
      }
    }
  }
}
