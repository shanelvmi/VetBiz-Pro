// POL2 Step 3, the rest of Home (group 2): the wide "Today at a glance"
// strip's figures are neutral (no colour by kind: the icon textSecondary,
// the value textPrimary); All details' bar has no shadow, a hairline under
// it; the calm-trial banners are neutral (the trial ending stays warning,
// locked stays danger: ph8a_banner_test, hub3_banner_test). Light and Dark,
// text scale 1.3.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/all_details_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/dashboard_panels.dart';
import 'package:vetbiz_pro/services/dashboard_summary_service.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';

import 'helpers/screen_size_matrix.dart';

const _totals = DashboardPeriodTotals(
  totalSales: 12500,
  totalCollected: 9700,
  totalProfit: 6000,
  totalRealizedProfit: 5000,
  totalUnrealizedProfit: 1000,
  netProfit: 4321,
  totalExpenses: 1500,
  completedServicesCount: 7,
  totalServiceRevenue: 5000,
);

AppColors _colors(WidgetTester tester, Type t) => Theme.of(tester.element(find.byType(t))).extension<AppColors>()!;

void main() {
  for (final look in [MatrixLook.light, MatrixLook.dark]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('the glance strip ${look.name} at $scale: every figure neutral, its words kept', (tester) async {
        await pumpAtSize(
          tester,
          screen: const Scaffold(
            body: TodayGlanceStrip(saleCount: 4, serviceCount: 2, collected: 9700, isLoading: false, debtorCount: 3),
          ),
          size: const Size(1200, 800),
          look: look,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        final c = _colors(tester, TodayGlanceStrip);
        for (final value in ['4', '2']) {
          expect(tester.widget<Text>(find.text(value)).style!.color, c.textPrimary, reason: value);
        }
        // The four figure icons (the Insights button keeps its primary: an action).
        final icons = tester.widgetList<Icon>(find.descendant(of: find.byType(TodayGlanceStrip), matching: find.byType(Icon))).toList();
        expect(icons.where((i) => i.color == c.textSecondary), hasLength(4));
        expect(icons.where((i) => i.color != c.textSecondary && i.color != c.primary), isEmpty);
      });
    }

    testWidgets('All details ${look.name}: the bar is flat with a hairline under it', (tester) async {
      await pumpAtSize(
        tester,
        screen: AllDetailsScreen(
          changes: ValueNotifier(0),
          figures: () => const AllDetailsFigures(totals: _totals, productValue: 880000, outstanding: 8250.5, clients: 42),
          isAdmin: () => true,
          period: () => 'Today',
          onPeriodChanged: (_) {},
          onOpen: (_) {},
          chart: (_) => const SizedBox(height: 200),
          feed: (_) => const SizedBox(height: 200),
        ),
        size: const Size(390, 844),
        look: look,
      );
      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.elevation, AppElevation.e0);
      expect((bar.shape! as Border).bottom.color, _colors(tester, AllDetailsScreen).divider);
    });
  }
}
