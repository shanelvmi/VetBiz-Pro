// UI4: the phone bar's trough made deeper and wider, cradling the round "+"
// with clear space all round (long S-curves, no bevel).
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_bar_shape.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';

import 'helpers/real_font.dart';
import 'helpers/ui4_shell.dart';

const _skip = false;

void main() {
  // The neighbours' labels are measured in a real font (helpers/real_font.dart).
  setUpAll(loadRealFont);

  group('the shape', () {
    for (final width in const [360.0, 390.0, 412.0]) {
      final size = Size(width, 98);
      final cx = width / 2;
      final path = phoneBarPath(size, centerX: cx);

      test('$width wide: at least 40 deep and 120 wide, open at the top, closed under it', () {
        expect(PhoneShellMetrics.troughDepth, greaterThanOrEqualTo(40));
        expect(PhoneShellMetrics.troughWidth, greaterThanOrEqualTo(120));
        expect(path.contains(Offset(cx, PhoneShellMetrics.troughDepth - 0.5)), isFalse, reason: 'in the trough');
        expect(path.contains(Offset(cx, PhoneShellMetrics.troughDepth + 0.5)), isTrue, reason: 'the bar under it');
        expect(path.contains(Offset(cx - PhoneShellMetrics.troughWidth / 2 - 2, 0.5)), isTrue, reason: 'flat top beside it');
        expect(path.contains(Offset(cx + PhoneShellMetrics.troughWidth / 2 + 2, 0.5)), isTrue);
        expect(path.contains(Offset(cx - PhoneShellMetrics.troughWidth / 2 + 20, 2)), isFalse, reason: 'its opening (the S-curve leaves the edge gently)');
      }, skip: _skip);

      test('$width wide: the button\'s circle is at least 8 from the wall at every point', () {
        final centre = Offset(cx, phoneTroughCentreY);
        expect(phoneTroughCentreY, closeTo(ui4R - PhoneShellMetrics.buttonRaise, 0.01));
        final points = ui4TroughPoints(path, cx, 0);
        expect(points.length, greaterThan(200));
        for (final p in points) {
          expect((p - centre).distance - ui4R, greaterThanOrEqualTo(PhoneShellMetrics.troughClearance - 0.01), reason: 'at $p');
        }
      }, skip: _skip);

      test('$width wide: no bevel: the edge never turns more than 6 degrees in half a pixel', () {
        final angles = [
          for (final PathMetric m in path.computeMetrics())
            for (var d = 0.0; d < m.length; d += 0.5)
              if (m.getTangentForOffset(d)!.position.dy < PhoneShellMetrics.troughDepth + 2 &&
                  m.getTangentForOffset(d)!.position.dx > PhoneShellMetrics.barRadius &&
                  m.getTangentForOffset(d)!.position.dx < width - PhoneShellMetrics.barRadius)
                m.getTangentForOffset(d)!.angle,
        ];
        expect(angles.length, greaterThan(500));
        for (var i = 1; i < angles.length; i++) {
          var turn = (angles[i] - angles[i - 1]).abs();
          if (turn > math.pi) turn = 2 * math.pi - turn;
          expect(turn, lessThan(6 * math.pi / 180), reason: 'at sample $i');
        }
      }, skip: _skip);
    }
  });

  for (final width in const [360.0, 390.0, 412.0]) {
    testWidgets('$width wide: the + centred, cradled, raised 14; its neighbours 12 from the trough', (tester) async {
      await ui4Shell(tester, size: Size(width, 844), realFont: true);
      final shape = tester.getRect(ui4Shape);
      final record = tester.getRect(ui4Record);
      expect(record.center.dx, closeTo(width / 2, 1));
      expect(shape.top - record.top, closeTo(PhoneShellMetrics.buttonRaise, 0.5));
      expect(record.center.dy - shape.top, closeTo(phoneTroughCentreY, 0.5));
      final points = ui4TroughPoints(phoneBarPath(shape.size, centerX: shape.width / 2).shift(shape.topLeft), width / 2, shape.top);
      for (final label in ['Sales', 'Products']) {
        final slot = find.ancestor(of: find.descendant(of: ui4Bar, matching: find.text(label)), matching: find.byType(Expanded));
        final icon = tester.getRect(find.descendant(of: slot, matching: find.byType(Icon))).deflate(ui4IconLiveInset);
        final text = tester.getRect(find.descendant(of: ui4Bar, matching: find.text(label)));
        // 12 from every point of the trough level with or below the item; the
        // points above it (where the curve leaves the flat edge) are never
        // closer than the bar's own top edge already is.
        for (final item in [icon, text]) {
          for (final p in points) {
            final least = p.dy >= item.top ? PhoneShellMetrics.troughItemGap : math.min(PhoneShellMetrics.troughItemGap, item.top - shape.top);
            expect(ui4Gap(item, p), greaterThanOrEqualTo(least - 0.1), reason: '$label ${item == icon ? 'icon' : 'label'} at $p');
          }
        }
      }
    }, skip: _skip);
  }

  testWidgets('the whole button takes the tap, its overhang too; the plus turns; Semantics unchanged', (tester) async {
    await ui4Shell(tester);
    final record = tester.getRect(ui4Record);
    expect(tester.getSize(find.bySemanticsLabel('Record')), const Size(56, 56));
    AnimatedRotation rotation() => tester.widget<AnimatedRotation>(find.descendant(of: ui4Record, matching: find.byType(AnimatedRotation)));
    expect(rotation().turns, 0);
    ui4Sheet = null;
    // Above the bar's top edge: outside the bar's box, still the button.
    await tester.tapAt(Offset(record.center.dx, record.top + 4));
    await tester.pumpAndSettle();
    expect(ui4Sheet, isNotNull);
    expect(rotation().turns, PhoneShellMetrics.recordOpenTurns);
    ui4Sheet!.complete();
    await tester.pumpAndSettle();
    expect(rotation().turns, 0);
  }, skip: _skip);

  testWidgets('the fill, the border and the shadow follow the new valley', (tester) async {
    await ui4Shell(tester);
    final colors = AppColors.fromTheme(AppColorTheme.pasture);
    final trough = Offset(195, PhoneShellMetrics.troughDepth - 4);
    final beside = Offset(195 - PhoneShellMetrics.troughWidth / 2 + 20, 4);
    const under = Offset(195, 60);
    const side = Offset(40, 30);
    expect(
      ui4Shape,
      paints
        ..path(includes: const [under, side], excludes: [trough, beside])
        ..path(includes: const [under, side], excludes: [trough, beside], color: colors.navBarFill)
        ..path(includes: const [under, side], excludes: [trough, beside], style: PaintingStyle.stroke),
    );
  }, skip: _skip);
}
