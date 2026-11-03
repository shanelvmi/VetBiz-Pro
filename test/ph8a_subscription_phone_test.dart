// PH8a (3): Subscription on phones: one column, the plans stacked, the PH6
// form shell (Submit in the FormActionBar, the discard check), 48 px targets
// and text 12 px or more at 360x740, 390x844 and 740x360 in Light, Dark and
// Kiswahili with a very long facility name; the history list built once (a
// rebuild does not listen again, the DASH-1 lesson); the history page too.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_history_screen.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';
import 'package:vetbiz_pro/widgets/phone_form/form_action_bar.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/fake_firestore.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;
import 'ph8a_subscription_wide_test.dart' show seedSubscription;

// True until the phone layout exists.
const _skip = false;

Future<Ph5App> _pump(WidgetTester tester, {Size size = const Size(390, 844), MatrixLook look = MatrixLook.light,
    bool pending = false, CountingFirestore? firestore}) async {
  final app = await pumpPh5(tester, (fs) => SubscriptionScreen(firestore: fs, auth: Ph8Auth()),
      size: size, look: look, pushed: true, firestore: firestore, seed: (fs) => seedSubscription(fs, pending: pending));
  return app;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'facilityName': matrixLongFacilityName}));

  for (final size in ph5PhoneSizes) {
    for (final look in MatrixLook.values) {
      for (final pending in [false, true]) {
        final where = '${size.label} ${look.name}${pending ? ' pending' : ''}';
        ph5TestWidgets('Subscription at $where: no overflow, 48 px targets, text 12 px or more', (tester) async {
          await _pump(tester, size: size.size, look: look, pending: pending);
          await checkCase(tester, phone: true, where: where);
          await tester.scrollUntilVisible(find.byType(Card).last, 300, scrollable: find.byType(Scrollable).first);
          await checkCase(tester, phone: true, where: '$where, scrolled');
        }, skip: _skip);
      }
      ph5TestWidgets('the history page at ${size.label} ${look.name}', (tester) async {
        await pumpPh5(
            tester,
            (fs) => SubscriptionHistoryScreen(facilityId: testFacilityId, primaryColor: Colors.teal, firestore: fs),
            size: size.size,
            look: look,
            pushed: true,
            seed: seedSubscription);
        await checkCase(tester, phone: true, where: 'history ${size.label} ${look.name}');
      }, skip: _skip);
    }
  }

  ph5TestWidgets('on a phone Submit is in the action bar; on a wide window it stays in the page', (tester) async {
    await _pump(tester);
    expect(find.descendant(of: find.byType(FormActionBar), matching: find.text('Submit Payment for Review')), findsOneWidget);
    await _pump(tester, size: const Size(1200, 800));
    expect(find.byType(FormActionBar), findsNothing);
    expect(find.text('Submit Payment for Review'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('Back with a reference typed asks first; a clean form leaves at once', (tester) async {
    await _pump(tester);
    await tester.pageBack();
    await ph5Settle(tester);
    expect(find.byType(SubscriptionScreen), findsNothing, reason: 'nothing typed: no question');

    await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'MP123');
    await tester.pageBack();
    await ph5Settle(tester);
    expect(find.text('Discard this payment?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await ph5Settle(tester);
    expect(find.byType(SubscriptionScreen), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('a rebuild does not listen again (the recent claims are listened to once)', (tester) async {
    final fs = CountingFirestore();
    await _pump(tester, firestore: fs);
    final before = fs.listens;
    await tester.tap(find.text('Weekly'));
    await ph5Settle(tester);
    await tester.tap(find.text('Yearly'));
    await ph5Settle(tester);
    expect(fs.listens, before, reason: 'choosing a plan rebuilds the screen, not its listeners');
  }, skip: _skip);
}
