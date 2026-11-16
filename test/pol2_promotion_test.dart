// POL2 Step 2: the Subscription screen's active-promotion banner is a flat
// surface with a hairline border: no gradient, no glow. It keeps its content
// (the offer's name, the discount sentence, the offer icon now in primary)
// and the plans under it keep theirs. Phone and wide, Light and Dark, text
// scale 1.3.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/constants/subscription_plans.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';

import 'helpers/screen_size_matrix.dart' show MatrixLook;
import 'helpers/phone_list_harness.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;
import 'pol2_fingerprints_test.dart' show seedPromotion;

Finder get _banner => find.ancestor(of: find.byIcon(Icons.local_offer), matching: find.byType(Container)).first;

void main() {
  for (final (where, size) in [('phone', const Size(390, 844)), ('wide', const Size(1200, 800))]) {
    for (final look in [MatrixLook.light, MatrixLook.dark]) {
      ph5TestWidgets('$where ${look.name}: the promotion banner is flat, with its content', (tester) async {
        final modal = size.width >= 900;
        await pumpPh5(tester, (fs) => SubscriptionScreen(isModal: modal, firestore: fs, auth: Ph8Auth()),
            size: size, look: look, pushed: !modal, seed: seedPromotion);
        await ph5SettleUntil(tester, () => find.text('Harvest offer').evaluate().isNotEmpty);
        expect(tester.takeException(), isNull);
        final colors = Theme.of(tester.element(find.byType(SubscriptionScreen))).extension<AppColors>()!;
        expect(find.text('Harvest offer'), findsOneWidget);
        expect(find.text('10% off every plan - applied automatically below.'), findsOneWidget);
        final d = tester.widget<Container>(_banner).decoration! as BoxDecoration;
        expect(d.gradient, isNull);
        expect(d.boxShadow, anyOf(isNull, isEmpty));
        expect(d.color, colors.surface);
        expect((d.border! as Border).top.color, colors.border);
        expect(tester.widget<Icon>(find.byIcon(Icons.local_offer)).color, colors.primary);
        expect(tester.widget<Text>(find.text('Harvest offer')).style!.color, colors.textPrimary);
        // The plans keep their content (the discounted prices under the offer).
        expect(find.byType(RadioListTile<SubscriptionPlan>), findsWidgets);
      });
    }
  }

  ph5TestWidgets('phone at text scale 1.3: no overflow, the banner\'s words stay', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPh5(tester, (fs) => SubscriptionScreen(firestore: fs, auth: Ph8Auth()),
        size: const Size(360, 640), pushed: true, seed: seedPromotion);
    await ph5SettleUntil(tester, () => find.text('Harvest offer').evaluate().isNotEmpty);
    expect(tester.takeException(), isNull);
    expect(find.text('Harvest offer'), findsOneWidget);
  });
}
