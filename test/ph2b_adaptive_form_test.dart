import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/daily_report.dart';
import 'package:vetbiz_pro/models/product.dart';
import 'package:vetbiz_pro/providers/debt_provider.dart';
import 'package:vetbiz_pro/providers/facility_provider.dart';
import 'package:vetbiz_pro/providers/payment_provider.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';
import 'package:vetbiz_pro/providers/service_provider.dart';
import 'package:vetbiz_pro/providers/subscription_provider.dart';
import 'package:vetbiz_pro/providers/transaction_provider.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/providers/user_role_provider.dart';
import 'package:vetbiz_pro/screens/activity/activity_log_screen.dart';
import 'package:vetbiz_pro/screens/clients/add_client_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/insights_screen.dart';
import 'package:vetbiz_pro/screens/debtors/add_payment_screen.dart';
import 'package:vetbiz_pro/screens/products/add_batch_screen.dart';
import 'package:vetbiz_pro/screens/products/add_edit_product_screen.dart';
import 'package:vetbiz_pro/screens/products/view_batches_screen.dart';
import 'package:vetbiz_pro/screens/register_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_full_view_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_review_screen.dart';
import 'package:vetbiz_pro/screens/sales/add_sale_screen.dart';
import 'package:vetbiz_pro/screens/services/add_edit_service_screen.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';
import 'package:vetbiz_pro/screens/transactions/add_transaction_screen.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_motion.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

import 'helpers/fake_firestore.dart';

// PH2b S4: the 14 copies of one rule (a full page below 900 wide, a modal
// at 900 and wider), RECORDED FROM THE OLD CODE before showAdaptiveForm
// replaces them; this file must pass unchanged after the migration.
//
// The screens themselves are not the point here (most need Firebase and
// providers): an error inside one is collected and ignored, and only the
// surface around it is measured: the route, the modal's box, the barrier
// and the result handed back on pop.

final _product = Product(
  id: 'p1',
  name: 'Product',
  buyPrice: 1,
  sellPrice: 2,
  stockQty: 1,
  unit: 'pcs',
  type: '',
  category: '',
  facilityId: 'f1',
);
final _report = DailyReport(
  id: 'r1',
  facilityId: 'f1',
  reportDate: DateTime(2026, 10, 1),
  generatedAt: DateTime(2026, 10, 1),
  generatedByName: 'Asha',
);

/// The modal box's size for a window: [w] and [h] are the old formulas.
typedef _Rule = Size Function(Size window);

Size _form(Size s) => Size((s.width * 0.60).clamp(0, 940), s.height * 0.88 < 480 ? 480 : s.height * 0.88);
Size _formCapped(Size s) => Size((s.width * 0.60).clamp(0, 940), (s.height * 0.88).clamp(0, 820));
Size _reportFull(Size s) => Size((s.width * 0.72).clamp(0, 1100), s.height * 0.9 < 480 ? 480 : s.height * 0.9);
Size _reportReview(Size s) => Size((s.width * 0.72).clamp(0, 900), s.height * 0.9 < 480 ? 480 : s.height * 0.9);
Size _activity(Size s) => Size((s.width * 0.85).clamp(0, 1000), s.height * 0.85);

class _Helper {
  final String name;
  final Future<Object?> Function(BuildContext) open;
  final _Rule rule;

  /// The value a pop hands back through the helper (null: a void helper).
  final Object? result;

  const _Helper(this.name, this.open, this.rule, {this.result});
}

final _helpers = <_Helper>[
  _Helper('Add Sale', (c) => showAddSaleScreen(c), _form),
  _Helper('Record Payment', (c) => showAddPaymentScreen(c), _form, result: true),
  _Helper('Add Client', (c) => showAddClientScreen(c), _formCapped, result: true),
  _Helper('Add Product', (c) => showAddEditProductScreen(c), _form),
  _Helper('Add Service', (c) => showAddEditServiceScreen(c), _formCapped),
  _Helper('Add Transaction', (c) => showAddTransactionScreen(c), _formCapped),
  _Helper('Add Batch', (c) => showAddBatchScreen(c, product: _product), _form),
  _Helper('View Batches', (c) => showViewBatchesScreen(c, product: _product), _form),
  _Helper('Insights', (c) => showInsightsScreen(c), _form),
  _Helper('Subscription', (c) => showSubscriptionScreen(c), _form),
  _Helper('Edit Profile', (c) => showEditProfileScreen(c, userData: const {}), _form, result: true),
  _Helper('Full report', (c) => showReportFullViewScreen(c, _report), _reportFull),
  _Helper('Report review', (c) => showReportReviewScreen(c, _report), _reportReview, result: _report),
  _Helper('Activity log', (c) => showActivityLog(c), _activity),
];

