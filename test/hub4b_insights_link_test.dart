// HUB4b (0): the chart carousel's header has a small "Insights" link with a
// chevron next to the 7d | 30d switch (a page tap no longer opens Insights):
// a 48 px target in the header's row, clear of the dots and the switch at
// every phone width, in English and Kiswahili; a tap opens Insights through
// the panel tile. The Visit activity donut's services come through the
// shared InsightsDataLoader (one read per window, shared with Insights).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

const _link = ValueKey('home-chart-insights');
const _switch = ValueKey('home-chart-range');

void main() {
  setUpAll(() => initializeDateFormatting());

  for (final size in const [Size(360, 740), Size(390, 844), Size(412, 915), Size(360, 640)]) {
    for (final look in [MatrixLook.light, MatrixLook.kiswahili]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} ${look.name}: left of the switch, 48 px, clear of '
          'the dots', (tester) async {
        final charts = HarnessCharts();
        await pumpAtSize(tester, screen: phoneHomeHarness(charts: charts.build()), size: size, look: look);
        await tester.pumpAndSettle();
        if (find.byKey(const ValueKey('home-chart-pages')).evaluate().isEmpty) {
          // No room for the chart region (360x640): no carousel, so no link.
          expect(find.byKey(_link), findsNothing);
          return;
        }
        final link = tester.getRect(find.byKey(_link));
        final range = tester.getRect(find.byKey(_switch));
        expect(link.width, greaterThanOrEqualTo(HomeChartMetrics.target));
        expect(link.height, greaterThanOrEqualTo(HomeChartMetrics.target));
        expect(link.top, range.top, reason: 'the same row as the switch');
        expect(link.right, lessThanOrEqualTo(range.left), reason: 'left of the switch, not over it');
        final lastDot = tester.getRect(find.byKey(const ValueKey('home-chart-dot-2')));
        expect(link.left, greaterThan(lastDot.right), reason: 'clear of the dots');
        expect(find.descendant(of: find.byKey(_link), matching: find.byIcon(Icons.chevron_right)), findsOneWidget);
        await checkCase(tester, phone: true, where: '${size.width}x${size.height} ${look.name}');

        await tester.tap(find.byKey(_link));
        expect(charts.insights, 1);
      }, skip: _skip);
    }
  }

  group('the dashboard', () {
    final dash = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync().replaceAll('\r\n', '\n');
    test('the link opens Insights the panel tile\'s way', () {
      expect(dash, contains('onInsights: () => runHubTile(homeContext, HubTile.insights, onDone: _returnToHome),'));
    }, skip: _skip);

    test('the donut reads its services through the shared loader, as Insights does (no second read)', () {
      expect(dash, contains('InsightsDataLoader.shared\n          .services(facilityId, days: r.days)'));
      final insights = File('lib/screens/dashboard/insights_screen.dart').readAsStringSync();
      expect(insights, contains('loader.services(facilityId, now: now)'));
      expect(insights, contains('final loader = InsightsDataLoader.shared;'));
    }, skip: _skip);
  });
}
