// DASH-1 report B: after sign-in the quick-action buttons sat higher than
// their normal place until every card had loaded, then jumped down. What
// sits above them (the Today at a Glance strip, the sales chart, the Recent
// Activity feed) showed a small spinner while loading and grew when the
// data came. These pump the real pieces, loading and then loaded, and
// measure where the quick actions start, at phone, tablet and desktop
// widths: it must not change.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/dashboard_panels.dart';
import 'package:vetbiz_pro/screens/dashboard/sales_revenue_chart.dart';
import 'package:vetbiz_pro/theme/app_breakpoints.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/utils/merged_query_stream.dart';

// Skipped until the DASH-1 B fix.
const _skipB = true;

const _quickActions = Key('quickActions');

/// [entries] activity entries, as the feed's query returns them.
Future<List<LogDoc>> _entries(int entries) async {
  final fs = FakeFirebaseFirestore();
  final logs = fs.collection('logs');
  for (var n = 1; n <= entries; n++) {
    await logs.add({
      'actionType': 'sales',
      'description': 'Entry $n',
      'timestamp': Timestamp.fromDate(DateTime(2026, 10, 1, 9, n)),
    });
  }
  return (await logs.get()).docs;
}

Widget _panels({required bool loaded, required Stream<List<LogDoc>> feed}) => MaterialApp(
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, constraints) => DashboardLowerPanels(
              glance: TodayGlanceStrip(
                saleCount: loaded ? 3 : null,
                serviceCount: loaded ? 1 : null,
                collected: loaded ? 0 : null,
                isLoading: !loaded,
                debtorCount: 2,
              ),
              wide: constraints.maxWidth >= AppBreakpoints.expanded,
              chart: SalesRevenueChart(
                salesByDay: loaded ? const [0, 1000, 0, 2500, 0, 0, 4000] : null,
                collectionsByDay: loaded ? const [0, 0, 500, 0, 0, 0, 0] : null,
                servicesByDay: loaded ? const [0, 0, 0, 0, 3000, 0, 0] : null,
                otherIncomeTotal: loaded ? 0 : null,
                previousTotal: loaded ? 5000 : null,
                isLoading: !loaded,
                period: 'Last 7 days',
                periodLabel: (p) => p,
                onPeriodChanged: (_) {},
                start: DateTime(2026, 10, 1),
                days: 7,
              ),
              feed: RecentActivityFeed(stream: feed),
              quickActions: const SizedBox(key: _quickActions, height: 80),
            ),
          ),
        ),
      ),
    );

void main() {
  for (final (size, width) in [('phone', 390.0), ('tablet', 800.0), ('desktop', 1400.0)]) {
    for (final entries in [AppLimits.recentActivityCount, 0]) {
      testWidgets('$size, $entries activity entries: the quick actions stay where they are while the cards load',
          (tester) async {
        // The test font draws every letter as a full square, so a card's
        // header can overflow by a few pixels where real text fits; only
        // that is ignored here.
        final onError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (!'${details.exception}'.contains('overflowed')) onError?.call(details);
        };
        addTearDown(() => FlutterError.onError = onError);
        await tester.binding.setSurfaceSize(Size(width, 3000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final docs = (await tester.runAsync(() => _entries(entries)))!;
        final feed = StreamController<List<LogDoc>>();
        addTearDown(feed.close);

        await tester.pumpWidget(_panels(loaded: false, feed: feed.stream));
        await tester.pump();
        final whileLoading = tester.getTopLeft(find.byKey(_quickActions)).dy;

        feed.add(docs);
        await tester.pumpWidget(_panels(loaded: true, feed: feed.stream));
        await tester.pump();
        expect(find.text(entries == 0 ? 'No activity yet.' : 'Entry 1'), findsWidgets);
        expect(tester.getTopLeft(find.byKey(_quickActions)).dy, whileLoading);
      }, skip: _skipB);
    }
  }
}
