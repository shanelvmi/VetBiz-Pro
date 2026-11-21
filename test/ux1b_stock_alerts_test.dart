// UX1b: Product Alerts on PC and tablet inside AppShell, opened above a
// place (openInContent, Products highlighted). The shared PageHeader with its
// subtitle and a back arrow (no teal bar, no centred title); Back returns
// where you were. The kind filters are one left-aligned row that wraps, each
// as wide as its label with its count; the footer is the shared ListPageBar,
// the range and the page size apart. Text 1.3, Light, Dark, Kiswahili, every
// colour theme, content 696, 774, 950 and 1128. The phone keeps its list.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/products/stock_alerts_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/ui/polish/filter_row.dart';
import 'package:vetbiz_pro/widgets/list_page_bar.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';
import 'package:vetbiz_pro/widgets/shell/page_header.dart';

import 'helpers/ph5b_finders.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

final _shell = GlobalKey<AppShellState>();

const _kinds = ['All', 'depleted', 'expired', 'lowStock', 'expiringSoon', 'restockShelf'];

Widget _harness(double sidebar) => Ph7Listening(
      child: Scaffold(
        body: AppShell(
          key: _shell,
          sidebar: (selected, onSelect) => SizedBox(
            width: sidebar,
            child: Column(children: [
              for (final d in const [AppDestination.home, AppDestination.products])
                SizedBox(key: ValueKey('sb-${d.name}${d == selected ? '-selected' : ''}'), height: 48),
            ]),
          ),
          topBar: const SizedBox(height: 64),
          home: const Text('HOME'),
          pageFor: (_) => null,
          onOpenFullScreen: (_) async {},
          onReturnedHome: (_) {},
        ),
      ),
    );

Future<void> _open(WidgetTester tester, Size size, double sidebar,
    {MatrixLook look = MatrixLook.light, AppColorTheme theme = AppColorTheme.pasture, double textScale = 1}) async {
  await pumpPh5(tester, (_) => _harness(sidebar), size: size, look: look, colorTheme: theme, textScale: textScale, seed: ph7SeedProducts);
  _shell.currentState!.openInContent(const StockAlertsScreen(), highlight: AppDestination.products);
  await tester.pumpAndSettle();
}

void main() {
  for (final (size, sidebar) in const [
    (Size(768, 1024), 72.0),
    (Size(1024, 768), 250.0),
    (Size(1200, 800), 250.0),
    (Size(1200, 800), 72.0),
  ]) {
    final content = (size.width - sidebar).toInt();
    for (final look in const [MatrixLook.light, MatrixLook.dark, MatrixLook.kiswahili]) {
      for (final theme in AppColorTheme.all) {
        ph5TestWidgets('content $content ${look.name} ${theme.id} text 1.3: header, one filter row, the page bar', (tester) async {
          await _open(tester, size, sidebar, look: look, theme: theme, textScale: 1.3);
          expect(tester.takeException(), isNull);
          final screen = find.byType(StockAlertsScreen);
          expect(tester.getTopLeft(screen).dx, sidebar, reason: 'in the content, beside the sidebar');
          expect(find.byKey(const ValueKey('sb-products-selected')), findsOneWidget);

          final header = find.byType(PageHeader);
          expect(header, findsOneWidget);
          expect(find.byType(AppBar), findsNothing, reason: 'no teal bar');
          expect(find.descendant(of: header, matching: find.byType(BackButton)), findsOneWidget, reason: 'pushed above a place');
          expect(tester.widget<PageHeader>(header).subtitle, isNotNull);

          // The filters: left-aligned, each its label's width, the first
          // ones on one line, every one in view.
          final row = find.byType(FilterRow);
          final rowLeft = tester.getTopLeft(row).dx;
          final all = tester.getRect(ph5Key('pol5-alertKind-All'));
          final depleted = tester.getRect(ph5Key('pol5-alertKind-depleted'));
          expect(all.left - rowLeft, lessThan(40), reason: 'left-aligned');
          expect(all.width, lessThan(content / 3), reason: 'not stretched to the row');
          expect(depleted.top, all.top, reason: 'on one line');
          expect(depleted.left, greaterThan(all.left));
          final lines = {for (final k in _kinds) tester.getRect(ph5Key('pol5-alertKind-$k')).top};
          // One row that wraps when narrow (696 at text 1.3: three lines, four
          // in Kiswahili), never one filter per line as before.
          expect(lines.length, lessThan(_kinds.length), reason: 'a wrapping row, not a column');
          // The footer: the shared bar; the range and the page size apart.
          final bar = find.byType(ListPageBar);
          expect(bar, findsOneWidget);
          final range = tester.getRect(find.descendant(of: bar, matching: find.byType(Text)).first);
          final sizeMenu = tester.getRect(find.descendant(of: bar, matching: find.byType(DropdownButton<int>)));
          expect(range.overlaps(sizeMenu), isFalse, reason: 'no collision: $range $sizeMenu');
        });
      }
    }
  }

  ph5TestWidgets('content 1128 at text 1.0: the six filters on one line', (tester) async {
    await _open(tester, const Size(1200, 800), 72);
    final tops = {for (final k in _kinds) tester.getRect(ph5Key('pol5-alertKind-$k')).top};
    expect(tops, hasLength(1));
  });

  ph5TestWidgets('Back returns to where you were (Home), Home highlighted', (tester) async {
    await _open(tester, const Size(1200, 800), 250);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(StockAlertsScreen), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byKey(const ValueKey('sb-home-selected')), findsOneWidget);
  });

  ph5TestWidgets('the phone keeps its own list (no PageHeader, no ListPageBar)', (tester) async {
    await pumpPh5(tester, (fs) => const Ph7Listening(child: StockAlertsScreen()), size: const Size(390, 844), pushed: true, seed: ph7SeedProducts);
    expect(find.byType(PageHeader), findsNothing);
    expect(find.byType(ListPageBar), findsNothing);
  });
}