const _windows = [
  Size(390, 800),
  Size(768, 800),
  Size(899, 800),
  Size(900, 800),
  Size(1200, 800),
  Size(1200, 1000), // where "at most 820" and "at least 480" part
  Size(1200, 500),
];

/// Errors inside the screen (no Firebase, no providers) are not this test's:
/// taken and dropped.
void _drain(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

class _Observer extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route);
}

/// Opens [h] at [window]; returns the route it pushed and the future it gave.
Future<(Route<dynamic>, Future<Object?>)> _open(WidgetTester tester, _Helper h, Size window, _Observer observer) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final fs = newFakeFirestore();
  final debts = DebtProvider(firestore: fs);
  late BuildContext host;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => FacilityProvider(firestore: fs)),
      ChangeNotifierProvider(create: (_) => UiSettingsProvider()),
      ChangeNotifierProvider.value(value: debts),
      ChangeNotifierProvider(create: (_) => UserRoleProvider(firestore: fs, currentUid: () => testUserId)),
      ChangeNotifierProvider(create: (_) => newClientProvider(fs)),
      ChangeNotifierProvider(create: (_) => newSaleProvider(fs)),
      ChangeNotifierProvider(create: (_) => ServiceProvider(debtProvider: debts, firestore: fs, currentUserInfo: testUserInfo)),
      ChangeNotifierProvider(create: (_) => TransactionProvider(firestore: fs, currentUserInfo: testUserInfo)),
      ChangeNotifierProvider(create: (_) => ProductProvider(firestore: fs, currentUserInfo: testUserInfo)),
      ChangeNotifierProvider(create: (_) => PaymentProvider(firestore: fs)),
      ChangeNotifierProvider(create: (_) => SubscriptionProvider(firestore: fs)),
    ],
    child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
    navigatorObservers: [observer],
    home: Builder(builder: (c) {
      host = c;
      return const Scaffold();
    }),
  )),
  );
  final pushedBefore = observer.pushed.length;
  final future = h.open(host);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  _drain(tester);
  expect(observer.pushed.length, pushedBefore + 1, reason: '${h.name} at $window pushed one route');
  return (observer.pushed.last, future);
}

void main() {
  for (final h in _helpers) {
    for (final window in _windows) {
      testWidgets('${h.name} at ${window.width.toInt()}x${window.height.toInt()}', (tester) async {
        final observer = _Observer();
        final (route, future) = await _open(tester, h, window, observer);

        if (window.width < 900) {
          // A full page with its own back arrow.
          expect(route, isA<MaterialPageRoute<dynamic>>(), reason: h.name);
        } else {
          expect(route, isA<RawDialogRoute<dynamic>>(), reason: h.name);
          final dialog = route as RawDialogRoute<dynamic>;
          expect(dialog.barrierDismissible, isTrue);
          final colors = Theme.of(tester.element(find.byType(Scaffold).first)).extension<AppColors>()!;
          expect(dialog.barrierColor, colors.scrim.withValues(alpha: 0.5));
          expect(dialog.transitionDuration, AppMotion.normal);
          // The modal's box: a SizedBox around a ClipRRect (radius 16) around Material.
          final box = find.byWidgetPredicate((w) => w is SizedBox && w.child is ClipRRect);
          expect(tester.getSize(box.first), h.rule(window), reason: '${h.name} at $window');
          final clip = tester.widget<ClipRRect>(find.descendant(of: box.first, matching: find.byType(ClipRRect)).first);
          expect(clip.borderRadius, BorderRadius.circular(16));
          // Centred in the window.
          expect(tester.getCenter(box.first), Offset(window.width / 2, window.height / 2));
        }

        // The pop result comes back through the helper.
        route.navigator!.pop(h.result);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        _drain(tester);
        expect(await future, h.result, reason: h.name);
      });
    }

    testWidgets('${h.name}: the modal closes on a tap outside it', (tester) async {
      final observer = _Observer();
      final (route, future) = await _open(tester, h, const Size(1200, 800), observer);
      expect(route.isActive, isTrue);
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      _drain(tester);
      expect(await future, isNull);
    });
  }
}
