import 'dart:io';

import 'package:flutter/material.dart' hide Baseline;
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_tap_target.dart';

import '../tool/check_hardcoded.dart';

// PH2a S2: tap targets at least 48 x 48 on touch
// (docs/design/phone_foundations.md S2 and risk 7).
const _skip = true;

/// Pumps [child] under a theme for [platform] and returns its size.
Future<Size> _sizeOn(WidgetTester tester, TargetPlatform platform, Widget Function(BuildContext) child) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(platform: platform),
    home: Scaffold(
      body: Center(
        child: Builder(builder: (context) => KeyedSubtree(key: const Key('t'), child: child(context))),
      ),
    ),
  ));
  return tester.getSize(find.byKey(const Key('t')));
}

void main() {
  test('minTapTarget is 48', () {
    expect(AppSizes.minTapTarget, 48);
  }, skip: _skip);

  group('AppTapTarget', () {
    testWidgets('an icon button: compact with a mouse, 48 x 48 on touch', (tester) async {
      Widget button(BuildContext context) => IconButton(
            icon: const Icon(Icons.copy, size: 16),
            padding: EdgeInsets.zero,
            constraints: AppTapTarget.iconConstraints(context),
            onPressed: () {},
          );
      expect(await _sizeOn(tester, TargetPlatform.android, button), const Size(48, 48));
      expect(await _sizeOn(tester, TargetPlatform.iOS, button), const Size(48, 48));
      expect(await _sizeOn(tester, TargetPlatform.windows, button), const Size(16, 16), reason: 'as BoxConstraints() was');
    }, skip: _skip);

    testWidgets('a button squeezed into a narrow column gets 48 on touch', (tester) async {
      Widget cell(BuildContext context) => SizedBox(
            width: AppTapTarget.extent(context, 32),
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              padding: EdgeInsets.zero,
              constraints: AppTapTarget.iconConstraints(context),
              onPressed: () {},
            ),
          );
      expect(await _sizeOn(tester, TargetPlatform.android, cell), const Size(48, 48));
      expect((await _sizeOn(tester, TargetPlatform.windows, cell)).width, 32);
    }, skip: _skip);

    testWidgets('a radio: 48 on touch, as compact as before with a mouse', (tester) async {
      Widget radio(BuildContext context) => RadioGroup<bool>(
            groupValue: true,
            onChanged: (_) {},
            child: Radio<bool>(
              value: true,
              materialTapTargetSize: AppTapTarget.size(context),
              visualDensity: AppTapTarget.density(context),
            ),
          );
      expect(await _sizeOn(tester, TargetPlatform.android, radio), const Size(48, 48));
      final desktop = await _sizeOn(tester, TargetPlatform.windows, radio);
      expect(desktop, const Size(32, 32), reason: 'shrinkWrap + compact, as before');
    }, skip: _skip);

    testWidgets('a text button keeps its look; the touch area grows to 48 high', (tester) async {
      Widget text(BuildContext context) => TextButton(
            style: TextButton.styleFrom(minimumSize: Size.zero, tapTargetSize: AppTapTarget.size(context)),
            onPressed: () {},
            child: const Text('Remove'),
          );
      expect((await _sizeOn(tester, TargetPlatform.android, text)).height, greaterThanOrEqualTo(48));
      expect((await _sizeOn(tester, TargetPlatform.windows, text)).height, lessThan(48));
    }, skip: _skip);
  });

  group('the guard (R12, shrunk tap target)', () {
    GuardRule r12() => guardRules.firstWhere((r) => r.id == 'R12');

    test('sees each way of shrinking a target', () {
      final r = r12();
      expect(r.count('constraints: const BoxConstraints(),'), 1);
      expect(r.count('constraints: BoxConstraints(),'), 1);
      expect(r.count('visualDensity: VisualDensity.compact,'), 1);
      expect(r.count('materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,'), 1);
      expect(r.count('tapTargetSize: MaterialTapTargetSize.shrinkWrap,'), 1);
      expect(r.count('constraints: const BoxConstraints(minWidth: 28, minHeight: 28),'), 2);
    }, skip: _skip);

    test('leaves alone what does not shrink a target', () {
      final r = r12();
      expect(r.count('constraints: AppTapTarget.iconConstraints(context),'), 0);
      expect(r.count('constraints: const BoxConstraints(maxWidth: 400),'), 0);
      expect(r.count('constraints: const BoxConstraints(minWidth: 48, minHeight: 48),'), 0);
      expect(r.count('constraints: BoxConstraints(minHeight: 120),'), 0);
      expect(r.count('materialTapTargetSize: AppTapTarget.size(context),'), 0);
      expect(r.count('shrinkWrap: true,'), 0);
    }, skip: _skip);

    test('looks only in lib/screens', () {
      final r = r12();
      expect(r.onlyIn, ['lib/screens/']);
    }, skip: _skip);

    test('is at zero, and every allowlist entry has a reason', () {
      final baseline = Baseline.load(Directory.current)!;
      expect(baseline.counts['R12'], isEmpty, reason: 'R12 has no ratchet: fix or allowlist with a reason');
      final entries = baseline.allowlist.where((a) => a.rule == 'R12').toList();
      expect(entries, isNotEmpty);
      for (final a in entries) {
        expect(a.reason.trim(), isNotEmpty, reason: a.file);
      }
      // The operator console is not for customers (LATER).
      expect(entries.map((a) => a.file), contains('lib/screens/platform_admin/'));
    }, skip: _skip);
  });

  test('the 11 buttons the audit found no longer shrink themselves', () {
    // file, and a line that only the fixed code has.
    const fixed = {
      'lib/screens/sales/add_sale_screen.dart': 4,
      'lib/screens/facilities/facility_screen.dart': 3,
      'lib/screens/dashboard/dashboard_screen.dart': 1,
    };
    for (final e in fixed.entries) {
      final src = File(e.key).readAsStringSync();
      expect('AppTapTarget.'.allMatches(src).length, greaterThanOrEqualTo(e.value), reason: e.key);
    }
    // The two filled "add client" buttons (44 px with padding 10) drop
    // BoxConstraints() and keep their look: the theme pads them to 48 on touch.
    for (final f in ['lib/screens/sales/add_sale_screen.dart', 'lib/screens/services/add_edit_service_screen.dart']) {
      expect(File(f).readAsStringSync(), isNot(contains('constraints: const BoxConstraints()')), reason: f);
    }
  }, skip: _skip);
}
