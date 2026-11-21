// UX1a: the shared page header of the PC/tablet screens (PageHeader). The
// title on the left with its subtitle under it, the actions on the right, a
// back arrow only on a page pushed above another (never at the shell's top
// level), at the four content widths, text 1.3, English and Kiswahili, Light
// and Dark, every colour theme.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_text.dart';
import 'package:vetbiz_pro/theme/polish_metrics.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';
import 'package:vetbiz_pro/widgets/shell/page_header.dart';

import 'helpers/screen_size_matrix.dart';

const _title = ValueKey('ux1a-title-probe');
const _range = ValueKey('ux1a-range');
const _record = ValueKey('ux1a-record');

/// The widest header of the ten (Transactions): an icon, a shrinking date
/// range and the primary button, with real texts in the current language.
class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: PageHeader(
          key: _title,
          title: context.l10n.transactions_title,
          subtitle: context.l10n.transactions_subtitle,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), tooltip: context.l10n.common_refresh, onPressed: () {}),
            Flexible(
              child: OutlinedButton.icon(
                key: _range,
                onPressed: () {},
                icon: const Icon(Icons.date_range_outlined),
                label: const Text('Nov 1, 2026 - Nov 21, 2026', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.s8, right: AppSpacing.s12),
              child: ElevatedButton.icon(
                key: _record,
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: Text(context.l10n.transactions_record),
              ),
            ),
          ],
        ),
        body: const SizedBox.expand(),
      );
}

void main() {
  const window = 800.0;
  for (final content in [696.0, 774.0, 950.0, 1128.0]) {
    for (final theme in AppColorTheme.all) {
      for (final look in MatrixLook.values) {
        testWidgets('content ${content.toInt()} ${theme.id} ${look.name} text 1.3: left title, right actions', (tester) async {
          await pumpAtSize(tester, size: Size(content, window), look: look, colorTheme: theme, textScale: 1.3, screen: const _Page());
          expect(tester.takeException(), isNull, reason: 'no overflow');
          final header = find.byType(PageHeader);
          expect(tester.getSize(header).height, PageHeader.height);
          // The title starts at the page padding (no leading on a base page).
          final title = find.descendant(of: header, matching: find.byType(Text)).first;
          expect(tester.getTopLeft(title).dx, PolishMetrics.pagePadding);
          final titleText = tester.widget<Text>(title);
          expect(titleText.style?.fontSize, AppFontSize.f19);
          expect(titleText.textAlign, anyOf(isNull, TextAlign.start));
          // The primary button ends 16 from the right edge (4 + its 12).
          expect(tester.getTopRight(find.byKey(_record)).dx, content - AppSpacing.s4 - AppSpacing.s12);
          // Centred in the full 72, as in the AppBar it replaced (the
          // hairline is painted over, not laid out).
          expect(tester.getCenter(find.byKey(_record)).dy, PageHeader.height / 2);
          expect(tester.getTopLeft(find.byKey(_range)).dx, greaterThan(tester.getTopLeft(title).dx));
          expect(find.byType(BackButton), findsNothing);
          // Colours from the roles: surface, the divider hairline, the text roles.
          final ctx = tester.element(header);
          final material = tester.widget<Material>(find.descendant(of: header, matching: find.byType(Material)).first);
          expect(material.color, ctx.colors.surface);
          final box = tester.widget<Container>(find.descendant(of: header, matching: find.byType(Container)).first);
          final side = ((box.foregroundDecoration! as BoxDecoration).border! as Border).bottom;
          expect(side.color, ctx.colors.divider);
          expect(side.width, PolishMetrics.hairline);
          expect((box.foregroundDecoration! as BoxDecoration).boxShadow, isNull);
          expect(titleText.style?.color, ctx.colors.textPrimary);
          final sub = tester.widget<Text>(find.descendant(of: header, matching: find.byType(Text)).at(1));
          expect(sub.data, ctx.l10n.transactions_subtitle);
          expect(sub.style?.color, ctx.colors.textSecondary);
        });
      }
    }
  }

  testWidgets('no subtitle: the title alone, centred vertically', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(774, 800),
      screen: const Scaffold(appBar: PageHeader(title: 'Insights'), body: SizedBox.expand()),
    );
    final header = find.byType(PageHeader);
    expect(find.descendant(of: header, matching: find.byType(Text)), findsOneWidget);
    final t = tester.getCenter(find.text('Insights')).dy;
    expect(t, closeTo(PageHeader.height / 2, 1));
  });

  testWidgets('a page pushed above another shows the back arrow; the base page none', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(1024, 768),
      screen: Builder(
        builder: (context) => Scaffold(
          appBar: const PageHeader(title: 'Base'),
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const Scaffold(appBar: PageHeader(title: 'Pushed'), body: SizedBox.expand()))),
            child: const Text('open'),
          ),
        ),
      ),
    );
    expect(find.byType(BackButton), findsNothing);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    // The title moves right of the arrow, still left-aligned.
    expect(tester.getTopLeft(find.text('Pushed')).dx, greaterThan(tester.getTopRight(find.byType(BackButton)).dx));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Base'), findsOneWidget);
  });

  testWidgets('a destination at the shell\'s top level has no back arrow even when it can pop', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(1024, 768),
      screen: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const ShellScope(child: Scaffold(appBar: PageHeader(title: 'Sales'), body: SizedBox.expand())))),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Sales'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('a Scaffold drawer gets the menu button (Products below 900), which opens it', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(768, 1024),
      screen: const ShellScope(
        child: Scaffold(appBar: PageHeader(title: 'Products'), drawer: Drawer(child: Text('filters')), body: SizedBox.expand()),
      ),
    );
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(tester.getSize(find.widgetWithIcon(IconButton, Icons.menu)).width, greaterThanOrEqualTo(44));
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('filters'), findsOneWidget);
  });

  testWidgets('showBack and leading override the rule', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(1024, 768),
      screen: const Scaffold(
        appBar: PageHeader(title: 'X', leading: Icon(Icons.close, key: ValueKey('lead'))),
        body: SizedBox.expand(),
      ),
    );
    expect(find.byKey(const ValueKey('lead')), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  test('the header uses existing roles only (Light and Dark, every theme)', () {
    for (final theme in AppColorTheme.all) {
      for (final b in Brightness.values) {
        final c = AppColors.fromTheme(theme, brightness: b);
        expect(c.surface, isNot(c.brandSurface), reason: '${theme.id} ${b.name}: not a teal bar');
      }
    }
  });
}
