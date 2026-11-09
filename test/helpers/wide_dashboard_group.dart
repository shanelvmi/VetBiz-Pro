// RV1 and UI5: the wide dashboard's group (the card grid and the lower
// panels) as dashboard_screen.dart builds it; the dashboard itself cannot be
// built in a test. Shared by rv1_home_test and ui5_wide_unchanged_test.
import 'package:flutter/material.dart';
import 'package:vetbiz_pro/screens/dashboard/dashboard_panels.dart';
import 'package:vetbiz_pro/screens/dashboard/sales_revenue_chart.dart';
import 'package:vetbiz_pro/theme/app_breakpoints.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/utils/merged_query_stream.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';
import 'package:vetbiz_pro/widgets/summary_card.dart';

import 'real_font.dart';
import 'screen_size_matrix.dart';

/// The wide group as dashboard_screen.dart builds it: eight cards through
/// SkeletonOr, then the lower panels, under one ScreenReveal.
Widget wideDashboardGroup(RevealGate gate, {required bool wide, Stream<List<LogDoc>>? feed}) {
  Widget group() => LayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.maxWidth > AppBreakpoints.dashboardGridFour
              ? 4
              : constraints.maxWidth > AppBreakpoints.dashboardGridThree
                  ? 3
                  : 2;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  mainAxisExtent: 120,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: 8,
                itemBuilder: (context, i) => SkeletonOr(
                  radius: AppRadius.r12,
                  child: SummaryCard(
                    title: 'Card $i ${matrixLongProductName.substring(0, 20)}',
                    value: '12,345,678',
                    icon: Icons.inventory,
                    color: Colors.teal,
                    subtitle: 'As of now',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              DashboardLowerPanels(
                glance: const SkeletonOr(
                  radius: AppRadius.r12,
                  child: TodayGlanceStrip(saleCount: 3, serviceCount: 2, collected: 12500, isLoading: false, debtorCount: 4),
                ),
                wide: wide,
                chart: SkeletonOr(
                  radius: AppRadius.r12,
                  child: SalesRevenueChart(
                    salesByDay: const [1, 2, 3, 4, 5, 6, 7],
                    collectionsByDay: const [1, 1, 1, 1, 1, 1, 1],
                    servicesByDay: const [0, 0, 0, 0, 0, 0, 0],
                    otherIncomeTotal: 0,
                    previousTotal: 10,
                    isLoading: false,
                    period: 'Last 7 days',
                    periodLabel: (p) => p,
                    onPeriodChanged: (_) {},
                    start: DateTime(2026, 11, 1),
                    days: 7,
                  ),
                ),
                feed: SkeletonOr(
                  radius: AppRadius.r12,
                  placeholder: const RecentActivityFeed(stream: null),
                  child: RecentActivityFeed(stream: feed),
                ),
                quickActions: const SkeletonOr(child: SizedBox(height: 120, child: Text('Quick actions'))),
              ),
            ],
          );
        },
      );
  return withRobotoText(Scaffold(
    body: SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.s16), child: ScreenReveal(gate: gate, child: group())),
  ));
}

/// The wide panels sized for real text: the square test font is about twice
/// as wide and overflows Recent Activity's header (dashboard_feed_resize_test
/// ignores it for the same reason).
Widget withRobotoText(Widget child) => Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: realFontFamily)),
          child: DefaultTextStyle.merge(style: const TextStyle(fontFamily: realFontFamily), child: child),
        );
      },
    );
