// UI5 (3): Needs attention is ONE strip of fixed height: the most urgent item
// with its count, "+N" when more kinds need attention, and a sheet listing
// every item, each leading to its screen. Built only from what the app
// already holds (products, debts, the bell's pending members).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/needs_attention.dart';
import 'package:vetbiz_pro/screens/products/stock_alerts_screen.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

const _all = [
  AttentionItem(AttentionKind.expired, 1),
  AttentionItem(AttentionKind.outOfStock, 2),
  AttentionItem(AttentionKind.overdueDebts, 4),
  AttentionItem(AttentionKind.expiringSoon, 3),
  AttentionItem(AttentionKind.lowStock, 5),
  AttentionItem(AttentionKind.pendingApprovals, 1),
];

Widget _strip(List<AttentionItem> items, {VoidCallback? onTap}) => Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(alignment: Alignment.topCenter, child: AttentionStrip(items: items, onTap: onTap ?? () {})),
      ),
    );

void main() {
  group('the items, from held data only, most urgent first', () {
    final products = [
      ph4Product('gone-off', expiry: ph4Now.subtract(const Duration(days: 2))),
      ph4Product('empty', qty: 0),
      ph4Product('soon', expiry: ph4Now.add(const Duration(days: 5))),
      ph4Product('low', qty: 3),
      ph4Product('fine'),
    ];
    final debts = [ph4Debt('c1', 500, 40), ph4Debt('c1', 300, 35), ph4Debt('c2', 200, 31), ph4Debt('c3', 100, 2)];

    test('the owner\'s order: expired, out of stock, overdue, expiring, low, pending', () {
      final items = attentionItemsFor(
        products: products,
        debts: debts,
        overdueDays: 30,
        isAdmin: true,
        pendingApprovals: 2,
        now: ph4Now,
      );
      expect(items, const [
        AttentionItem(AttentionKind.expired, 1),
        AttentionItem(AttentionKind.outOfStock, 1),
        // One item counting clients (c1 twice is one), never one per debt.
        AttentionItem(AttentionKind.overdueDebts, 2),
        AttentionItem(AttentionKind.expiringSoon, 1),
        AttentionItem(AttentionKind.lowStock, 1),
        AttentionItem(AttentionKind.pendingApprovals, 2),
      ]);
    }, skip: _skip);

    test('overdue follows the facility\'s setting', () {
      final items = attentionItemsFor(products: const [], debts: debts, overdueDays: 36, isAdmin: true, now: ph4Now);
      expect(items, const [AttentionItem(AttentionKind.overdueDebts, 1)]);
    }, skip: _skip);

    test('pending approvals are for admins only; nothing at all is an empty list', () {
      expect(
        attentionItemsFor(products: const [], debts: const [], overdueDays: 30, isAdmin: false, pendingApprovals: 3),
        isEmpty,
      );
    }, skip: _skip);

    test('each item leads to its screen and chip', () {
      expect(attentionItemTarget(AttentionKind.overdueDebts), AttentionTarget.debtors);
      expect(attentionItemTarget(AttentionKind.pendingApprovals), AttentionTarget.team);
      expect(attentionStockKind(AttentionKind.expired), StockAlertKind.expired);
      expect(attentionStockKind(AttentionKind.outOfStock), StockAlertKind.depleted);
      expect(attentionStockKind(AttentionKind.expiringSoon), StockAlertKind.expiringSoon);
      expect(attentionStockKind(AttentionKind.lowStock), StockAlertKind.lowStock);
      for (final k in [AttentionKind.expired, AttentionKind.outOfStock, AttentionKind.lowStock]) {
        expect(attentionItemTarget(k), AttentionTarget.stockAlerts);
      }
    }, skip: _skip);
  });

  group('the strip', () {
    for (final look in MatrixLook.values) {
      testWidgets('${look.name}: the first item, "+N", a fixed height, at 360 and with a long text', (tester) async {
        await pumpAtSize(tester, screen: _strip(_all), size: const Size(360, 740), look: look);
        expect(tester.getSize(find.byType(AttentionStrip)).height, PhoneHomeMetrics.attentionStripHeight);
        expect(find.text(look == MatrixLook.kiswahili ? 'Muda umepita: bidhaa 1' : 'Expired stock: 1 product'),
            findsOneWidget);
        expect(find.text('+5'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, skip: _skip);
    }

    testWidgets('one item: no badge, the same height', (tester) async {
      await pumpAtSize(tester, screen: _strip(const [AttentionItem(AttentionKind.outOfStock, 1)]), size: const Size(390, 844));
      expect(find.text('Out of stock: 1 product'), findsOneWidget);
      expect(find.byType(AttentionCountBadge), findsNothing);
      expect(tester.getSize(find.byType(AttentionStrip)).height, PhoneHomeMetrics.attentionStripHeight);
    }, skip: _skip);

    testWidgets('one button for a screen reader, saying how many more', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, screen: _strip(_all.take(3).toList()), size: const Size(390, 844));
      expect(find.bySemanticsLabel('Expired stock: 1 product. 2 more need attention'), findsOneWidget);
      handle.dispose();
    }, skip: _skip);

    testWidgets('a tap opens the sheet of every item; a row closes it and opens its screen', (tester) async {
      AttentionItem? opened;
      await pumpAtSize(
        tester,
        screen: Scaffold(
          body: Builder(
            builder: (context) => AttentionStrip(
              items: _all,
              onTap: () => showAttentionSheet(context, items: _all, onOpen: (i) => opened = i),
            ),
          ),
        ),
        size: const Size(390, 844),
      );
      await tester.tap(find.byType(AttentionStrip));
      await tester.pumpAndSettle();
      expect(find.text('Needs attention'), findsOneWidget);
      for (final t in [
        'Out of stock: 2 products',
        'Overdue debts: 4 clients',
        'Expiring soon: 3 products',
        'Low stock: 5 products',
        'Waiting for approval: 1 person',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      await tester.tap(find.text('Overdue debts: 4 clients'));
      await tester.pumpAndSettle();
      expect(opened, const AttentionItem(AttentionKind.overdueDebts, 4));
      expect(find.text('Needs attention'), findsNothing);
    }, skip: _skip);
  });

  // No amber role reaches 4.5:1 on the amber fill in Light (warningDeep 3.5),
  // so the text and badge are textPrimary and the amber is the icon's.
  test('the strip\'s text and badge 4.5:1, its amber icon 3:1, four themes, Light and Dark', () {
    for (final theme in AppColorTheme.all) {
      for (final brightness in Brightness.values) {
        final c = AppColors.fromTheme(theme, brightness: brightness);
        final where = '${theme.id} ${brightness.name}';
        expect(ColorMath.contrast(c.textPrimary, c.warningBannerFill), greaterThanOrEqualTo(4.5), reason: where);
        expect(ColorMath.contrast(c.textPrimary, c.surface), greaterThanOrEqualTo(4.5), reason: '$where badge');
        expect(ColorMath.contrast(c.warningDeep, c.warningBannerFill), greaterThanOrEqualTo(3), reason: '$where icon');
      }
    }
  }, skip: _skip);
}
