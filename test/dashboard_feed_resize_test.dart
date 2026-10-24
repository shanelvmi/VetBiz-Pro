// DASH-1 report A: the Recent Activity feed spun forever after the window
// was made narrower, and kept spinning when it was made wide again. The
// feed is built in one of two layout branches (side by side when wide,
// stacked when narrow), so a resize drops one StreamBuilder and builds
// another on the SAME cached stream. These pump the real feed, layout and
// query on the fake Firestore, as an admin and as an assistant (two scoped
// queries merged), and resize 1200 -> 400 -> 1200.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/dashboard_panels.dart';
import 'package:vetbiz_pro/theme/app_breakpoints.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/utils/merged_query_stream.dart';

// Skipped until the DASH-1 A fix.
const _skipA = true;
const _facility = 'facility1';
const _uid = 'assistant1';

Future<FakeFirebaseFirestore> _threeEntries() async {
  final fs = FakeFirebaseFirestore();
  final logs = fs.collection(Collections.facilities).doc(_facility).collection(Collections.activityLogs);
  for (var n = 1; n <= 3; n++) {
    await logs.add({
      'userId': _uid,
      'actionType': 'sales',
      'description': 'Entry $n',
      'timestamp': Timestamp.fromDate(DateTime(2026, 10, 1, 9, n)),
    });
  }
  return fs;
}

/// The dashboard's lower panels around the real feed, wide or stacked by
/// the dashboard's own breakpoint. [stream] is made once, as the dashboard
/// caches it.
Widget _dashboard(Stream<List<LogDoc>> stream) => MaterialApp(
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, constraints) => DashboardLowerPanels(
              wide: constraints.maxWidth >= AppBreakpoints.expanded,
              chart: const SizedBox(height: 100),
              feed: RecentActivityFeed(stream: stream),
              quickActions: const SizedBox(height: 50),
            ),
          ),
        ),
      ),
    );

Future<void> _resize(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 2000));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The stream as cloud_firestore gives it (web and mobile): one live
/// listener per query, shared by every listener, replaying nothing.
Stream<QuerySnapshot<Map<String, dynamic>>> _sharedLikeCloudFirestore(Query<Map<String, dynamic>> q) =>
    q.snapshots().asBroadcastStream();

void main() {
  for (final (who, isAdmin, snapshotsOf) in [
    ('admin', true, _sharedLikeCloudFirestore),
    ('admin (the fake\'s own stream)', true, null),
    ('assistant', false, null),
  ]) {
    testWidgets('$who: the feed shows its entries after every resize', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // The test font draws every letter as a full square, so the card's
      // header overflows by a few pixels where real text fits; only that is
      // ignored here.
      final onError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!'${details.exception}'.contains('overflowed')) onError?.call(details);
      };
      addTearDown(() => FlutterError.onError = onError);
      final fs = await _threeEntries();
      final stream = recentActivityStream(fs, _facility, isAdmin: isAdmin, uid: _uid, snapshotsOf: snapshotsOf);

      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(_dashboard(stream));
      await _resize(tester, 1200);
      expect(find.text('Entry 3'), findsOneWidget, reason: 'wide, first build');

      await _resize(tester, 400);
      expect(tester.takeException(), isNull);
      expect(find.text('Entry 3'), findsOneWidget, reason: 'narrow');

      await _resize(tester, 1200);
      expect(tester.takeException(), isNull);
      expect(find.text('Entry 3'), findsOneWidget, reason: 'wide again');
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }, skip: _skipA);
  }
}
