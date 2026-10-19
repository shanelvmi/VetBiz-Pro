import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/models/daily_report.dart';
import 'package:vetbiz_pro/screens/reports/report_activity_log_loader.dart';

// E4c (a1): the report screens read the activity log from its admin-only
// subdocument through this loader, and must cope with it being absent (a
// report made before the change) or refused.
DailyReport _report() => DailyReport(
      id: '2026-10-19',
      facilityId: 'F1',
      reportDate: DateTime(2026, 10, 19),
      generatedAt: DateTime(2026, 10, 19, 18),
      generatedByName: 'Asha',
    );

void main() {
  group('ReportActivityLogLoader', () {
    Future<void> pump(WidgetTester tester, Future<List<ActivityLogEntry>?> Function(DailyReport) load, List<String> seen) =>
        tester.pumpWidget(MaterialApp(
          home: ReportActivityLogLoader(
            report: _report(),
            load: load,
            builder: (context, snap) {
              final state = snap.connectionState != ConnectionState.done
                  ? 'waiting'
                  : snap.hasError
                      ? 'error'
                      : snap.data == null
                          ? 'not saved'
                          : '${snap.data!.length} entries';
              seen.add(state);
              return Text(state);
            },
          ),
        ));

    testWidgets('no subdocument (a report from before the change): "not saved", read once', (tester) async {
      var reads = 0;
      final seen = <String>[];
      await pump(tester, (_) async {
        reads++;
        return null;
      }, seen);
      await tester.pumpAndSettle();
      await tester.pump();
      expect(find.text('not saved'), findsOneWidget);
      expect(reads, 1);
    });

    testWidgets('entries are handed over; a failed read is an error, not a crash', (tester) async {
      final seen = <String>[];
      await pump(tester, (_) async => [ActivityLogEntry(time: DateTime(2026), actionType: 'Sale', description: 'x', userName: 'y')], seen);
      await tester.pumpAndSettle();
      expect(find.text('1 entries'), findsOneWidget);

      final failing = Completer<List<ActivityLogEntry>?>();
      // Replace the tree first, so a fresh loader starts its own read.
      await tester.pumpWidget(const SizedBox());
      await pump(tester, (_) => failing.future, seen);
      expect(find.text('waiting'), findsOneWidget);
      failing.completeError(StateError('permission-denied'));
      await tester.pumpAndSettle();
      expect(find.text('error'), findsOneWidget);
    });
  });
}
