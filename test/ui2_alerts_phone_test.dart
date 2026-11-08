// UI2 (1): Product Alerts on a phone follows the PH5a list pattern. The five
// cards become one summary line and a row of chips that filter exactly as
// the tablet's cards do (a tap on a chosen card or chip clears it); rows are
// a photo, the name and the quantity, the category and the alert in text,
// with no buttons: a tap opens the product's details page, where the alert's
// action (Restock: Add Batch for that product, as today's button) waits.
// No coloured left strip anywhere on the page, at any width.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';
import 'package:vetbiz_pro/screens/products/add_batch_screen.dart';
import 'package:vetbiz_pro/screens/products/product_phone_parts.dart';
import 'package:vetbiz_pro/screens/products/stock_alerts_screen.dart';

import 'helpers/ph5b_finders.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

// Until the strips go (UI2 (1), the strip commit).
const _stripSkip = false;

/// ph7Products with the long-named product low on stock, so it is an alert.
final ui2AlertProducts = [
  for (final p in ph7Products)
    p.id == 'p7' ? Ph7Product('p7', p.name, shelf: 2, store: 0, sell: p.sell, buy: p.buy, category: p.category) : p,
];

Future<void> _seed(dynamic fs) => ph7SeedProducts(fs, ui2AlertProducts);

Widget _alerts(dynamic fs) => const Ph7Listening(child: StockAlertsScreen());

final _rowKey = RegExp(r'^(phoneList-row-)?(depleted|expired|lowStock|expiringSoon|restockShelf)-[a-z]\d+$');

/// The alert rows on screen, as 'kind-productId'.
Set<String> _rows(WidgetTester tester) => {
      for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && _rowKey.hasMatch((w.key! as ValueKey<String>).value)).evaluate())
        (e.widget.key! as ValueKey<String>).value.replaceFirst('phoneList-row-', ''),
    };

/// Every alert the products give right now.
List<StockAlert> _all(WidgetTester tester) =>
    StockAlertsScreen.currentAlerts(Provider.of<ProductProvider>(tester.element(find.byType(StockAlertsScreen)), listen: false).products);

/// A decoration whose border has a coloured left side and nothing else.
bool _leftOnly(Decoration? d) {
  if (d is! BoxDecoration || d.border is! Border) return false;
  final b = d.border! as Border;
  return b.left.width > 0 && b.left.style != BorderStyle.none && b.top.width == 0 && b.right.width == 0 && b.bottom.width == 0;
}

int _strips(WidgetTester tester) => find
    .descendant(
      of: find.byType(StockAlertsScreen),
      matching: find.byWidgetPredicate((w) =>
          (w is Container && _leftOnly(w.decoration)) || (w is DecoratedBox && _leftOnly(w.decoration))),
    )
    .evaluate()
    .length;

const _kinds = [null, ...StockAlertKind.values];

