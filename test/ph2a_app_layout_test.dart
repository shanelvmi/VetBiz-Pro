import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/theme/app_breakpoints.dart';
import 'package:vetbiz_pro/theme/app_layout.dart';

// PH2a S1: one layout signal (docs/design/phone_foundations.md S1, and
// phone_shell.md section 3).
const _skip = false;

void main() {
  test('phones, portrait and landscape', () {
    for (final s in const [Size(360, 740), Size(390, 844), Size(844, 390), Size(740, 360)]) {
      expect(AppLayout.fromSize(s), AppLayout.phone, reason: '$s');
    }
  }, skip: _skip);

  test('tablets', () {
    for (final s in const [Size(600, 800), Size(768, 1024)]) {
      expect(AppLayout.fromSize(s), AppLayout.tablet, reason: '$s');
    }
  }, skip: _skip);

  test('desktop, including a short desktop window', () {
    for (final s in const [Size(1024, 768), Size(1200, 800), Size(1200, 550)]) {
      expect(AppLayout.fromSize(s), AppLayout.desktop, reason: '$s');
    }
  }, skip: _skip);

  test('the edges come from the tokens', () {
    expect(AppBreakpoints.phoneLandscapeHeight, 500);
    expect(AppLayout.fromSize(const Size(AppBreakpoints.compact - 1, 900)), AppLayout.phone);
    expect(AppLayout.fromSize(const Size(AppBreakpoints.compact, 900)), AppLayout.tablet);
    expect(AppLayout.fromSize(const Size(AppBreakpoints.expanded - 1, AppBreakpoints.phoneLandscapeHeight - 1)),
        AppLayout.phone);
    expect(AppLayout.fromSize(const Size(AppBreakpoints.expanded - 1, AppBreakpoints.phoneLandscapeHeight)),
        AppLayout.tablet);
    expect(AppLayout.fromSize(const Size(AppBreakpoints.expanded, 300)), AppLayout.desktop);
  }, skip: _skip);

  testWidgets('of and isPhone read the window size', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    late AppLayout layout;
    late bool phone;
    await tester.pumpWidget(Builder(builder: (context) {
      layout = AppLayout.of(context);
      phone = AppLayout.isPhone(context);
      return const SizedBox();
    }));
    expect(layout, AppLayout.phone);
    expect(phone, isTrue);

    tester.view.physicalSize = const Size(1200, 800);
    await tester.pump();
    expect(layout, AppLayout.desktop);
    expect(phone, isFalse);
  }, skip: _skip);

  test('the dashboard keeps its numbers (no behaviour change in PH2a)', () {
    expect(AppBreakpoints.sidebarMinHeight, 600);
    expect(AppBreakpoints.expanded, 1024);
    expect(AppBreakpoints.dashboardGridThree, 700);
    expect(AppBreakpoints.dashboardGridFour, 1200);
  });
}
