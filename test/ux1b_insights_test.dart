// UX1b: Insights on PC and tablet inside AppShell. The shared PageHeader (no
// teal bar, no centred title, no back arrow: a top-level place), the full
// content width: Business Pulse full width, the chart cards two to a row
// from a content width of 900 (950, 1128) and one below (696, 774). The
// services donut reads the 30-day window (a service 20 days old shows) and,
// when every service was free, says so instead of a blank ring. Text 1.3,
// Light, Dark, Kiswahili, every colour theme. The phone keeps its bar.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/dashboard/insights_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/utils/app_clock.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';
import 'package:vetbiz_pro/widgets/shell/page_header.dart';

import 'helpers/fake_firestore.dart' show testFacilityId;
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

final _shell = GlobalKey<AppShellState>();

Widget _harness(FirebaseFirestore fs, double sidebar) => Scaffold(
      body: AppShell(
        key: _shell,
        sidebar: (selected, onSelect) => SizedBox(width: sidebar),
        topBar: const SizedBox(height: 64),
        home: const Text('HOME'),
        pageFor: (d) => d == AppDestination.insights ? InsightsScreen(firestore: fs) : null,
        onOpenFullScreen: (_) async {},
        onReturnedHome: (_) {},
      ),
    );

/// One service [daysAgo] days back, earning [amount].
Future<void> Function(FirebaseFirestore) _service(int daysAgo, num amount) => (fs) async {
      final at = Timestamp.fromDate(AppClock.now().subtract(Duration(days: daysAgo)));
      await fs.collection(Collections.facilities).doc(testFacilityId).collection(Collections.services).add(
          {'name': 'Vaccination', 'totalAmount': amount, 'serviceDate': at, 'timestamp': at});
    };

Future<void> _pumpInShell(WidgetTester tester, Size size, double sidebar,
    {MatrixLook look = MatrixLook.light, AppColorTheme theme = AppColorTheme.pasture, double textScale = 1, Future<void> Function(FirebaseFirestore)? seed}) async {
  await pumpPh5(tester, (fs) => _harness(fs, sidebar), size: size, look: look, colorTheme: theme, textScale: textScale, seed: seed);
  _shell.currentState!.select(AppDestination.insights);
  await tester.pumpAndSettle();
  await ph5SettleUntil(tester, () => find.byKey(const ValueKey('pulse-content')).evaluate().isNotEmpty);
}

Finder _cardTitle(String text) => find.text(text);

void main() {
  for (final (size, sidebar) in const [
    (Size(768, 1024), 72.0),
    (Size(1024, 768), 250.0),
    (Size(1200, 800), 250.0),
    (Size(1200, 800), 72.0),
  ]) {
    final content = (size.width - sidebar).toInt();
    final twoColumns = content >= 900;
    for (final look in const [MatrixLook.light, MatrixLook.dark, MatrixLook.kiswahili]) {
      for (final theme in AppColorTheme.all) {
        ph5TestWidgets('content $content ${look.name} ${theme.id} text 1.3: PageHeader, ${twoColumns ? 'two' : 'one'} column(s)', (tester) async {
          await _pumpInShell(tester, size, sidebar, look: look, theme: theme, textScale: 1.3);
          expect(tester.takeException(), isNull);
          expect(find.byType(PageHeader), findsOneWidget);
          expect(find.byType(AppBar), findsNothing, reason: 'no teal bar');
          expect(find.byType(BackButton), findsNothing, reason: 'a top-level place');
          final header = find.byType(PageHeader);
          final title = find.descendant(of: header, matching: find.byType(Text)).first;
          expect(tester.getTopLeft(title).dx - tester.getTopLeft(header).dx, lessThan(40), reason: 'title on the left');
          if (look != MatrixLook.kiswahili) {
            final pulse = find.byKey(const ValueKey('pulse-content'));
            final sales = _cardTitle('Sales - Last 14 Days');
            final top = _cardTitle('Top 5 Products - Last 30 Days');
            await tester.ensureVisible(top);
            await tester.pumpAndSettle();
            expect(tester.getSize(find.byType(InsightsScreen)).width, content.toDouble(), reason: 'the full content width');
            if (twoColumns) {
              expect(tester.getTopLeft(top).dy, tester.getTopLeft(sales).dy, reason: 'side by side');
              expect(tester.getTopLeft(top).dx, greaterThan(tester.getTopLeft(sales).dx));
            } else {
              expect(tester.getTopLeft(top).dy, greaterThan(tester.getTopLeft(sales).dy), reason: 'one column');
              expect(tester.getTopLeft(top).dx, tester.getTopLeft(sales).dx);
            }
            expect(pulse, findsOneWidget);
          }
        });
      }
    }
  }

  ph5TestWidgets('a service 20 days old is in the donut (the 30-day read)', (tester) async {
    await _pumpInShell(tester, const Size(1200, 800), 250, seed: _service(20, 5000));
    await tester.ensureVisible(find.text('Services by Type - Last 30 Days'));
    await tester.pumpAndSettle();
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('No services in the last 30 days.'), findsNothing);
  });

  ph5TestWidgets('every service free: the no-revenue line, not a blank ring', (tester) async {
    await _pumpInShell(tester, const Size(1200, 800), 250, seed: _service(2, 0));
    await tester.ensureVisible(find.text('Services by Type - Last 30 Days'));
    await tester.pumpAndSettle();
    expect(find.byType(PieChart), findsNothing);
    expect(find.text('No service revenue in the last 30 days.'), findsOneWidget);
  });

  ph5TestWidgets('no services: the existing empty line', (tester) async {
    await _pumpInShell(tester, const Size(1200, 800), 250);
    await tester.ensureVisible(find.text('Services by Type - Last 30 Days'));
    await tester.pumpAndSettle();
    expect(find.text('No services in the last 30 days.'), findsOneWidget);
  });

  ph5TestWidgets('the phone keeps its own bar (no PageHeader)', (tester) async {
    await pumpPh5(tester, (fs) => InsightsScreen(firestore: fs), size: const Size(390, 844), pushed: true);
    await ph5SettleUntil(tester, () => find.byKey(const ValueKey('pulse-content')).evaluate().isNotEmpty);
    expect(find.byType(PageHeader), findsNothing);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
