// LAY6a: the shared pieces of the record screens: DetailsLayout (inline, or
// auto: inline from 900, a slide-over below), ListPageBar and ToolbarLayout.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/details_layout.dart';
import 'package:vetbiz_pro/widgets/list_page_bar.dart';
import 'package:vetbiz_pro/widgets/toolbar_layout.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Future<void> _pump(WidgetTester tester, Widget child, {double width = 1200, double scale = 1, bool reduce = false}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: reduce),
      child: c!,
    ),
    home: Scaffold(body: child),
  ));
}

/// A list with one focusable row, and its details when [open].
class _Host extends StatefulWidget {
  const _Host({required this.mode, required this.rowFocus});
  final DetailsMode mode;
  final FocusNode rowFocus;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool open = false;
  @override
  Widget build(BuildContext context) => DetailsLayout(
        mode: widget.mode,
        detailsWidth: 380,
        label: 'Client details',
        onClose: () => setState(() => open = false),
        list: Column(children: [
          TextButton(focusNode: widget.rowFocus, onPressed: () => setState(() => open = true), child: const Text('row')),
          const Text('list'),
        ]),
        details: open
            ? Column(children: [
                const Text('details'),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => open = false)),
              ])
            : null,
      );
}

Future<void> _openRow(WidgetTester tester, FocusNode row) async {
  row.requestFocus();
  await tester.pump();
  await tester.tap(find.text('row'));
  await tester.pumpAndSettle();
}

void main() {
  group('DetailsLayout', () {
    testWidgets('inline (the default): beside the list at any width, as the Row it replaces', (tester) async {
      final row = FocusNode();
      addTearDown(row.dispose);
      await _pump(tester, _Host(mode: DetailsMode.inline, rowFocus: row), width: 700);
      await _openRow(tester, row);
      expect(tester.getSize(find.ancestor(of: find.text('details'), matching: find.byType(SizedBox)).first).width, 380);
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.byKey(const ValueKey('details-slide-over')), findsNothing);
    });

    testWidgets('auto at 900 and wider: inline', (tester) async {
      final row = FocusNode();
      addTearDown(row.dispose);
      await _pump(tester, _Host(mode: DetailsMode.auto, rowFocus: row), width: 900);
      await _openRow(tester, row);
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.byKey(const ValueKey('details-slide-over')), findsNothing);
    });

    for (final width in [696.0, 400.0]) {
      testWidgets('auto at $width: a slide-over from the right over a dimmed list; scrim and button close it',
          (tester) async {
        final row = FocusNode();
        addTearDown(row.dispose);
        await _pump(tester, _Host(mode: DetailsMode.auto, rowFocus: row), width: width);
        await _openRow(tester, row);
        final panel = find.byKey(const ValueKey('details-slide-over'));
        expect(panel, findsOneWidget);
        final rect = tester.getRect(panel);
        expect(rect.width, width * 0.9 < 380 ? width * 0.9 : 380);
        expect(rect.right, width, reason: 'from the right edge');
        expect(find.byType(VerticalDivider), findsNothing);
        expect(find.text('list'), findsOneWidget, reason: 'the list stays under it');
        // A dialog-like region named by the panel's title.
        final node = tester.getSemantics(panel);
        expect(node.label, 'Client details');
        expect(node.flagsCollection.scopesRoute, isTrue);
        expect(node.flagsCollection.namesRoute, isTrue);
        expect(row.hasFocus, isFalse, reason: 'focus moved into the panel');

        // The dimmed list, labelled Close, closes it; focus goes back to the row.
        final scrim = find.byKey(const ValueKey('details-slide-over-scrim'));
        expect(tester.getSemantics(scrim).label, _en.common_close);
        await tester.tapAt(Offset(rect.left / 2, 400));
        await tester.pumpAndSettle();
        expect(panel, findsNothing);
        expect(row.hasFocus, isTrue, reason: 'focus returns to the row');

        // The panel's own close button closes it too.
        await _openRow(tester, row);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(panel, findsNothing);
        expect(find.text('list'), findsOneWidget);
      });
    }

    testWidgets('reduced motion: the slide-over appears without a slide', (tester) async {
      final row = FocusNode();
      addTearDown(row.dispose);
      await _pump(tester, _Host(mode: DetailsMode.auto, rowFocus: row), width: 696, reduce: true);
      await tester.tap(find.text('row'));
      await tester.pump();
      expect(tester.getRect(find.byKey(const ValueKey('details-slide-over'))).right, 696, reason: 'in place at once');
    });
  });

  group('ListPageBar', () {
    Widget bar(List<String> taps) => Align(
          alignment: Alignment.bottomCenter,
          child: ListPageBar(
            emptyText: 'none',
            itemCount: 25,
            pageSize: 25,
            currentPage: 2,
            hasPreviousPage: true,
            hasNextPage: true,
            isLoading: false,
            onPageSize: (n) => taps.add('size $n'),
            onPrevious: () => taps.add('previous'),
            onNext: () => taps.add('next'),
          ),
        );

    for (final (width, scale) in [(1200.0, 1.0), (500.0, 1.0), (330.0, 1.3)]) {
      testWidgets('at $width, text $scale: no overflow; the controls work', (tester) async {
        final taps = <String>[];
        await _pump(tester, bar(taps), width: width, scale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text(_en.common_showingRange(26, 50)), findsOneWidget);
        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.tap(find.byIcon(Icons.chevron_right));
        expect(taps, ['previous', 'next']);
      });
    }

    testWidgets('one line when it fits, the controls under the range when not', (tester) async {
      await _pump(tester, bar([]), width: 1200);
      final range = tester.getRect(find.text(_en.common_showingRange(26, 50)));
      expect(tester.getRect(find.byIcon(Icons.chevron_right)).center.dy, closeTo(range.center.dy, 12));
      await _pump(tester, bar([]), width: 330, scale: 1.3);
      expect(tester.getRect(find.byIcon(Icons.chevron_right)).top,
          greaterThan(tester.getRect(find.text(_en.common_showingRange(26, 50))).bottom));
    });
  });

  group('ToolbarLayout', () {
    Widget toolbar() => Align(
          alignment: Alignment.topCenter,
          child: ToolbarLayout(
            search: const TextField(key: ValueKey('search')),
            filters: [
              for (final f in ['Type: All', 'Status: All', 'Export']) SizedBox(height: 44, child: OutlinedButton(onPressed: () {}, child: Text(f))),
            ],
          ),
        );

    testWidgets('wide: one line, the search takes the rest, the filters at the end', (tester) async {
      await _pump(tester, toolbar(), width: 1200);
      final search = tester.getRect(find.byKey(const ValueKey('search')));
      final last = tester.getRect(find.text('Export'));
      expect(search.left, 0);
      expect(last.center.dy, closeTo(search.center.dy, 12));
      expect(search.width, greaterThan(240));
    });

    for (final (width, scale) in [(500.0, 1.0), (330.0, 1.3)]) {
      testWidgets('at $width, text $scale: the search on its own line, filters wrapped under it, no overflow',
          (tester) async {
        await _pump(tester, toolbar(), width: width, scale: scale);
        expect(tester.takeException(), isNull);
        final search = tester.getRect(find.byKey(const ValueKey('search')));
        expect(search.width, width);
        expect(tester.getRect(find.text('Type: All')).top, greaterThan(search.bottom));
      });
    }
  });
}