void main() {
  for (final kind in _kinds) {
    ph5TestWidgets('chip ${kind?.name ?? 'All'} lists exactly what the tablet card lists', (tester) async {
      await pumpPh5(tester, _alerts, size: const Size(1024, 1400), pushed: true, seed: _seed);
      if (kind != null) {
        await tester.tap(find.descendant(of: find.byType(GridView), matching: find.textContaining(_titleEn(kind))).first);
        await ph5Settle(tester);
      }
      final wide = _rows(tester);

      await pumpPh5(tester, _alerts, size: const Size(390, 844), pushed: true, seed: _seed);
      if (kind != null) {
        await tester.ensureVisible(ph5Key('ui2-alertChip-${kind.name}'));
        await tester.tap(ph5Key('ui2-alertChip-${kind.name}'));
        await ph5Settle(tester);
      }
      expect(_rows(tester), wide);
      expect(wide, isNotEmpty);

      if (kind != null) {
        // A tap on the chosen chip clears it, as on the chosen card.
        await tester.ensureVisible(ph5Key('ui2-alertChip-${kind.name}'));
        await tester.tap(ph5Key('ui2-alertChip-${kind.name}'));
        await ph5Settle(tester);
        expect(_rows(tester).length, _all(tester).length);
      }
    }, skip: _skip);
  }

  ph5TestWidgets('the chips show their counts as text and the chosen one a check mark', (tester) async {
    await pumpPh5(tester, _alerts, pushed: true, seed: _seed);
    final all = _all(tester);
    for (final kind in StockAlertKind.values) {
      final count = all.where((a) => a.kind == kind).length;
      expect(find.descendant(of: ph5Key('ui2-alertChip-${kind.name}'), matching: find.text('${_titleEn(kind)} · $count')), findsOneWidget);
    }
    await tester.tap(ph5Key('ui2-alertChip-lowStock'));
    await ph5Settle(tester);
    final chip = tester.widget<ChoiceChip>(ph5Key('ui2-alertChip-lowStock'));
    expect(chip.selected, isTrue);
    expect(chip.showCheckmark ?? true, isTrue);
  }, skip: _skip);

  ph5TestWidgets('one summary line: the number of alerts, and no subtitle in the bar', (tester) async {
    await pumpPh5(tester, _alerts, pushed: true, seed: _seed);
    expect(find.text('${_all(tester).length} alerts'), findsOneWidget);
    expect(find.text('Product Alerts'), findsOneWidget);
    expect(find.text('Stock and expiry problems that need action'), findsNothing);
    expect(find.byType(GridView), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.textContaining('Showing 1 to'), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('a row: photo, name and quantity, category and the alert in text, no buttons', (tester) async {
    await pumpPh5(tester, _alerts, pushed: true, seed: _seed);
    final row = ph5Key('phoneList-row-depleted-p6');
    expect(find.descendant(of: row, matching: find.byType(ProductLeading)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Newcastle vaccine')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('0 pcs')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('Vaccines')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Out of Stock')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.bySubtype<ButtonStyleButton>()), findsNothing);
    expect(find.descendant(of: row, matching: find.byType(IconButton)), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('Restock on the details page opens Add Batch for that product, as the old button', (tester) async {
    await pumpPh5(tester, _alerts, pushed: true, seed: _seed);
    await tester.tap(ph5Key('phoneList-row-lowStock-p7'));
    await ph5Settle(tester);
    expect(ph5Page, findsOneWidget);
    // The page's Add New Batch is that same call, so it is not shown twice.
    expect(find.text('Add New Batch'), findsNothing);
    await tester.tap(find.text('Restock'));
    await ph5Settle(tester);
    expect(tester.widget<AddBatchScreen>(find.byType(AddBatchScreen)).product.id, 'p7');
  }, skip: _skip);

  ph5TestWidgets('the tablet Restock button still opens Add Batch for its product', (tester) async {
    await pumpPh5(tester, _alerts, size: const Size(1024, 1400), pushed: true, seed: _seed);
    await tester.tap(find.descendant(of: ph5Key('lowStock-p7'), matching: find.text('Restock')));
    await ph5Settle(tester);
    expect(tester.widget<AddBatchScreen>(find.byType(AddBatchScreen)).product.id, 'p7');
  }, skip: _skip);

  ph5TestWidgets('an assistant cannot move stock to the shelf from the page either', (tester) async {
    await pumpPh5(tester, _alerts, pushed: true, seed: _seed, admin: false);
    await tester.tap(ph5Key('phoneList-row-restockShelf-p8'));
    await ph5Settle(tester);
    final button = find.ancestor(of: find.text('Move to shelf'), matching: find.bySubtype<FilledButton>());
    expect(tester.widget<FilledButton>(button.first).onPressed, isNull);
  }, skip: _skip);

  ph5TestWidgets('no alerts: one plain line, no cheerful text', (tester) async {
    await pumpPh5(tester, _alerts, pushed: true, seed: (fs) => ph7SeedProducts(fs, [ph7Products.first]));
    expect(ph5Key('phoneList-empty'), findsOneWidget);
    expect(find.text('No alerts'), findsOneWidget);
    expect(find.textContaining('caught up'), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('more alerts than a page: scrolling with Load more, ten at a time', (tester) async {
    await pumpPh5(tester, _alerts, size: const Size(390, 1400), pushed: true, seed: (fs) => ph7SeedProducts(fs, [
          for (var i = 0; i < 12; i++) Ph7Product('q$i', 'Product $i', shelf: 0, store: 0),
        ]));
    expect(_rows(tester).length, 10);
    await tester.ensureVisible(ph5Key('phoneList-loadMore'));
    await tester.tap(ph5Key('phoneList-loadMore'));
    await ph5Settle(tester);
    expect(_rows(tester).length, 12);
  }, skip: _skip);

  for (final size in [const Size(390, 844), ...ph5WideSizes]) {
    ph5TestWidgets('no coloured left strip at ${size.width.toInt()} wide', (tester) async {
      await pumpPh5(tester, _alerts, size: size, pushed: true, seed: _seed);
      expect(_strips(tester), 0);
    }, skip: _stripSkip);
  }

  group('Product Alerts phone matrix', () {
    for (final size in ph5PhoneSizes) {
      for (final look in MatrixLook.values) {
        final where = 'Product Alerts ${matrixCase(size, look)}';
        ph5TestWidgets(where, (tester) async {
          await pumpPh5(tester, _alerts, size: size.size, look: look, pushed: true, seed: _seed);
          await checkCase(tester, phone: true, where: '$where list');
          await tester.tap(ph5Key('phoneList-row-lowStock-p7'));
          await ph5Settle(tester);
          await checkCase(tester, phone: true, where: '$where details');
        }, skip: _skip);
      }
    }
  });
}

String _titleEn(StockAlertKind k) => switch (k) {
      StockAlertKind.depleted => 'Out of Stock',
      StockAlertKind.expired => 'Expired',
      StockAlertKind.lowStock => 'Low Stock',
      StockAlertKind.expiringSoon => 'Expiring Soon',
      StockAlertKind.restockShelf => 'Restock Shelf',
    };
