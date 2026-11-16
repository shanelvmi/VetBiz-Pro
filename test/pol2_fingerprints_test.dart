// POL2: the screens POL2 changes that had no fingerprint yet, recorded on the
// code before POL2 (the pol2- names in test/fixtures/ph5a_wide_fingerprints.json):
// Insights and the Subscription screen with an active promotion at 768x1024,
// 1024x768 and 1200x800, and the phone Today card at three phone sizes. The
// fingerprint holds the widget types, the texts and every box's size and
// place, not colours or shadows, so removing a glow leaves it unchanged; a
// commit that changes one names it and says why.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/facility_provider.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/dashboard/insights_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

import 'helpers/phone_list_harness.dart';
import 'helpers/tree_fingerprint.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;
import 'ph8a_subscription_wide_test.dart' show seedSubscription;

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

void _expect(WidgetTester tester, String name, Finder root) =>
    expectSameFingerprint(name, '${_errors(tester)}${treeFingerprint(tester, root.first)}');

const pol2PhoneSizes = [Size(360, 640), Size(390, 844), Size(412, 915)];

const _figures = PhoneHomeFigures(sales: 1250000, collected: 980000, owed: 310000, netProfit: 145000);

/// One active promotion for every plan and every facility.
Future<void> seedPromotion(FirebaseFirestore fs) async {
  await seedSubscription(fs);
  await fs.collection(Collections.promotions).doc('p1').set({
    'label': 'Harvest offer',
    'active': true,
    'discountPercent': 10,
    'appliesToPlans': <String>[],
    'targetExpiringOnly': false,
  });
}

/// The phone Today card as the dashboard wires it, today up 12 % on yesterday.
Future<void> pumpTodayCard(WidgetTester tester, Size size, {Brightness brightness = Brightness.light, HomeDelta delta = const HomeDelta.change(12), AppColorTheme theme = AppColorTheme.pasture}) async {
  SharedPreferences.setMockInitialValues({'facilityId': 'f1', 'facilityName': 'Mwanzo Agrovet'});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final facilities = FacilityProvider(firestore: FakeFirebaseFirestore());
  await facilities.setFacility(id: 'f1', name: 'Mwanzo Agrovet', type: 'Agrovet');
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => UiSettingsProvider()),
      ChangeNotifierProvider.value(value: facilities),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.build(theme, brightness),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: TodayCard(
            figures: _figures,
            isAdmin: true,
            period: 'Today',
            onPeriodChanged: (_) {},
            onAllDetails: () {},
            onToggleAmounts: () {},
            periodLabel: 'Mon 9 Nov',
            delta: delta,
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final size in ph5WideSizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    final modal = size.width >= 900;

    ph5TestWidgets('pol2-insights-$at: the layout as before POL2', (tester) async {
      await pumpPh5(tester, (fs) => InsightsScreen(isModal: modal, firestore: fs), size: size, pushed: true);
      await ph5SettleUntil(tester, () => find.byKey(const ValueKey('pulse-content')).evaluate().isNotEmpty);
      expect(find.byKey(const ValueKey('pulse-content')), findsOneWidget, reason: 'the Business pulse card is shown');
      _expect(tester, 'pol2-insights-$at', find.byType(InsightsScreen));
    });

    ph5TestWidgets('pol2-subscription-promo-$at: the layout as before POL2', (tester) async {
      await pumpPh5(tester, (fs) => SubscriptionScreen(isModal: modal, firestore: fs, auth: Ph8Auth()),
          size: size, pushed: !modal, seed: seedPromotion);
      await ph5SettleUntil(tester, () => find.text('Harvest offer').evaluate().isNotEmpty);
      expect(find.text('Harvest offer'), findsOneWidget, reason: 'the active-promotion banner is shown');
      _expect(tester, 'pol2-subscription-promo-$at', find.byType(SubscriptionScreen));
    });
  }

  for (final size in pol2PhoneSizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('pol2-today-card-$at: the layout as before POL2', (tester) async {
      await pumpTodayCard(tester, size);
      expect(find.byKey(const ValueKey('home-delta')), findsOneWidget);
      _expect(tester, 'pol2-today-card-$at', find.byType(TodayCard));
    });
  }
}
