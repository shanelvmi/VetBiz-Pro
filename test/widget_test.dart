import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/main.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';

void main() {
  // Pumping VetBizProApp itself is not possible here: its home,
  // AppEntryPoint, reads FirebaseAuth on start, and the test environment
  // has no initialised Firebase app (and no Firebase mocks). So this checks
  // what can be checked without Firebase: that the app-wide theme colours
  // still come from AppPalette.
  test('VetBizProApp brand colours come from AppPalette', () {
    expect(VetBizProApp.primaryDeepGreen, AppPalette.primary);
    expect(VetBizProApp.warmAmber, AppPalette.accent);
    expect(VetBizProApp.offWhite, AppPalette.background);
  });
}
